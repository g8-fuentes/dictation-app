import { useEffect, useRef, useState } from 'react'
import { canListen, Listener } from '../lib/listen'
import type { DictationRecord } from '../lib/models'
import { recordTitle } from '../lib/models'
import { comparePronunciation, pronunciationScore, type SpokenWord } from '../lib/pronunciation'
import { GeminiError } from '../lib/gemini'
import { readText } from '../lib/ocr'
import { formatDate } from '../lib/store'
import { say, stopSpeaking, type VoiceSettings } from '../lib/voice'
import { Icon } from './Icon'
import { PhotoPicker } from './PhotoPicker'

/** The student reads the dictation aloud; words heard differently are flagged. */
export function PronunciationTab({
  history,
  voice,
  read = readText,
}: {
  history: DictationRecord[]
  voice: VoiceSettings
  read?: (f: Blob) => Promise<string>
}) {
  const [source, setSource] = useState<string>('') // record id, or 'photo'
  const [photo, setPhoto] = useState<File | null>(null)
  const [photoText, setPhotoText] = useState('')
  const [busy, setBusy] = useState(false)
  const [recording, setRecording] = useState(false)
  const [heard, setHeard] = useState('')
  const [result, setResult] = useState<SpokenWord[] | null>(null)
  const [error, setError] = useState('')
  const listener = useRef(new Listener())

  const fromPhoto = source === 'photo' || (!source && !history.length)
  const record = fromPhoto ? undefined : history.find((r) => r.id === source) ?? history[0]
  const text = fromPhoto ? photoText : record?.correction.originalText ?? ''

  useEffect(() => () => {
    listener.current.stop()
    stopSpeaking()
  }, [])

  const pickPhoto = async (f: File | null) => {
    setPhoto(f)
    setPhotoText('')
    setResult(null)
    if (!f) return
    setBusy(true)
    try {
      setPhotoText(await read(f))
    } catch (e) {
      setError(e instanceof GeminiError ? e.message : 'Não consegui ler a foto.')
    } finally {
      setBusy(false)
    }
  }

  const start = () => {
    stopSpeaking()
    setError('')
    setHeard('')
    setResult(null)
    setRecording(true)
    listener.current.start(voice.british ? 'en-GB' : 'en-US', setHeard, (e) => {
      setRecording(false)
      setError(e === 'unsupported' ? 'Este navegador não reconhece fala. Use o Chrome.' : 'Permita o uso do microfone para gravar.')
    })
  }

  const finish = async () => {
    const said = await listener.current.stop()
    setRecording(false)
    if (!said.trim()) return setError('Não ouvi nada. Fale perto do microfone e tente de novo.')
    setResult(comparePronunciation(text, said))
  }

  const score = result ? pronunciationScore(result) : 0
  const review = result?.filter((w) => w.status !== 'ok') ?? []

  return (
    <div className="tab">
      <section className="card">
        <h2>O que você vai ler</h2>
        <select
          className="select"
          value={fromPhoto ? 'photo' : record?.id}
          onChange={(e) => (setSource(e.target.value), setResult(null))}
          aria-label="Texto para ler"
        >
          {history.map((r) => (
            <option key={r.id} value={r.id}>
              {recordTitle(r)} · {formatDate(r.date)}
            </option>
          ))}
          <option value="photo">Foto de outro texto</option>
        </select>
        {!fromPhoto && <p className="reading">{text}</p>}
      </section>

      {fromPhoto && <PhotoPicker title="Texto para ler" hint="Foto do texto que você vai ler em voz alta" file={photo} onChange={pickPhoto} />}
      {fromPhoto && photoText && (
        <section className="card">
          <textarea className="text" value={photoText} onChange={(e) => setPhotoText(e.target.value)} rows={6} aria-label="Texto" />
        </section>
      )}

      {!canListen() && <p className="error">Este navegador não reconhece fala. Use o Chrome.</p>}
      {error && <p className="error" role="alert">{error}</p>}

      {text && canListen() && (
        <section className="card center">
          {recording ? (
            <>
              <button className="mic on" onClick={finish} aria-label="Parar gravação">
                <Icon name="stop" size={36} />
              </button>
              <p>Gravando… leia o texto e toque para terminar.</p>
              {heard && <p className="muted heard">{heard}</p>}
            </>
          ) : (
            <>
              <button className="mic" onClick={start} aria-label="Gravar">
                <Icon name="mic" size={36} />
              </button>
              <p>Toque e leia o texto em voz alta.</p>
            </>
          )}
        </section>
      )}

      {result && (
        <section className="card">
          <div className="section-head">
            <h2>Resultado</h2>
            <span className={`pill ${score >= 85 ? 'good' : score >= 60 ? 'mid' : 'bad'}`}>{score}% claro</span>
          </div>
          <p className="spoken">
            {result.map((w, i) => (
              <button key={i} className={`word ${w.status}`} onClick={() => say(w.word, voice)}>
                {w.word}
              </button>
            ))}
          </p>
          {review.length > 0 ? (
            <>
              <h3>Para treinar</h3>
              <ul className="mistakes">
                {review.map((w, i) => (
                  <li key={i}>
                    <div className="m-words">
                      <strong>{w.word}</strong>
                      <span className="muted">{w.status === 'skipped' ? 'não ouvi' : `soou como “${w.heard}”`}</span>
                      <button className="btn text" onClick={() => say(w.word, voice, voice.rate * 0.8)}>
                        <Icon name="speaker" size={18} /> Ouvir
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            </>
          ) : (
            <p>Todas as palavras foram entendidas. Muito bem!</p>
          )}
          <p className="muted">É uma estimativa feita pelo reconhecimento de voz do navegador, não um professor.</p>
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
