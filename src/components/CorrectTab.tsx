import { useState } from 'react'
import { check, dictationNumber, trimToMatch, words } from '../lib/checker'
import type { DictationRecord } from '../lib/models'
import { GeminiError, readDictation } from '../lib/gemini'
import { Icon } from './Icon'
import { KeyCard } from './KeyCard'
import { PhotoPicker } from './PhotoPicker'

/** Two photos in, a saved correction out: no other step. */
export function CorrectTab({
  geminiKey,
  onKey,
  onDone,
  read = readDictation,
}: {
  geminiKey: string
  onKey: (k: string) => void
  onDone: (r: DictationRecord) => void
  read?: typeof readDictation
}) {
  const [book, setBook] = useState<File | null>(null)
  const [copy, setCopy] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const analyse = async () => {
    if (!book || !copy || !geminiKey) return
    setBusy(true)
    setError('')
    try {
      const { original, student, number } = await read(geminiKey, book, copy)
      if (!words(original).length) throw new GeminiError('Não encontrei a dictation na foto do livro. Tente uma foto mais nítida.')
      if (!words(student).length) throw new GeminiError('Não encontrei texto na foto do aluno. Tente uma foto mais nítida.')
      const record: DictationRecord = {
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
        date: new Date().toISOString(),
        number: number ?? dictationNumber(original),
        correction: check(trimToMatch(original, student), student),
      }
      setBook(null)
      setCopy(null)
      onDone(record)
    } catch (e) {
      setError(e instanceof GeminiError ? e.message : 'Não consegui ler as fotos. Tente de novo.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="tab">
      {!geminiKey && <KeyCard onSave={onKey} />}
      <PhotoPicker step="1" title="Texto original" hint="Foto da página do livro com a dictation" file={book} onChange={setBook} />
      <PhotoPicker step="2" title="Texto do aluno" hint="Foto do caderno com a letra do aluno" file={copy} onChange={setCopy} />
      {error && <p className="error" role="alert">{error}</p>}
      <div className="bottom-action">
        <button className="btn primary big" disabled={!book || !copy || !geminiKey} onClick={analyse}>
          <Icon name="check" /> {book && copy ? 'Corrigir' : 'Adicione as duas fotos'}
        </button>
      </div>
      {busy && (
        <div className="loading" role="status">
          <div className="spinner" />
          <p>Analisando…</p>
        </div>
      )}
    </div>
  )
}
