import { build } from 'esbuild'
import { cp, mkdir, rm } from 'node:fs/promises'
const output = new URL('../Sources/Mori/Resources/Web/', import.meta.url)
await rm(output, { recursive: true, force: true })
await mkdir(output, { recursive: true })
await build({
  entryPoints: ['src/main.ts'], bundle: true, minify: true, splitting: false,
  format: 'iife', target: ['safari17'], outfile: new URL('editor.js', output).pathname,
  loader: { '.woff2': 'file', '.woff': 'file', '.ttf': 'file' },
  assetNames: 'fonts/[name]-[hash]', legalComments: 'linked'
})
await cp('src/index.html', new URL('index.html', output))
console.log('离线编辑器已打包。')
