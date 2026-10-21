import { createWorker, type Worker } from 'tesseract.js'

// Reads the text in a photo inside the browser (Tesseract, offline): the
// engine and the English model are served with the app itself.

let worker: Promise<Worker> | null = null

const local = (path: string) => new URL(import.meta.env.BASE_URL + path, location.href).href

function getWorker(): Promise<Worker> {
  worker ??= createWorker('eng', 1, {
    workerPath: local('tesseract/worker.min.js'),
    corePath: local('tesseract/'),
    langPath: local('tesseract/lang'),
    gzip: true,
  }).catch((e) => {
    worker = null
    throw e
  })
  return worker
}

/** Starts the engine early so the first photo reads faster. */
export function warmUp() {
  getWorker().catch(() => {})
}

/** Upright, at most 2000 px, so phone photos read fast and the right way up. */
async function prepare(file: Blob): Promise<Blob | HTMLCanvasElement> {
  try {
    const bmp = await createImageBitmap(file, { imageOrientation: 'from-image' })
    const scale = Math.min(1, 2000 / Math.max(bmp.width, bmp.height))
    const canvas = document.createElement('canvas')
    canvas.width = Math.round(bmp.width * scale)
    canvas.height = Math.round(bmp.height * scale)
    const ctx = canvas.getContext('2d')!
    ctx.filter = 'grayscale(1) contrast(1.2)'
    ctx.drawImage(bmp, 0, 0, canvas.width, canvas.height)
    bmp.close()
    return canvas
  } catch {
    return file
  }
}

/** Joins the lines into running text, undoing words split with a hyphen at a line end. */
export const tidy = (raw: string) =>
  raw
    .replace(/(\w)-\s*\n\s*(\w)/g, '$1$2')
    .replace(/\s+/g, ' ')
    .trim()

export async function readText(file: Blob): Promise<string> {
  const w = await getWorker()
  const { data } = await w.recognize(await prepare(file))
  return tidy(data.text)
}
