# Login personalizado (login-skin)

Personaliza el aspecto del login de Zitadel (Login V2, el contenedor
`zitadel-login`) más allá de lo que permite el Branding de la consola: imagen
de fondo, tarjeta translúcida, tipografía propia.

## Cómo funciona

```
cloudflared → login-proxy (nginx, esta carpeta) → zitadel-login
                  └─ /ui/v2/login/milantus/* sale de static/
```

`login-proxy` hace dos cosas que el túnel no puede hacer:

1. **Sirve `static/` bajo el mismo hostname que el login**
   (`https://${ZITADEL_EXTERNAL_DOMAIN}/ui/v2/login/milantus/…`). La CSP del
   login solo admite imágenes, fuentes y hojas de estilo del mismo origen: un
   fondo servido desde `APP_PUBLIC_DOMAIN` o una fuente de Google Fonts quedan
   bloqueados.
2. **Agrega `<link rel="stylesheet" href="…/login.css">` a cada página HTML**
   del login, con `sub_filter` de nginx. Ese HTML lo genera `zitadel-login` y
   no tiene ningún punto de extensión para CSS propio.

Se descartaron dos alternativas:

- **Compilar una imagen propia del login** con las variables
  `NEXT_PUBLIC_THEME_*` (diseño `side-by-side`, apariencia `glass`, imagen de
  fondo). Esas variables se compilan dentro del JavaScript, así que hay que
  construir el monorepo entero de Zitadel en cada actualización. Es la única
  forma de cambiar la *estructura* del login; para el aspecto alcanza con CSS.
- **Un Cloudflare Worker** que haga lo mismo. Funciona, pero deja parte del
  login fuera del repo y del despliegue normal.

## Qué se personaliza dónde

| Qué | Dónde |
|---|---|
| Colores de botones y enlaces, logo, ícono | Branding de la consola de Zitadel (claro **y** oscuro, y «Aplicar configuración») |
| Textos | `SetHostedLoginTranslation` de la Settings V2 API (la consola solo cambia los del login V1) |
| Fondo, tarjeta, tipografía, cualquier otro ajuste visual | `static/login.css` |
| Imagen de fondo | `static/fondo.webp` |
| Fuente | `static/fuente.woff2` (y quitar el comentario en `login.css`) |

El `fondo.webp` incluido es un provisorio generado (un resplandor cálido sobre
fondo oscuro). Reemplazalo por la ilustración que quieras con el mismo nombre;
`login.css` le pone encima un velo para que el formulario se lea igual.

## Después de cada actualización de Zitadel

Los selectores de `login.css` apuntan a clases de Tailwind del login oficial
(revisadas contra v4.20.0). No son una API estable. Después de subir
`ZITADEL_VERSION`, abrí el login en modo claro y oscuro: si algo dejó de
aplicarse, buscá las clases nuevas con las DevTools y ajustá el selector. Un
selector que no coincide no rompe nada: esa parte vuelve al aspecto por
defecto.

## Si login-proxy falla

El login no carga (502), porque el túnel pasa por acá. Para salir del paso
sin tocar el repo, volvé a apuntar la regla del login en
`cloudflared/config.yml` a `http://zitadel-login:3000` y reiniciá
`cloudflared` (ver «Puesta en marcha», paso 3, al revés).

## Puesta en marcha

1. Commit y push. El CD construye `login-proxy` y lo levanta. Todavía no
   cambia nada: el túnel sigue mandando el login directo a `zitadel-login`.
2. En el host, comprobá que el proxy esté sano:

   ```sh
   docker compose ps login-proxy        # healthy
   ```

3. En el host, en `cloudflared/config.yml` (no versionado), cambiá la regla
   del login como en `cloudflared/config.example.yml`:

   ```yaml
   - hostname: auth.tu-dominio.com
     path: ^/ui/v2/login(/.*)?$
     service: http://login-proxy:8080
   ```

   y reiniciá el túnel:

   ```sh
   docker compose restart cloudflared
   ```

   El orden importa: si el túnel apunta a `login-proxy` antes de que exista,
   el login da 502.

4. Probá en una ventana privada: que se vea el fondo, y el flujo completo
   (iniciar sesión, registrarse, recuperar contraseña, cerrar sesión). En el
   código fuente de la página tiene que aparecer el `<link>` a
   `/ui/v2/login/milantus/login.css`.

Desde ahí, un cambio en esta carpeta se despliega solo con el CD (está en la
lista del paso `gate`). Los navegadores toman el CSS nuevo en una hora como
mucho (`expires 1h` en `nginx.conf`); para verlo antes, recargá sin caché.
