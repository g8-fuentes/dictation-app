// Copies the OCR engine and the English model into public/ so the app reads
// photos offline, without any CDN.
import { cpSync, mkdirSync } from 'node:fs'

const out = 'public/tesseract'
mkdirSync(`${out}/lang`, { recursive: true })
cpSync('node_modules/tesseract.js/dist/worker.min.js', `${out}/worker.min.js`)
for (const f of [
  'tesseract-core-lstm.wasm.js',
  'tesseract-core-simd-lstm.wasm.js',
  'tesseract-core-relaxedsimd-lstm.wasm.js',
]) {
  cpSync(`node_modules/tesseract.js-core/${f}`, `${out}/${f}`)
}
cpSync('node_modules/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz', `${out}/lang/eng.traineddata.gz`)
