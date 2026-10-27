import 'dart:convert';
import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:shelf/shelf.dart';

import '../auth/auth_middleware.dart';
import '../util/safe_path.dart';

/// Versión del protocolo MCP que se habla. Si el cliente pide otra, se le
/// contesta esta y decide él; es lo que pide la especificación.
const String mcpProtocolVersion = '2025-06-18';

/// Servidor MCP del Modo DM sobre HTTP «Streamable» en su forma mínima: cada
/// POST trae un mensaje JSON-RPC y se contesta con JSON, sin SSE ni sesión.
/// Ninguna herramienta necesita avisar nada por su cuenta, y así el túnel no
/// tiene que sostener conexiones abiertas.
///
/// Las herramientas no tocan los repositorios: llaman a [api], el mismo
/// enrutado que usa la app, con la cuenta del token ya puesta. Así la
/// validación y la autorización del `WHERE` existen en un solo lugar, y lo
/// ajeno le responde a Claude lo mismo que a la app: que no existe.
Handler mcpHandler({
  required Future<String?> Function(String token) resolveToken,
  required Handler api,
}) {
  return (Request request) async {
    if (request.method != 'POST') {
      // Sin SSE no hay nada que abrir con GET; la especificación pide 405.
      return Response(405, headers: {'allow': 'POST'});
    }
    // El token va en el encabezado y no en una cookie: el navegador no lo
    // manda solo, así que una página ajena no puede usarlo por el usuario.
    final auth = request.headers['authorization'] ?? '';
    final token = auth.startsWith('Bearer ') ? auth.substring(7).trim() : '';
    final userId = token.isEmpty ? null : await resolveToken(token);
    if (userId == null) {
      return Response(
        401,
        body: jsonEncode({'error': 'Token inválido o vencido.'}),
        headers: {
          'content-type': 'application/json',
          'www-authenticate': 'Bearer',
        },
      );
    }

    final Object? message;
    try {
      message = jsonDecode(await request.readAsString());
    } on FormatException {
      return _rpc(null, error: {'code': -32700, 'message': 'JSON inválido.'});
    }
    if (message is! Map<String, dynamic>) {
      return _rpc(
        null,
        error: {'code': -32600, 'message': 'Se esperaba un objeto JSON-RPC.'},
      );
    }
    final id = message['id'];
    // Una notificación (`notifications/initialized`) no lleva respuesta.
    if (id == null) return Response(202);

    final params = message['params'] is Map<String, dynamic>
        ? message['params'] as Map<String, dynamic>
        : const <String, dynamic>{};
    switch (message['method']) {
      case 'initialize':
        return _rpc(
          id,
          result: {
            'protocolVersion': mcpProtocolVersion,
            'capabilities': {'tools': <String, dynamic>{}},
            'serverInfo': {'name': 'milantus', 'version': '1.0.0'},
            'instructions': _instructions,
          },
        );
      case 'ping':
        return _rpc(id, result: <String, dynamic>{});
      case 'tools/list':
        return _rpc(
          id,
          result: {
            'tools': [
              for (final t in _tools)
                {
                  'name': t.name,
                  'description': t.description,
                  'inputSchema': {
                    'type': 'object',
                    'properties': t.properties,
                    'required': t.required,
                  },
                },
            ],
          },
        );
      case 'tools/call':
        final tool = _tools.where((t) => t.name == params['name']).firstOrNull;
        if (tool == null) {
          return _rpc(
            id,
            error: {'code': -32602, 'message': 'Herramienta desconocida.'},
          );
        }
        final args = params['arguments'] is Map<String, dynamic>
            ? params['arguments'] as Map<String, dynamic>
            : <String, dynamic>{};
        final calls = _ApiCalls(api, userId);
        try {
          final out = await tool.run(calls, _Args(args));
          return _rpc(id, result: _toolResult(out));
        } on _ToolError catch (e) {
          return _rpc(id, result: _toolResult(e.message, isError: true));
        } on FormatException catch (e) {
          return _rpc(id, result: _toolResult(e.message, isError: true));
        }
      default:
        return _rpc(
          id,
          error: {'code': -32601, 'message': 'Método desconocido.'},
        );
    }
  };
}

const String _instructions =
    'Milantus es una app de D&D 5e (reglas 2024). Estas herramientas manejan '
    'el Modo DM de la cuenta: campañas, capítulos, notas del cuaderno y PNJ. '
    'Toda nota cuelga de un capítulo; si no hay ninguno, creá uno primero. '
    'Un capítulo nace «planned» y solo uno puede estar «active» a la vez; '
    'cerrarlo se hace desde la app. Borrar también se hace desde la app. '
    'Las fichas de los jugadores son de sus dueños: acá solo se ven sus '
    'nombres y niveles.';

Response _rpc(Object? id, {Object? result, Map<String, dynamic>? error}) =>
    Response.ok(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        if (error != null) 'error': error else 'result': result,
      }),
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _toolResult(Object? out, {bool isError = false}) => {
  'content': [
    {'type': 'text', 'text': out is String ? out : jsonEncode(out)},
  ],
  'isError': isError,
};

/// Un error que Claude tiene que leer y corregir: va como resultado con
/// `isError`, no como error del protocolo.
class _ToolError implements Exception {
  final String message;
  const _ToolError(this.message);
}

class _Args {
  final Map<String, dynamic> _raw;
  const _Args(this._raw);

  String req(String key) {
    final v = _raw[key];
    if (v is! String || v.trim().isEmpty) {
      throw _ToolError('Falta «$key».');
    }
    return v.trim();
  }

  /// Un id que va a la ruta: con `/` o `..` podría apuntar a otra ruta de la
  /// API, siempre de la misma cuenta, pero no a la que Claude quiso.
  String id(String key) => requireSafePathSegment(req(key), label: key);

  String? opt(String key) => _raw[key] is String ? _raw[key] as String : null;

  bool has(String key) => _raw.containsKey(key);

  List<String>? list(String key) =>
      _raw[key] is List ? [for (final v in _raw[key] as List) '$v'] : null;
}

/// Llamadas internas al enrutado de la API con la cuenta del token.
class _ApiCalls {
  final Handler _api;
  final String _userId;
  const _ApiCalls(this._api, this._userId);

  Future<Map<String, dynamic>> call(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _api(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {if (body != null) 'content-type': 'application/json'},
        context: {userIdContextKey: _userId},
      ),
    );
    final text = await response.readAsString();
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode != 200) {
      // El mensaje del servidor ya está escrito para una persona: «Ya hay un
      // capítulo en marcha…», «Campaña no encontrada».
      throw _ToolError(
        decoded is Map && decoded['error'] is String
            ? decoded['error'] as String
            : 'La operación falló (${response.statusCode}).',
      );
    }
    return (decoded as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> chapter(String campaignId, String id) async {
    final all = await call('GET', '/api/campaigns/$campaignId/chapters');
    return _find(all['chapters'], id, 'Capítulo');
  }

  Future<Map<String, dynamic>> note(String campaignId, String id) async {
    final all = await call('GET', '/api/campaigns/$campaignId/notebook');
    return _find(all['notes'], id, 'Nota');
  }

  Future<Map<String, dynamic>> campaign(String id) async {
    final all = await call('GET', '/api/campaigns');
    return _find(all['campaigns'], id, 'Campaña');
  }

  Map<String, dynamic> _find(Object? list, String id, String label) {
    for (final e in list as List) {
      if (e is Map && e['id'] == id) return e.cast<String, dynamic>();
    }
    throw _ToolError('$label no encontrada: $id.');
  }
}

/// Mismo formato que los ids que arma la app (`prefijo-micros-n`), con azar
/// en vez del contador: dos llamadas pueden caer en el mismo microsegundo.
String _newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-'
    '${Random.secure().nextInt(1 << 32)}';

/// Aplica a [doc] los campos que vinieron, y nada más: así editar no pisa lo
/// que la app guardó y Claude no conoce (escenas de música, objetos…).
Map<String, dynamic> _merge(
  Map<String, dynamic> doc,
  _Args args,
  List<String> keys,
) {
  for (final k in keys) {
    if (args.has(k)) doc[k] = args.list(k) ?? args.opt(k);
  }
  return doc;
}

void _checkEnum(_Args args, String key, Iterable<String> values) {
  final v = args.opt(key);
  if (v != null && !values.contains(v)) {
    throw _ToolError('«$key» tiene que ser uno de: ${values.join(', ')}.');
  }
}

class _Tool {
  final String name;
  final String description;
  final Map<String, dynamic> properties;
  final List<String> required;
  final Future<Object?> Function(_ApiCalls api, _Args args) run;
  const _Tool(
    this.name,
    this.description,
    this.properties,
    this.required,
    this.run,
  );
}

Map<String, dynamic> _str(String description, [List<String>? values]) => {
  'type': 'string',
  'description': description,
  if (values != null) 'enum': values,
};

final _campaignStates = [for (final s in CampaignState.values) s.name];

/// Los estados que se pueden poner a mano: completar es cerrar el capítulo,
/// que reparte avisos y lo hace la app.
const _chapterStates = ['planned', 'active'];
final _npcStatuses = [for (final s in NpcStatus.values) s.name];

final _tools = <_Tool>[
  _Tool('list_campaigns', 'Lista las campañas de la cuenta.', {}, [], (
    api,
    args,
  ) async {
    final all = await api.call('GET', '/api/campaigns');
    return [
      for (final c in all['campaigns'] as List)
        {
          'id': c['id'],
          'name': c['name'],
          'state': c['state'],
          'premise': c['premise'],
        },
    ];
  }),
  _Tool(
    'get_campaign',
    'Una campaña con sus capítulos, notas, PNJ y jugadores.',
    {'campaignId': _str('Id de la campaña.')},
    ['campaignId'],
    (api, args) async {
      final id = args.id('campaignId');
      final campaign = await api.campaign(id);
      final chapters = await api.call('GET', '/api/campaigns/$id/chapters');
      final notebook = await api.call('GET', '/api/campaigns/$id/notebook');
      final npcs = await api.call('GET', '/api/campaigns/$id/npcs');
      final members = await api.call('GET', '/api/campaigns/$id/members');
      return {
        'id': campaign['id'],
        'name': campaign['name'],
        'state': campaign['state'],
        'premise': campaign['premise'],
        'chapters': [
          for (final c in chapters['chapters'] as List)
            {
              'id': c['id'],
              'name': c['name'],
              'state': c['state'],
              'summary': c['summary'],
            },
        ],
        'notes': [
          for (final n in notebook['notes'] as List)
            {
              'id': n['id'],
              'chapterId': n['chapterId'],
              'title': n['title'],
              'body': n['body'],
            },
        ],
        'npcs': [
          for (final e in npcs['npcs'] as List)
            {
              'id': e['npc']['id'],
              'name': e['npc']['name'],
              'status': e['status'],
            },
        ],
        'players': [
          for (final m in members['members'] as List)
            {
              'name': m['character']['name'],
              'level': (m['character']['classHistory'] as List?)?.length,
            },
        ],
      };
    },
  ),
  _Tool(
    'create_campaign',
    'Crea una campaña.',
    {
      'name': _str('Nombre.'),
      'premise': _str('Premisa: de qué trata, en un párrafo.'),
    },
    ['name'],
    (api, args) async {
      final campaign = Campaign(
        id: _newId('campaign'),
        name: args.req('name'),
        premise: args.opt('premise') ?? '',
      );
      final out = await api.call('POST', '/api/campaigns', {
        'campaign': campaign.toJson(),
      });
      return {'id': out['campaign']['id']};
    },
  ),
  _Tool(
    'update_campaign',
    'Cambia el nombre, la premisa o el estado de una campaña. Solo se tocan '
        'los campos que se pasan.',
    {
      'campaignId': _str('Id de la campaña.'),
      'name': _str('Nombre.'),
      'premise': _str('Premisa.'),
      'state': _str('Estado.', _campaignStates),
    },
    ['campaignId'],
    (api, args) async {
      final id = args.id('campaignId');
      _checkEnum(args, 'state', _campaignStates);
      final doc = _merge(await api.campaign(id), args, [
        'name',
        'premise',
        'state',
      ]);
      await api.call('PUT', '/api/campaigns/$id', {'campaign': doc});
      return 'Campaña actualizada.';
    },
  ),
  _Tool(
    'create_chapter',
    'Crea un capítulo en una campaña.',
    {
      'campaignId': _str('Id de la campaña.'),
      'name': _str('Nombre.'),
      'summary': _str('Resumen.'),
      'state': _str('Estado; por defecto planned.', _chapterStates),
    },
    ['campaignId', 'name'],
    (api, args) async {
      final campaignId = args.id('campaignId');
      _checkEnum(args, 'state', _chapterStates);
      final chapter = Chapter(
        id: _newId('chapter'),
        name: args.req('name'),
        summary: args.opt('summary') ?? '',
        state: ChapterState.fromJson(args.opt('state')),
      );
      final out = await api.call(
        'POST',
        '/api/campaigns/$campaignId/chapters',
        {'chapter': chapter.toJson()},
      );
      return {'id': out['chapter']['id']};
    },
  ),
  _Tool(
    'update_chapter',
    'Cambia el nombre, el resumen o el estado de un capítulo. Solo se tocan '
        'los campos que se pasan.',
    {
      'campaignId': _str('Id de la campaña.'),
      'chapterId': _str('Id del capítulo.'),
      'name': _str('Nombre.'),
      'summary': _str('Resumen.'),
      'state': _str('Estado.', _chapterStates),
    },
    ['campaignId', 'chapterId'],
    (api, args) async {
      final campaignId = args.id('campaignId');
      final id = args.id('chapterId');
      _checkEnum(args, 'state', _chapterStates);
      final doc = _merge(await api.chapter(campaignId, id), args, [
        'name',
        'summary',
        'state',
      ]);
      await api.call('PUT', '/api/campaigns/$campaignId/chapters/$id', {
        'chapter': doc,
      });
      return 'Capítulo actualizado.';
    },
  ),
  _Tool(
    'create_note',
    'Agrega una nota al cuaderno de la campaña, dentro de un capítulo.',
    {
      'campaignId': _str('Id de la campaña.'),
      'chapterId': _str('Id del capítulo.'),
      'title': _str('Título.'),
      'body': _str('Texto de la nota.'),
    },
    ['campaignId', 'chapterId', 'title'],
    (api, args) async {
      final campaignId = args.id('campaignId');
      final note = Note(
        id: _newId('note'),
        chapterId: args.id('chapterId'),
        title: args.req('title'),
        body: args.opt('body') ?? '',
        updatedAt: DateTime.now().toUtc(),
      );
      final out = await api.call('POST', '/api/campaigns/$campaignId/notes', {
        'note': note.toJson(),
      });
      return {'id': out['note']['id']};
    },
  ),
  _Tool(
    'update_note',
    'Cambia el título, el texto o el capítulo de una nota. Solo se tocan los '
        'campos que se pasan.',
    {
      'campaignId': _str('Id de la campaña.'),
      'noteId': _str('Id de la nota.'),
      'title': _str('Título.'),
      'body': _str('Texto completo; reemplaza al anterior.'),
      'chapterId': _str('Capítulo al que se mueve.'),
    },
    ['campaignId', 'noteId'],
    (api, args) async {
      final campaignId = args.id('campaignId');
      final id = args.id('noteId');
      final doc = _merge(await api.note(campaignId, id), args, [
        'title',
        'body',
        'chapterId',
      ])..['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await api.call('PUT', '/api/campaigns/$campaignId/notes/$id', {
        'note': doc,
      });
      return 'Nota actualizada.';
    },
  ),
  _Tool(
    'list_npcs',
    'Lista los PNJ de la biblioteca de la cuenta, con las campañas en que '
        'están.',
    {},
    [],
    (api, args) async {
      final all = await api.call('GET', '/api/npcs');
      return [
        for (final e in all['npcs'] as List)
          {
            'id': e['npc']['id'],
            'name': e['npc']['name'],
            'sheetKind': e['npc']['sheetKind'],
            'tags': e['npc']['tags'] ?? const [],
            'campaigns': e['campaigns'],
          },
      ];
    },
  ),
  _Tool(
    'get_npc',
    'Un PNJ completo.',
    {'npcId': _str('Id del PNJ.')},
    ['npcId'],
    (api, args) async =>
        (await api.call('GET', '/api/npcs/${args.id('npcId')}'))['npc'],
  ),
  _Tool(
    'create_npc',
    'Crea un PNJ sin estadísticas (nombre y rol). Con campaignId, además lo '
        'suma a esa campaña.',
    {
      'name': _str('Nombre.'),
      'appearance': _str('Apariencia.'),
      'speech': _str('Cómo habla.'),
      'background': _str('Trasfondo e historia.'),
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Etiquetas: aliado, tabernero, Neverwinter…',
      },
      'campaignId': _str('Campaña a la que se suma.'),
    },
    ['name'],
    (api, args) async {
      final npc = Npc(
        id: _newId('npc'),
        name: args.req('name'),
        sheetKind: NpcSheetKind.none,
        appearance: args.opt('appearance') ?? '',
        speech: args.opt('speech') ?? '',
        background: args.opt('background') ?? '',
        tags: args.list('tags') ?? const [],
      );
      final out = await api.call('POST', '/api/npcs', {'npc': npc.toJson()});
      final id = out['npc']['id'] as String;
      final campaignId = args.opt('campaignId');
      if (campaignId != null) {
        await api.call('PUT', '/api/campaigns/$campaignId/npcs/$id', {});
      }
      return {'id': id};
    },
  ),
  _Tool(
    'update_npc',
    'Cambia los datos narrativos de un PNJ. Solo se tocan los campos que se '
        'pasan.',
    {
      'npcId': _str('Id del PNJ.'),
      'name': _str('Nombre.'),
      'appearance': _str('Apariencia.'),
      'speech': _str('Cómo habla.'),
      'background': _str('Trasfondo e historia.'),
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Etiquetas; reemplazan a las anteriores.',
      },
    },
    ['npcId'],
    (api, args) async {
      final id = args.id('npcId');
      final current = await api.call('GET', '/api/npcs/$id');
      final doc = _merge(
        (current['npc'] as Map).cast<String, dynamic>(),
        args,
        ['name', 'appearance', 'speech', 'background', 'tags'],
      );
      await api.call('PUT', '/api/npcs/$id', {'npc': doc});
      return 'PNJ actualizado.';
    },
  ),
  _Tool(
    'link_npc',
    'Suma un PNJ de la biblioteca a una campaña, o le cambia el estado en '
        'ella.',
    {
      'campaignId': _str('Id de la campaña.'),
      'npcId': _str('Id del PNJ.'),
      'status': _str('Estado en esta campaña.', _npcStatuses),
    },
    ['campaignId', 'npcId'],
    (api, args) async {
      _checkEnum(args, 'status', _npcStatuses);
      await api.call(
        'PUT',
        '/api/campaigns/${args.id('campaignId')}/npcs/${args.id('npcId')}',
        {if (args.opt('status') != null) 'status': args.opt('status')},
      );
      return 'PNJ vinculado.';
    },
  ),
];
