import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api/intake': {
        target: 'http://localhost:5678',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/intake/, '/webhook/truespend-intake'),
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
})
