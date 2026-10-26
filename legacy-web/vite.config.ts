import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';

// Tauri expects a fixed port and no clearing of its terminal output.
export default defineConfig({
  plugins: [preact()],
  clearScreen: false,
  server: { port: 1420, strictPort: true },
  build: { target: 'es2022', outDir: 'dist' },
  test: { environment: 'node', include: ['tests/**/*.test.ts'] },
});
