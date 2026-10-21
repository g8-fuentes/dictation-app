import type { Settings } from '../lib/store'
import { say } from '../lib/voice'
import { Icon } from './Icon'
import { keyLink } from './KeyCard'

export function SettingsSheet({ settings, onChange, onClose }: { settings: Settings; onChange: (p: Partial<Settings>) => void; onClose: () => void }) {
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" role="dialog" aria-label="Configurações" onClick={(e) => e.stopPropagation()}>
        <div className="section-head">
          <h2>Configurações</h2>
          <button className="icon-btn" aria-label="Fechar" onClick={onClose}>
            <Icon name="close" />
          </button>
        </div>
        <h3>Chave do Gemini</h3>
        <input
          className="text"
          type="password"
          autoComplete="off"
          placeholder="Cole a chave aqui"
          value={settings.geminiKey}
          onChange={(e) => onChange({ geminiKey: e.target.value.trim() })}
          aria-label="Chave do Gemini"
        />
        <p className="muted small">
          Gratuita no Google AI Studio:{' '}
          <a href={keyLink} target="_blank" rel="noreferrer">
            pegar minha chave
          </a>
          . Fica salva só neste aparelho e é enviada apenas ao Google.
        </p>
        <h3>Tema</h3>
        <div className="segmented">
          {([['light', 'Claro'], ['dark', 'Escuro'], [null, 'Automático']] as const).map(([v, label]) => (
            <button key={label} className={settings.theme === v ? 'on' : ''} onClick={() => onChange({ theme: v })}>
              {label}
            </button>
          ))}
        </div>
        <h3>Sotaque da voz</h3>
        <div className="segmented">
          <button className={settings.british ? 'on' : ''} onClick={() => onChange({ british: true })}>
            Britânico
          </button>
          <button className={!settings.british ? 'on' : ''} onClick={() => onChange({ british: false })}>
            Americano
          </button>
        </div>
        <h3>Velocidade: {settings.rate.toFixed(2)}×</h3>
        <input
          type="range"
          min={0.5}
          max={1.3}
          step={0.05}
          value={settings.rate}
          onChange={(e) => onChange({ rate: Number(e.target.value) })}
          aria-label="Velocidade"
        />
        <button className="btn outline" onClick={() => say('This is how the dictation will sound.', settings)}>
          <Icon name="speaker" size={20} /> Testar voz
        </button>
        <p className="muted small">Suas dictations ficam salvas só neste navegador.</p>
      </div>
    </div>
  )
}
