import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// `Cache-Control` de `index.html` (y de todo lo que no lleve huella): igual
/// que el build de Flutter, ver [webCacheHeadersMiddleware]. El HTML es lo que
/// apunta al bundle vigente, así que tiene que revalidar siempre.
const String webV2IndexCacheControl = 'private, no-cache';

/// Los archivos de `assets/` los emite Vite con el hash del contenido en el
/// nombre (`index-Dh3k9a.js`): una versión nueva es otra URL, así que la
/// vieja nunca queda desactualizada y puede cachearse un año sin revalidar.
/// Es lo contrario del build de Flutter, cuyos nombres se repiten entre
/// versiones.
const String webV2AssetCacheControl = 'public, max-age=31536000, immutable';

/// Sirve el build de `packages/dnd_web` bajo `/v2/`. Espera la petición
/// original (con el prefijo `v2/` en la ruta).
///
/// Devuelve `null` si [root] no existe: quien lo monta decide qué responder.
/// Una ruta de cliente (`/v2/personajes/3`) no es un archivo y cae a
/// `index.html` para que el router de React la resuelva; un archivo que falta
/// (`/v2/assets/viejo.js`) en cambio es un 404 de verdad, porque devolverle
/// HTML a un `<script>` esconde el despliegue roto detrás de un error de
/// sintaxis.
Handler? buildWebV2Handler(String root) {
  if (!Directory(root).existsSync()) return null;
  final files = createStaticHandler(root, defaultDocument: 'index.html');

  return (Request request) async {
    final inner = request.change(path: 'v2');
    var response = await files(inner);
    final path = inner.url.path;

    if (response.statusCode == 404 && !_looksLikeFile(path)) {
      // La ruta de cliente no existe en disco: se pide el documento a mano.
      response = await files(
        Request(
          request.method,
          request.requestedUri.replace(path: '/index.html'),
          headers: request.headers,
        ),
      );
    }
    final isAsset = path.startsWith('assets/') && response.statusCode == 200;
    return response.change(
      headers: {
        'cache-control': isAsset
            ? webV2AssetCacheControl
            : webV2IndexCacheControl,
      },
    );
  };
}

bool _looksLikeFile(String path) => path.split('/').last.contains('.');
