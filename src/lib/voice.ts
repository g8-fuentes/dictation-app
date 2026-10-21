// Speaks English with the phone's own (native) voices.

export interface VoiceSettings {
  british: boolean
  rate: number
}

let session = 0

function pickVoice(british: boolean): SpeechSynthesisVoice | undefined {
  const voices = speechSynthesis.getVoices()
  const norm = (v: SpeechSynthesisVoice) => v.lang.replace('_', '-').toLowerCase()
  const want = british ? 'en-gb' : 'en-us'
  const pool = voices.filter((v) => norm(v) === want)
  return (
    pool.find((v) => v.localService) ??
    pool[0] ??
    voices.find((v) => norm(v).startsWith('en'))
  )
}

// Voices load asynchronously on some browsers.
if (typeof speechSynthesis !== 'undefined') speechSynthesis.getVoices()

function utter(text: string, s: VoiceSettings, rate: number): Promise<void> {
  return new Promise((resolve) => {
    const u = new SpeechSynthesisUtterance(text)
    u.lang = s.british ? 'en-GB' : 'en-US'
    const v = pickVoice(s.british)
    if (v) u.voice = v
    u.rate = rate
    u.onend = () => resolve()
    u.onerror = () => resolve()
    speechSynthesis.speak(u)
  })
}

export const canSpeak = () => typeof speechSynthesis !== 'undefined'

/** Speaks one piece of text, interrupting anything already playing. */
export async function say(text: string, s: VoiceSettings, rate = s.rate) {
  if (!canSpeak()) return
  session++
  speechSynthesis.cancel()
  await utter(text, s, rate)
}

/**
 * Speaks the parts one after another with a pause between them, like a
 * teacher dictating. onPart gets the index being read, then -1 at the end.
 */
export async function dictate(
  parts: string[],
  s: VoiceSettings,
  { pauseMs, rate = s.rate, onPart }: { pauseMs: number; rate?: number; onPart?: (i: number) => void },
) {
  if (!canSpeak()) return
  const mine = ++session
  speechSynthesis.cancel()
  for (let i = 0; i < parts.length; i++) {
    if (mine !== session) return
    onPart?.(i)
    await utter(parts[i], s, rate)
    if (mine !== session) return
    if (i < parts.length - 1 && pauseMs) await new Promise((r) => setTimeout(r, pauseMs))
  }
  if (mine === session) onPart?.(-1)
}

/** Reads a whole text without pauses (sentence by sentence, so long texts are not cut off). */
export function readAll(text: string, s: VoiceSettings, rate = s.rate) {
  const sentences = text.match(/[^.!?]+[.!?]*["')\]]*\s*/g)?.map((x) => x.trim()).filter(Boolean) ?? [text]
  return dictate(sentences, s, { pauseMs: 0, rate })
}

export function stopSpeaking() {
  session++
  if (canSpeak()) speechSynthesis.cancel()
}
