// Reads the photos with Gemini, using the student's own free key from Google
// AI Studio. The key stays in this browser (Configurações) and is sent only
// to Google.

export class GeminiError extends Error {
  /** The model is busy, over its free quota or gone; another one may work. */
  tryOther: boolean
  constructor(message: string, tryOther = false) {
    super(message)
    this.tryOther = tryOther
  }
}

/** Tried in order: free Flash models often answer "high demand" (503) and each has its own quota. */
export const models = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-flash-lite-latest', 'gemini-3.5-flash-lite']

/** Upright JPEG, at most 1600 px, so the upload is quick. */
async function toJpeg(file: Blob): Promise<{ mime: string; data: string }> {
  let blob = file
  try {
    const bmp = await createImageBitmap(file, { imageOrientation: 'from-image' })
    const scale = Math.min(1, 1600 / Math.max(bmp.width, bmp.height))
    const canvas = document.createElement('canvas')
    canvas.width = Math.round(bmp.width * scale)
    canvas.height = Math.round(bmp.height * scale)
    canvas.getContext('2d')!.drawImage(bmp, 0, 0, canvas.width, canvas.height)
    bmp.close()
    blob = await new Promise<Blob>((ok, fail) => canvas.toBlob((b) => (b ? ok(b) : fail()), 'image/jpeg', 0.85))
  } catch {
    /* send the original file */
  }
  const bytes = new Uint8Array(await blob.arrayBuffer())
  let bin = ''
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  return { mime: blob.type || 'image/jpeg', data: btoa(bin) }
}

async function send(model: string, key: string, images: { mime: string; data: string }[], prompt: string): Promise<string> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), 90_000)
  let res: Response
  try {
    res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      signal: ctrl.signal,
      headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [...images.map((i) => ({ inline_data: { mime_type: i.mime, data: i.data } })), { text: prompt }] }],
        generationConfig: { responseMimeType: 'application/json', temperature: 0, maxOutputTokens: 8000 },
      }),
    })
  } catch {
    throw new GeminiError('Sem conexão com o Gemini. Verifique a internet e tente de novo.', true)
  } finally {
    clearTimeout(timer)
  }
  if (!res.ok) {
    const msg = await res.json().then((j) => String(j?.error?.message ?? ''), () => '')
    if ([404, 429, 500, 503, 504].includes(res.status))
      throw new GeminiError(
        res.status === 429 ? 'Limite gratuito do Gemini atingido. Espere um minuto e tente de novo.' : 'O Gemini está sobrecarregado agora. Tente de novo em instantes.',
        true,
      )
    if (res.status === 400 && /api key/i.test(msg)) throw new GeminiError('Chave do Gemini inválida. Confira em Configurações.')
    if (res.status === 401 || res.status === 403) throw new GeminiError('Chave do Gemini inválida ou sem permissão. Confira em Configurações.')
    throw new GeminiError(`Algo deu errado (${res.status}). ${msg}`)
  }
  const data = await res.json()
  const text = (data?.candidates?.[0]?.content?.parts ?? [])
    .filter((p: { thought?: boolean; text?: string }) => !p.thought && typeof p.text === 'string')
    .map((p: { text: string }) => p.text)
    .join('')
  if (!text) throw new GeminiError('O Gemini não conseguiu ler essas fotos. Tente fotos mais nítidas.')
  return text
}

async function ask<T>(key: string, files: Blob[], prompt: string): Promise<T> {
  const images = await Promise.all(files.map(toJpeg))
  let last: unknown
  for (const m of models) {
    try {
      const text = await send(m, key, images, prompt)
      const start = text.indexOf('{')
      const end = text.lastIndexOf('}')
      return JSON.parse(text.slice(start, end + 1)) as T
    } catch (e) {
      last = e
      if (e instanceof GeminiError && !e.tryOther) throw e
      if (e instanceof SyntaxError) last = new GeminiError('Não consegui entender a resposta do Gemini. Tente de novo.', true)
    }
  }
  throw last
}

const dictationPrompt = `Image 1 is a page of a Callan Method book with a dictation passage. Image 2 is a student's handwritten copy of that dictation.
1. "original": transcribe ONLY the dictation passage from image 1, exactly as printed. If the page has more than one dictation or other text, use the passage that matches what the student wrote. Do not include headings like "Lesson 41" or "Dictation 59".
2. "number": the dictation number printed on the page (e.g. 59 for "Dictation 59"), or null.
3. "student": transcribe the handwriting in image 2 EXACTLY as written, letter by letter. Keep every misspelling, missing or extra word, wrong capital letter and wrong punctuation. Never correct anything, and never fill in a word from the original. If a word is illegible, write [?].
Reply with only this JSON: {"original": "...", "number": 59, "student": "..."}`

const photoPrompt = `Transcribe all the text in this photo exactly as written, in reading order, as running text (join the lines; keep paragraphs separated by a blank line). Reply with only this JSON: {"text": "..."}`

export async function readDictation(key: string, book: Blob, copy: Blob) {
  const r = await ask<{ original?: string; number?: number | null; student?: string }>(key, [book, copy], dictationPrompt)
  return { original: (r.original ?? '').trim(), student: (r.student ?? '').trim(), number: typeof r.number === 'number' ? r.number : undefined }
}

export async function readPhoto(key: string, photo: Blob) {
  const r = await ask<{ text?: string }>(key, [photo], photoPrompt)
  return (r.text ?? '').trim()
}
