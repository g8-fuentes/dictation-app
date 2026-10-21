import { useCallback, useEffect, useState } from 'react'
import type { DictationRecord } from './models'

// Everything is saved in this browser only (localStorage).

function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function save(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    /* storage full or blocked: keep working in memory */
  }
}

export function useStored<T>(key: string, fallback: T): [T, (v: T | ((old: T) => T)) => void] {
  const [value, setValue] = useState<T>(() => load(key, fallback))
  const set = useCallback(
    (v: T | ((old: T) => T)) =>
      setValue((old) => {
        const next = typeof v === 'function' ? (v as (o: T) => T)(old) : v
        save(key, next)
        return next
      }),
    [key],
  )
  return [value, set]
}

export interface Settings {
  theme: 'light' | 'dark' | null
  british: boolean
  rate: number
  /** The student's own Gemini key; kept only in this browser. */
  geminiKey: string
}

export const defaultSettings: Settings = { theme: null, british: true, rate: 0.95, geminiKey: '' }

export function useSettings() {
  const [s, set] = useStored<Settings>('settings', defaultSettings)
  const settings = { ...defaultSettings, ...s }
  useEffect(() => {
    if (settings.theme) document.documentElement.dataset.theme = settings.theme
    else delete document.documentElement.dataset.theme
  }, [settings.theme])
  return [settings, (patch: Partial<Settings>) => set((old) => ({ ...defaultSettings, ...old, ...patch }))] as const
}

/** Every corrected dictation, newest first. */
export function useHistory() {
  return useStored<DictationRecord[]>('history', [])
}

export const formatDate = (iso: string) => {
  const d = new Date(iso)
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
}
