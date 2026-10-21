import type { DictationRecord } from '../lib/models'
import { recordTitle } from '../lib/models'
import { formatDate } from '../lib/store'
import { Icon } from './Icon'

function Chart({ items }: { items: DictationRecord[] }) {
  const pts = [...items].reverse().slice(-20)
  if (pts.length < 2) return null
  const W = 320
  const H = 140
  const pad = 22
  const x = (i: number) => pad + (i * (W - pad * 2)) / (pts.length - 1)
  const y = (v: number) => H - pad - (v / 10) * (H - pad * 2)
  const line = pts.map((r, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(Number(r.correction.score)).toFixed(1)}`).join(' ')
  return (
    <svg className="chart" viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Notas ao longo do tempo">
      {[0, 5, 10].map((v) => (
        <g key={v}>
          <line x1={pad} x2={W - pad} y1={y(v)} y2={y(v)} className="grid" />
          <text x={4} y={y(v) + 4} className="axis">
            {v}
          </text>
        </g>
      ))}
      <path d={line} className="line" />
      {pts.map((r, i) => (
        <circle key={r.id} cx={x(i)} cy={y(Number(r.correction.score))} r={4} className="dot" />
      ))}
    </svg>
  )
}

export function ProgressTab({
  history,
  onOpen,
  onDelete,
}: {
  history: DictationRecord[]
  onOpen: (r: DictationRecord) => void
  onDelete: (r: DictationRecord) => void
}) {
  if (!history.length)
    return (
      <div className="tab empty">
        <Icon name="chart" size={48} />
        <h2>Seu progresso aparece aqui</h2>
        <p className="muted">Cada dictation corrigida fica salva neste aparelho, com a nota e os erros.</p>
      </div>
    )
  const scores = history.map((r) => Number(r.correction.score))
  const avg = (xs: number[]) => (xs.reduce((a, b) => a + b, 0) / xs.length).toFixed(1)
  const recent = scores.slice(0, 5)
  const before = scores.slice(5, 10)
  const trend = before.length ? Number(avg(recent)) - Number(avg(before)) : 0
  return (
    <div className="tab">
      <div className="stats">
        <div className="card stat">
          <strong>{history.length}</strong>
          <span>dictations</span>
        </div>
        <div className="card stat">
          <strong>{avg(scores)}</strong>
          <span>média</span>
        </div>
        <div className="card stat">
          <strong>{Math.max(...scores).toFixed(1)}</strong>
          <span>melhor</span>
        </div>
      </div>
      {history.length >= 2 && (
        <section className="card">
          <h2>Evolução</h2>
          <Chart items={history} />
          {before.length > 0 && (
            <p className="muted">
              {trend > 0.05 ? `Subiu ${trend.toFixed(1)} nas últimas 5.` : trend < -0.05 ? `Caiu ${(-trend).toFixed(1)} nas últimas 5.` : 'Estável nas últimas 5.'}
            </p>
          )}
        </section>
      )}
      <section className="card">
        <h2>Histórico</h2>
        <ul className="history">
          {history.map((r) => (
            <li key={r.id}>
              <button className="history-item" onClick={() => onOpen(r)}>
                <span className="h-score">{r.correction.score}</span>
                <span>
                  <strong>{recordTitle(r)}</strong>
                  <small>
                    {formatDate(r.date)} · {r.correction.mistakes.length} {r.correction.mistakes.length === 1 ? 'erro' : 'erros'}
                  </small>
                </span>
              </button>
              <button
                className="icon-btn"
                aria-label="Apagar"
                onClick={() => confirm(`Apagar ${recordTitle(r)} de ${formatDate(r.date)}?`) && onDelete(r)}
              >
                <Icon name="trash" />
              </button>
            </li>
          ))}
        </ul>
      </section>
    </div>
  )
}
