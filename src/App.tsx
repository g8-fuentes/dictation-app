import { useEffect, useState } from 'react'
import { CorrectTab } from './components/CorrectTab'
import { Icon, type IconName } from './components/Icon'
import { ListenTab } from './components/ListenTab'
import { ProgressTab } from './components/ProgressTab'
import { PronunciationTab } from './components/PronunciationTab'
import { ResultView } from './components/ResultView'
import { SettingsSheet } from './components/SettingsSheet'
import type { DictationRecord } from './lib/models'
import { warmUp } from './lib/ocr'
import { useHistory, useSettings } from './lib/store'

type Tab = 'correct' | 'progress' | 'listen' | 'speak'

const tabs: [Tab, string, IconName][] = [
  ['correct', 'Corrigir', 'check'],
  ['progress', 'Progresso', 'chart'],
  ['listen', 'Ouvir', 'headphones'],
  ['speak', 'Pronúncia', 'mic'],
]

export default function App() {
  const [settings, setSettings] = useSettings()
  const [history, setHistory] = useHistory()
  const [tab, setTab] = useState<Tab>('correct')
  const [open, setOpen] = useState<string | null>(null)
  const [showSettings, setShowSettings] = useState(false)

  // Loads the reading engine in the background so the first analysis is quick.
  useEffect(() => {
    const t = setTimeout(() => warmUp(), 800)
    return () => clearTimeout(t)
  }, [])

  const record = history.find((r) => r.id === open)
  const dark = settings.theme === 'dark' || (!settings.theme && matchMedia('(prefers-color-scheme: dark)').matches)

  const save = (r: DictationRecord) => setHistory((h) => (h.some((x) => x.id === r.id) ? h.map((x) => (x.id === r.id ? r : x)) : [r, ...h]))

  return (
    <div className="app">
      <header className="top">
        <img src={`${import.meta.env.BASE_URL}icon-192.png`} alt="" width={30} height={30} />
        <h1>dictation-app</h1>
        <button className="icon-btn" aria-label={dark ? 'Tema claro' : 'Tema escuro'} onClick={() => setSettings({ theme: dark ? 'light' : 'dark' })}>
          <Icon name={dark ? 'sun' : 'moon'} />
        </button>
        <button className="icon-btn" aria-label="Configurações" onClick={() => setShowSettings(true)}>
          <Icon name="settings" />
        </button>
      </header>

      <main>
        {record ? (
          <ResultView record={record} voice={settings} onChange={save} onBack={() => setOpen(null)} />
        ) : (
          <>
            <div hidden={tab !== 'correct'}>
              <CorrectTab
                onDone={(r) => {
                  save(r)
                  setOpen(r.id)
                }}
              />
            </div>
            {tab === 'progress' && (
              <ProgressTab history={history} onOpen={(r) => setOpen(r.id)} onDelete={(r) => setHistory((h) => h.filter((x) => x.id !== r.id))} />
            )}
            {tab === 'listen' && <ListenTab voice={settings} />}
            {tab === 'speak' && <PronunciationTab history={history} voice={settings} />}
          </>
        )}
      </main>

      <nav className="tabs">
        {tabs.map(([id, label, icon]) => (
          <button
            key={id}
            className={tab === id && !record ? 'on' : ''}
            onClick={() => {
              setOpen(null)
              setTab(id)
            }}
          >
            <span className="pill-icon">
              <Icon name={icon} />
            </span>
            {label}
          </button>
        ))}
      </nav>

      {showSettings && <SettingsSheet settings={settings} onChange={setSettings} onClose={() => setShowSettings(false)} />}
    </div>
  )
}
