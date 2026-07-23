// Sovereign Post Office — NUI build config
// base: './'          — RedM NUI resolves bundled assets relatively.
// assetsInlineLimit:0 — never inline assets as data: URIs; keep them as real
//                       files under dist/assets so fxmanifest can ship them.
// Everything is self-contained: no CDN, no external fetches (standing rule).
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: './',
  plugins: [react()],
  build: {
    outDir: 'dist',
    assetsInlineLimit: 0,
  },
})
