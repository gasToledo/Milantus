# MCP de Milantus

Claude se conecta a Milantus como conector personalizado y trabaja sobre la
cuenta de quien lo conectó: sus personajes, las campañas que dirige o en las
que juega, su homebrew y el catálogo SRD. Vive en el mismo servidor, en
`POST /mcp`. Cómo configurarlo está en
[Despliegue](../operaciones/despliegue.md#conector-mcp-para-claude).

## Autorización

OAuth 2.1 con PKCE contra **Zitadel**, que es el servidor de autorización.
Milantus no emite tokens: los valida.

- `/.well-known/oauth-protected-resource/mcp` (RFC 9728) dice que el recurso
  es `…/mcp`, que el emisor es Zitadel y qué scopes pedir. Un 401 de `/mcp`
  lleva `WWW-Authenticate: Bearer resource_metadata="…"`, que es por donde
  Claude lo descubre.
- `requireMcpToken` (`lib/src/auth/mcp_token.dart`) valida el access token
  como **JWT con JWKS**: firma contra `/oauth/v2/keys`, emisor, vigencia y que
  la audiencia incluya el proyecto de Milantus. Sin llamada de red por pedido;
  las claves se recargan ante un `kid` desconocido, a lo sumo una vez por
  minuto. Por eso la app de Zitadel emite *Token Type: JWT*.
- Zitadel no soporta el parámetro `resource` (RFC 8707): la audiencia se pide
  como scope (`urn:zitadel:iam:org:project:id:{proyecto}:aud`), que la
  metadata publica y Claude pide solo.
- El `sub` se resuelve con `findOrCreateAccount`, la misma cuenta del login
  web. `requireSession` y la cookie no cambian, y el Bearer no abre `/api`.
- **Cliente:** un client ID fijo, público, registrado a mano en Zitadel. Zitadel
  no tiene CIMD todavía, y su registro dinámico habría que abrirlo a
  cualquiera. Cuando publique CIMD, Claude puede usar su identidad publicada
  sin tocar el servidor.

### Lectura y escritura

`milantus:lectura` y `milantus:escritura` (escritura incluye lectura). Zitadel
no documenta scopes propios en el token, así que el verificador acepta los dos
caminos: el claim `scope` o los roles del proyecto `milantus_lectura` /
`milantus_escritura`. La metadata pide hoy los roles; si Zitadel copiara los
scopes propios, se cambia `mcpRequestedScopes` y nada más. Una herramienta sin
el permiso responde 403 con `error="insufficient_scope"`, y Claude vuelve a
autorizarse pidiéndolo.

## Las herramientas

`lib/src/app_mcp.dart`. Llaman a los repositorios con la cuenta del token: la
autorización es la del `WHERE`, y lo ajeno responde igual que lo inexistente.
Las validaciones que antes vivían solo en un handler (la nota en un capítulo
propio, crear y editar un PNJ) son funciones que usan los dos caminos.

| Lectura | Escritura |
|---|---|
| `listar_personajes`, `ver_personaje` | `aplicar_dano_o_curacion` |
| `listar_campanas`, `ver_campana` | `gestionar_condicion`, `descanso` |
| `ver_encuentro`, `buscar_catalogo` | `crear_nota` |
| `listar_homebrew`, `listar_pnj`, `ver_eventos` | `crear_pnj`, `actualizar_pnj`, `crear_homebrew` |

- **La ficha** sale de `CharacterCompiler` con la Forma Salvaje y el Cansancio
  encima, como en la app. El servidor carga el catálogo SRD al arrancar
  (`DND_CONTENT_DIR`, que el Dockerfile copia a la imagen) y le suma el
  homebrew de la cuenta en cada llamada.
- **Daño, condiciones y descansos** usan `CombatOps` sobre un personaje
  propio. El DM no escribe fichas ajenas tampoco por acá.
- **Campañas:** la vista del DM si la dirige; si juega, `playerView()` con la
  misma poda que `/api/characters/<id>/campaigns`.
- Esquemas con `additionalProperties: false`, anotaciones `readOnlyHint` /
  `destructiveHint`, salida en `structuredContent` más un resumen, y listados
  paginados con `cursor`.

Afuera: borrar, importar respaldos, generar retratos, canjear códigos y
`/api/feedback`.

## Protocolo y operación

- HTTP «Streamable» en su forma mínima (`lib/src/mcp/mcp_handler.dart`): un
  POST por mensaje, respuesta JSON, sin SSE ni sesión. Escrito a mano: `dart_mcp`
  no trae Streamable HTTP y `mcp_dart` es una dependencia grande para cuatro
  métodos.
- Un `Origin` que no sea la propia app responde 403.
- Tope de 60 llamadas por minuto y por cuenta (429).
- `mcp_audit_log`: cuenta, herramienta y resultado, sin argumentos, 90 días.

## Qué probar al tocar esto

`packages/dnd_server/test/mcp_test.dart`, con tokens firmados por una clave del
propio test: sin token, vencido y con otra audiencia (401 con la metadata);
solo lectura intentando escribir (403); `Origin` ajeno; y que la ficha y la
campaña de otra cuenta no se vean ni se toquen, comparando el documento antes y
después. Corre contra los dobles en memoria: el SQL de `mcp_audit_repository`
y la conexión con Zitadel se prueban con el stack real.
