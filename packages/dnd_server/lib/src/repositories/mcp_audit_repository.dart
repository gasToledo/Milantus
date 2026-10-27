import 'package:postgres/postgres.dart';

/// Registro de lo que hizo el MCP: qué cuenta, qué herramienta y cómo
/// terminó. Sin argumentos ni resultados: una nota o una ficha no tienen que
/// quedar copiadas en un registro que nadie mira.
abstract class McpAuditRepository {
  Future<void> record(String userId, String tool, String outcome);
}

/// Cuánto se guarda. Alcanza para mirar un abuso o un error reciente.
const Duration mcpAuditRetention = Duration(days: 90);

class PostgresMcpAuditRepository implements McpAuditRepository {
  final Session _session;
  const PostgresMcpAuditRepository(this._session);

  @override
  Future<void> record(String userId, String tool, String outcome) async {
    // El barrido va con cada inserción, como el de las sesiones con cada
    // login: es lo único que hace crecer la tabla y no suma otro proceso.
    await _session.execute(
      Sql.named('DELETE FROM mcp_audit_log WHERE created_at < @cutoff'),
      parameters: {
        'cutoff': TypedValue(
          Type.timestampWithTimezone,
          DateTime.now().toUtc().subtract(mcpAuditRetention),
        ),
      },
    );
    await _session.execute(
      Sql.named('''
        INSERT INTO mcp_audit_log (user_id, tool, outcome)
        VALUES (@userId, @tool, @outcome)
      '''),
      parameters: {
        'userId': TypedValue(Type.uuid, userId),
        'tool': TypedValue(Type.text, tool),
        'outcome': TypedValue(Type.text, outcome),
      },
    );
  }
}
