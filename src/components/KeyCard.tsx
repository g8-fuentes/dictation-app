import { useState } from 'react'
import { Icon } from './Icon'

export const keyLink = 'https://aistudio.google.com/apikey'

/** Asks once for the Gemini key; it is saved only in this browser. */
export function KeyCard({ onSave }: { onSave: (k: string) => void }) {
  const [key, setKey] = useState('')
  return (
    <section className="card key-card">
      <h2>Chave do Gemini</h2>
      <p className="muted">
        Para ler as fotos, cole sua chave gratuita do Google AI Studio. Ela fica salva só neste celular.{' '}
        <a href={keyLink} target="_blank" rel="noreferrer">
          Pegar minha chave
        </a>
      </p>
      <div className="key-row">
        <input
          className="text"
          type="password"
          autoComplete="off"
          placeholder="Cole a chave aqui"
          value={key}
          onChange={(e) => setKey(e.target.value)}
          aria-label="Chave do Gemini"
        />
        <button className="btn primary" disabled={key.trim().length < 20} onClick={() => onSave(key.trim())}>
          <Icon name="check" size={20} /> Salvar
        </button>
      </div>
    </section>
  )
}
