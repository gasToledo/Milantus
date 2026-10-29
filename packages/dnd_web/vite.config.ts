import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  // El servidor lo monta bajo `/v2/` (DND_WEB_V2_ROOT): sin esta base, los
  // assets del HTML apuntarían a `/assets/...`, que es del cliente de Flutter.
  base: '/v2/',
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
