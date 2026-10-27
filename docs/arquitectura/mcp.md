# MCP del Modo DM

Claude Code (o cualquier cliente MCP) se conecta a una cuenta y trabaja sobre
su Modo DM: lee y escribe campañas, capítulos, notas del cuaderno y PNJ. Vive
dentro del servidor, en `POST /mcp`; no hay nada que instalar.

## Cómo se conecta

En **Ajustes → Claude Code** se crea un token con nombre. La app lo muestra
una sola vez, ya armado dentro del comando:

```bash
claude mcp add --transport http milantus https://<dominio>/mcp --header "Authorization: Bearer mlt_…"
```

## El token

- Tabla `api_tokens` (migración `0013_api_tokens`). Como las sesiones, se
  guarda solo el hash SHA-256: un volcado de la base no alcanza para usarlo.
- Prefijo `mlt_`, para reconocerlo si aparece pegado donde no debe.
- Vence a los 90 días (`apiTokenTtl`). Revocar es borrar la fila. Cada uso
  anota `last_used_at` en la misma sentencia que lo valida.
- Se administra con `GET`, `POST` y `DELETE /api/tokens`, que piden la cookie
  como el resto de `/api`. Revocar uno ajeno responde 404, igual que uno que
  no existe.

## La frontera

El Bearer se acepta **solo en `/mcp`**. Todo `/api` sigue autenticando con la
cookie: un token filtrado no abre la API que usa el navegador, y una página
ajena no puede usar el token por el usuario, porque el navegador no lo manda
solo.

Las herramientas no tocan los repositorios. Llaman al mismo enrutado de la
API por adentro, con la cuenta del token puesta en el contexto de shelf
(`requireSession` la acepta: una petición HTTP no puede escribir ese
contexto). Así la validación y la autorización del `WHERE` existen una sola
vez, y lo ajeno le responde a Claude lo mismo que a la app: que no existe.

## Protocolo

HTTP «Streamable» en su forma mínima (`lib/src/mcp/mcp_handler.dart`): cada
`POST` trae un mensaje JSON-RPC y se contesta con JSON, sin SSE ni sesión.
`initialize`, `ping`, `tools/list` y `tools/call`; un `GET` responde 405.
Ninguna herramienta avisa nada por su cuenta, así que el túnel no sostiene
conexiones abiertas.

Las herramientas reciben argumentos simples y el servidor arma los documentos
con los modelos del engine: Claude no maneja `schemaVersion` ni genera ids.
Editar aplica solo los campos que llegan sobre el documento guardado, así no
pisa lo que la app guardó y Claude no conoce (escenas de música, objetos).

## Lo que queda afuera

- **Borrar.** Con un agente, borrar sigue siendo una acción de la persona,
  desde la app.
- **Cerrar capítulos.** Reparte avisos a los jugadores; es una decisión de
  mesa.
- **Combate y música.** Son de la sesión en vivo.
- **Fichas de los jugadores.** El DM no escribe fichas ajenas; el MCP muestra
  solo nombre y nivel.
- **PNJ con estadísticas.** El servidor no carga el bestiario; por el MCP se
  crean PNJ narrativos y el bloque se elige en la app.

## Qué probar al tocar esto

`packages/dnd_server/test/mcp_test.dart` cubre el token (sin token, vencido,
revocado, ajeno) y que lo ajeno no exista por el MCP. Corre contra el doble en
memoria: el SQL de `api_token_repository.dart` se revisa a mano y se prueba
con el stack real.
