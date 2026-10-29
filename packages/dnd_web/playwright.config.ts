import { fileURLToPath } from 'node:url';
import { defineConfig } from '@playwright/test';

const PUERTO = 8787;
// `fileURLToPath` y no `URL.pathname`: en Windows ese último devuelve `/C:/...`.
const dist = fileURLToPath(new URL('./dist', import.meta.url));
const servidor = fileURLToPath(new URL('../dnd_server', import.meta.url));

export default defineConfig({
  testDir: './e2e',
  // Pocas pruebas (la ficha y el dashboard): reintentar escondería una falla real, y en CI no
  // hay "a veces anda".
  retries: 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: `http://127.0.0.1:${PUERTO}`,
    trace: 'retain-on-failure',
    // Solo para quien ya tiene un Chromium instalado y no quiere bajar otro
    // (`npx playwright install chromium` es lo normal, y lo que hace CI).
    launchOptions: { executablePath: process.env.PLAYWRIGHT_CHROMIUM_PATH },
  },
  // El servidor real con repositorios en memoria y una sesión falsa, sirviendo
  // el `dist` de /v2 con un personaje sembrado: ver `packages/dnd_server/test/e2e_server.dart`. Requiere
  // `npm run build` antes. `/health` no pide sesión.
  webServer: {
    command: 'dart run test/e2e_server.dart',
    cwd: servidor,
    env: { DND_WEB_V2_ROOT: dist, DND_SERVER_PORT: String(PUERTO) },
    url: `http://127.0.0.1:${PUERTO}/health`,
    timeout: 120_000,
    reuseExistingServer: false,
  },
});
