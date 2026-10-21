import { afterEach, describe, expect, it, vi } from 'vitest'
import { GeminiError, readDictation, readPhoto } from './gemini'

const photo = new Blob([new Uint8Array([1, 2, 3])], { type: 'image/jpeg' })
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status })
const answer = (obj: unknown) => reply({ candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] })

afterEach(() => vi.unstubAllGlobals())

describe('gemini', () => {
  it('reads both photos in one request', async () => {
    const fetch = vi.fn().mockResolvedValue(answer({ original: 'The cat sat.', number: 59, student: 'The cat sad.' }))
    vi.stubGlobal('fetch', fetch)
    expect(await readDictation('k'.repeat(39), photo, photo)).toEqual({ original: 'The cat sat.', number: 59, student: 'The cat sad.' })
    expect(fetch).toHaveBeenCalledTimes(1)
    const [url, init] = fetch.mock.calls[0]
    expect(url).toContain('gemini-flash-latest:generateContent')
    expect(init.headers['x-goog-api-key']).toBe('k'.repeat(39))
    expect(JSON.parse(init.body).contents[0].parts).toHaveLength(3)
  })

  it('tries another model when one is busy', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(reply({ error: { message: 'high demand' } }, 503))
      .mockResolvedValueOnce(answer({ text: 'Hello world.' }))
    vi.stubGlobal('fetch', fetch)
    expect(await readPhoto('key', photo)).toBe('Hello world.')
    expect(fetch.mock.calls[1][0]).toContain('gemini-3.6-flash')
  })

  it('stops at a bad key with a clear message', async () => {
    const fetch = vi.fn().mockResolvedValue(reply({ error: { message: 'API key not valid.' } }, 400))
    vi.stubGlobal('fetch', fetch)
    await expect(readPhoto('bad', photo)).rejects.toThrow(new GeminiError('Chave do Gemini inválida. Confira em Configurações.'))
    expect(fetch).toHaveBeenCalledTimes(1)
  })
})
