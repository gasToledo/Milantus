# Construye la imagen única del stack: el mismo contenedor sirve la API y el
# build web (ver capacidad `self-hosted-deployment`)
# porque el cliente llama a `/api` con rutas relativas al mismo origen que lo
# sirvió, sin `baseUrl` propio (`lib/api/api_client.dart`).
#
# Se construye desde la raíz del repositorio (`docker build -f
# packages/dnd_server/Dockerfile .`), porque tanto `dnd_app` como `dnd_server`
# dependen de `dnd_engine` por ruta relativa del monorepo.
#
# Las etiquetas de imagen usan `stable`, no una versión fija: seguir builds
# reproducibles al pie de la letra implica fijar un dígito de versión concreto
# (y actualizarlo a mano) tanto acá como en la sección "Comandos" de
# `CLAUDE.md`; se deja así por simplicidad de un despliegue de una sola
# cuenta, no por ser la práctica recomendada en un stack con más operadores.
#
# `ghcr.io/cirruslabs/flutter` solo publica los *minor* de Flutter: `stable`
# apunta al mismo digest que `3.44.0` y no existe tag para los hotfix
# (`3.44.8`). Por eso `environment.sdk` de `dnd_app` no puede llevar una cota
# de patch aunque el SDK local sí lo tenga: acá nunca va a haber una imagen
# que la cumpla.

# El pub-cache vive en un caché de BuildKit (`--mount=type=cache`) y no en una
# capa: el `COPY` del código invalida todo lo que viene después en cada
# despliegue, y sin esto cada deploy volvía a bajar todas las dependencias.
# El caché persiste en el runner entre builds. Se monta también en el paso que
# compila, porque `package_config.json` apunta a esos archivos y el montaje
# solo existe durante el `RUN` que lo declara. Un id por etapa: las dos
# corren en paralelo y no comparten SDK.

# ---- Etapa 1: build del cliente web (Flutter) ----
FROM ghcr.io/cirruslabs/flutter:stable AS web-build
ENV PUB_CACHE=/pub-cache
WORKDIR /workspace
COPY packages/dnd_engine ./packages/dnd_engine
COPY packages/dnd_app ./packages/dnd_app
WORKDIR /workspace/packages/dnd_app
RUN --mount=type=cache,id=pub-flutter,target=/pub-cache flutter pub get
RUN --mount=type=cache,id=pub-flutter,target=/pub-cache flutter build web --release

# ---- Etapa 2: compilación del servidor (Dart) ----
FROM dart:stable AS server-build
ENV PUB_CACHE=/pub-cache
WORKDIR /workspace
COPY packages/dnd_engine ./packages/dnd_engine
COPY packages/dnd_server ./packages/dnd_server
WORKDIR /workspace/packages/dnd_server
RUN --mount=type=cache,id=pub-dart,target=/pub-cache dart pub get
RUN --mount=type=cache,id=pub-dart,target=/pub-cache dart compile exe bin/server.dart -o /workspace/dnd_server_bin

# ---- Etapa 3: build del cliente React (Node), servido bajo /v2 ----
# Versión de Node fijada a propósito (a diferencia de las otras etapas): el
# `package-lock.json` ya fija las dependencias y acá solo falta que el runtime
# que las instala no se mueva solo. El caché de npm sigue la misma lógica que
# el pub-cache de arriba: vive en BuildKit y no en una capa, así el `COPY` del
# código no obliga a bajar todo de nuevo. `package*.json` se copia antes que
# el resto para que `npm ci` solo se repita cuando cambian las dependencias.
FROM node:22-alpine AS web-v2-build
WORKDIR /workspace/packages/dnd_web
COPY packages/dnd_web/package.json packages/dnd_web/package-lock.json ./
RUN --mount=type=cache,id=npm-web-v2,target=/root/.npm npm ci
COPY packages/dnd_web ./
RUN npm run build

# ---- Etapa 4: runtime mínimo ----
# `dart compile exe` produce un binario nativo: no hace falta el SDK de Dart
# ni el de Flutter en la imagen final, así que ninguna clave ni credencial de
# build llega a la imagen publicada (no hay ninguna en primer lugar: la
# configuración se lee de variables de entorno recién al arrancar, ver
# `lib/src/config.dart`).
FROM debian:bookworm-slim AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=server-build /workspace/dnd_server_bin ./dnd_server
COPY --from=web-build /workspace/packages/dnd_app/build/web ./web
COPY --from=web-v2-build /workspace/packages/dnd_web/dist ./web-v2
# El catálogo SRD, para las fichas calculadas y la búsqueda del MCP: el
# binario no lleva los assets del engine adentro.
COPY packages/dnd_engine/lib/assets/srd_2024 ./content

ENV DND_WEB_ROOT=/app/web
ENV DND_WEB_V2_ROOT=/app/web-v2
ENV DND_CONTENT_DIR=/app/content
EXPOSE 8080

ENTRYPOINT ["/app/dnd_server"]
