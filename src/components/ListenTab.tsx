import { useEffect, useState } from 'react'
import { readText } from '../lib/ocr'
import { canSpeak, readAll, stopSpeaking, type VoiceSettings } from '../lib/voice'
import { Icon } from './Icon'
import { PhotoPicker } from './PhotoPicker'

/** Photo of any text in, the whole text read aloud by the phone's own voice. */
export function ListenTab({ voice, read = readText }: { voice: VoiceSettings; read?: (f: Blob) => Promise<string> }) {
  const [file, setFile] = useState<File | null>(null)
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [playing, setPlaying] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => () => stopSpeaking(), [])

  const play = async (t: string) => {
    setPlaying(true)
    await readAll(t, voice)
    setPlaying(false)
  }

  const pick = async (f: File | null) => {
    stopSpeaking()
    setPlaying(false)
    setFile(f)
    setText('')
    setError('')
    if (!f) return
    setBusy(true)
    try {
      const t = await read(f)
      if (!t.trim()) throw new Error()
      setText(t)
      play(t)
    } catch {
      setError('Não encontrei texto nessa foto. Tente uma foto mais nítida.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="tab">
      <PhotoPicker title="Foto do texto" hint="Tire ou escolha a foto e o texto é lido em voz alta" file={file} onChange={pick} />
      {!canSpeak() && <p className="error">Este navegador não tem voz. Use o Chrome.</p>}
      {error && <p className="error" role="alert">{error}</p>}
      {text && (
        <section className="card">
          <div className="section-head">
            <h2>Texto</h2>
            {playing ? (
              <button className="btn tonal" onClick={() => (stopSpeaking(), setPlaying(false))}>
                <Icon name="stop" /> Parar
              </button>
            ) : (
              <button className="btn primary" onClick={() => play(text)}>
                <Icon name="play" /> Ouvir tudo
              </button>
            )}
          </div>
          <textarea className="text" value={text} onChange={(e) => setText(e.target.value)} rows={8} aria-label="Texto lido" />
          <p className="muted">Se alguma palavra saiu errada, corrija aqui antes de ouvir de novo.</p>
        </section>
      )}
      {busy && (
        <div className="loading" role="status">
          <div className="spinner" />
          <p>Lendo o texto…</p>
        </div>
      )}
    </div>
  )
}
