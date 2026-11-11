# Proxy delante de `zitadel-login` que le suma la hoja de estilos de Milantus.
# Ver login-skin/README.md.
#
# La configuración y los estáticos se copian a la imagen en vez de montarse
# como volúmenes a propósito: así un cambio en cualquiera de ellos cambia la
# imagen, y el `docker compose build` + `up -d` del CD recrea el contenedor
# solo. Con un bind mount, un cambio en nginx.conf no se aplicaba hasta un
# `docker compose restart login-proxy` a mano.
FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY static/ /usr/share/nginx/milantus/
