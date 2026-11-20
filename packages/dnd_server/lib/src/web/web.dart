import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// `Cache-Control` de `index.html` (y de todo lo que no lleve huella). El HTML
/// es lo que apunta al bundle vigente, así que tiene que revalidar siempre.
///
/// `private` está por Cloudflare, la única caché compartida en el camino: con
/// `no-cache` a secas el borde guardaba el archivo y le reescribía la cabecera
/// al navegador a `max-age=14400`, y un despliegue tardaba hasta cuatro horas
/// en llegar.
const String webIndexCacheControl = 'private, no-cache';

/// Los archivos de `assets/` los emite Vite con el hash del contenido en el
/// nombre (`index-Dh3k9a.js`): una versión nueva es otra URL, así que la
/// vieja nunca queda desactualizada y puede cachearse un año sin revalidar.
const String webAssetCacheControl = 'public, max-age=31536000, immutable';

/// Sirve el build de `packages/dnd_web` en la raíz del sitio.
///
/// Devuelve `null` si [root] no existe: quien lo monta decide qué responder.
/// Una ruta de cliente (`/personajes/3`) no es un archivo y cae a
/// `index.html` para que el router de React la resuelva; un archivo que falta
/// (`/assets/viejo.js`) en cambio es un 404 de verdad, porque devolverle HTML
/// a un `<script>` esconde el despliegue roto detrás de un error de sintaxis.
Handler? buildWebHandler(String root) {
  if (!Directory(root).existsSync()) return null;
  final files = createStaticHandler(root, defaultDocument: 'index.html');

  return (Request request) async {
    var response = await files(request);
    final path = request.url.path;

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
        'cache-control': isAsset ? webAssetCacheControl : webIndexCacheControl,
      },
    );
  };
}

bool _looksLikeFile(String path) => path.split('/').last.contains('.');
