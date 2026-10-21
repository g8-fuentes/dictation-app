import { useEffect, useState } from 'react'
import type { DictationRecord, Mistake } from '../lib/models'
import { markCorrect, recordTitle } from '../lib/models'
import { dictate, say, stopSpeaking, type VoiceSettings } from '../lib/voice'
import { formatDate } from '../lib/store'
import { Icon } from './Icon'

export function ResultView({
  record,
  voice,
  onChange,
  onBack,
}: {
  record: DictationRecord
  voice: VoiceSettings
  onChange: (r: DictationRecord) => void
  onBack: () => void
}) {
  const c = record.correction
  const [playing, setPlaying] = useState(-2)
  const [slow, setSlow] = useState(false)

  useEffect(() => () => stopSpeaking(), [])

  const play = () =>
    dictate(
      c.segments.map((s) => s.original),
      voice,
      { pauseMs: slow ? 2500 : 900, rate: slow ? voice.rate * 0.75 : voice.rate, onPart: (i) => setPlaying(i === -1 ? -2 : i) },
    )
  const stop = () => {
    stopSpeaking()
    setPlaying(-2)
  }
  const accept = (m: Mistake) => onChange({ ...record, correction: markCorrect(c, m) })

  const score = Number(c.score)
  const tone = score >= 8 ? 'good' : score >= 5 ? 'mid' : 'bad'

  return (
    <div className="tab result">
      <div className="result-head">
        <button className="icon-btn" aria-label="Voltar" onClick={onBack}>
          <Icon name="back" />
        </button>
        <div>
          <h1>{recordTitle(record)}</h1>
          <small>{formatDate(record.date)}</small>
        </div>
      </div>

      <section className={`card score ${tone}`}>
        <div className="big-score">{c.score}</div>
        <div>
          <strong>{c.mistakes.length === 0 ? 'Sem erros!' : `${c.mistakes.length} ${c.mistakes.length === 1 ? 'erro' : 'erros'}`}</strong>
          <p>Pontuação e maiúsculas valem meio ponto.</p>
        </div>
      </section>

      <section className="card">
        <div className="section-head">
          <h2>Ouvir a dictation</h2>
          <label className="switch">
            <input type="checkbox" checked={slow} onChange={(e) => setSlow(e.target.checked)} /> Devagar
          </label>
        </div>
        <p className="muted">Lida em partes com pausa, como o professor dita. Toque numa palavra para ouvir só ela.</p>
        <button className="btn primary" onClick={play} disabled={playing !== -2}>
          <Icon name="play" /> Ouvir com pausas
        </button>
      </section>

      <section className="card">
        <h2>Texto dividido</h2>
        <ol className="segments">
          {c.segments.map((s, i) => (
            <li key={i} className={playing === i ? 'now' : ''}>
              <span className="seg-n">{i + 1}</span>
              <div>
                <p className="original">
                  {s.original.split(' ').map((w, j) => (
                    <button key={j} className="word" onClick={() => say(w, voice)}>
                      {w}
                    </button>
                  ))}
                </p>
                <p className="copy">
                  {s.tokens.map((t, j) =>
                    t.s === 'ok' ? (
                      <span key={j}>{t.t} </span>
                    ) : t.s === 'wrong' ? (
                      <span key={j}>
                        <del>{t.t}</del> <ins>{t.c}</ins>{' '}
                      </span>
                    ) : t.s === 'missing' ? (
                      <ins key={j} className="missing">
                        ^{t.t}{' '}
                      </ins>
                    ) : (
                      <span key={j} className="extra">
                        {t.t}{' '}
                      </span>
                    ),
                  )}
                </p>
              </div>
            </li>
          ))}
        </ol>
        <p className="legend">
          <del>riscado</del> = escrito errado · <ins>verde</ins> = certo · <ins className="missing">^</ins> = faltou ·{' '}
          <span className="extra">ondulado</span> = sobrou
        </p>
      </section>

      {c.mistakes.length > 0 && (
        <section className="card">
          <h2>Erros</h2>
          <p className="muted">Se o app leu sua letra errado, marque como certo.</p>
          <ul className="mistakes">
            {c.mistakes.map((m, i) => (
              <li key={`${m.segment}-${m.written}-${m.correct}-${i}`}>
                <div className="m-words">
                  {m.written ? <del>{m.written}</del> : <span className="muted">(faltou)</span>}
                  <span className="arrow">→</span>
                  {m.correct ? <ins>{m.correct}</ins> : <span className="muted">(sobrou)</span>}
                  <span className="chip">{m.type}</span>
                </div>
                <p>{m.why}</p>
                <div className="row">
                  {m.correct && (
                    <button className="btn text" onClick={() => say(m.correct, voice)}>
                      <Icon name="speaker" size={18} /> Ouvir
                    </button>
                  )}
                  <button className="btn text" onClick={() => accept(m)}>
                    <Icon name="check" size={18} /> Marcar como certo
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {playing !== -2 && (
        <button className="fab" onClick={stop}>
          <Icon name="stop" /> Parar
        </button>
      )}
    </div>
  )
}
