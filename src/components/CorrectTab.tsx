import { useState } from 'react'
import { check, dictationNumber, trimToMatch, words } from '../lib/checker'
import type { DictationRecord } from '../lib/models'
import { readText } from '../lib/ocr'
import { Icon } from './Icon'
import { PhotoPicker } from './PhotoPicker'

/** Two photos in, a saved correction out: no other step. */
export function CorrectTab({ onDone, read = readText }: { onDone: (r: DictationRecord) => void; read?: (f: Blob) => Promise<string> }) {
  const [book, setBook] = useState<File | null>(null)
  const [copy, setCopy] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const analyse = async () => {
    if (!book || !copy) return
    setBusy(true)
    setError('')
    try {
      const page = await read(book)
      const written = await read(copy)
      if (!words(page).length) throw new Error('Não encontrei texto na foto do livro. Tente uma foto mais nítida.')
      if (!words(written).length) throw new Error('Não encontrei texto na foto do aluno. Tente uma foto mais nítida.')
      const record: DictationRecord = {
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
        date: new Date().toISOString(),
        number: dictationNumber(page),
        correction: check(trimToMatch(page, written), written),
      }
      setBook(null)
      setCopy(null)
      onDone(record)
    } catch (e) {
      setError(e instanceof Error && e.message.startsWith('Não') ? e.message : 'Não consegui ler as fotos. Tente fotos mais nítidas e retas.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="tab">
      <PhotoPicker step="1" title="Texto original" hint="Foto da página do livro com a dictation" file={book} onChange={setBook} />
      <PhotoPicker step="2" title="Texto do aluno" hint="Foto do caderno com a letra do aluno" file={copy} onChange={setCopy} />
      {error && <p className="error" role="alert">{error}</p>}
      <div className="bottom-action">
        <button className="btn primary big" disabled={!book || !copy} onClick={analyse}>
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
