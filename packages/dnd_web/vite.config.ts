import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import pkg from './package.json' with { type: 'json' };

export default defineConfig({
  base: '/',
  // La versión visible sale de `package.json` y entra al bundle al construir:
  // es la del despliegue que sirvió este HTML, sin un pedido más.
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  // Hidden: genera los .map sin el comentario que hace que el navegador los
  // baje solo; se usan a mano para leer una traza del log (ver despliegue.md).
  build: { sourcemap: 'hidden' },
  plugins: [react(), tailwindcss()],
  server: {
    // En desarrollo la API vive en el servidor Dart, no acá. Con el proxy el
    // navegador ve un solo origen y la cookie de sesión viaja igual que en
    // producción.
    proxy: {
      '/api': 'http://localhost:8080',
      '/auth': 'http://localhost:8080',
    },
  },
});
