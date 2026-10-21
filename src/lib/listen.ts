// Hears the student reading aloud with the browser's own speech recognition
// (no key). It stops by itself after a pause, so it is restarted until the
// student taps stop, keeping what was already heard.

interface Recognition {
  lang: string
  continuous: boolean
  interimResults: boolean
  onresult: ((e: { resultIndex: number; results: ArrayLike<ArrayLike<{ transcript: string }> & { isFinal: boolean }> }) => void) | null
  onend: (() => void) | null
  onerror: ((e: { error: string }) => void) | null
  start(): void
  stop(): void
}

type RecognitionCtor = new () => Recognition

const Ctor = (): RecognitionCtor | undefined => {
  const w = window as unknown as { SpeechRecognition?: RecognitionCtor; webkitSpeechRecognition?: RecognitionCtor }
  return w.SpeechRecognition ?? w.webkitSpeechRecognition
}

export const canListen = () => !!Ctor()

export class Listener {
  private rec?: Recognition
  private wanted = false
  private done = ''
  private current = ''
  private finished?: (text: string) => void
  error = ''

  private get all() {
    return [this.done, this.current].filter(Boolean).join(' ')
  }

  start(lang: string, onText: (text: string) => void, onFatal: (error: string) => void) {
    const C = Ctor()
    if (!C) return onFatal('unsupported')
    this.done = ''
    this.current = ''
    this.wanted = true
    const rec = new C()
    rec.lang = lang
    rec.continuous = true
    rec.interimResults = true
    rec.onresult = (e) => {
      let interim = ''
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i]
        if (r.isFinal) this.done = [this.done, r[0].transcript.trim()].filter(Boolean).join(' ')
        else interim += r[0].transcript
      }
      this.current = interim.trim()
      onText(this.all)
    }
    rec.onerror = (e) => {
      if (e.error === 'not-allowed' || e.error === 'service-not-allowed' || e.error === 'audio-capture') {
        this.wanted = false
        onFatal(e.error)
      }
    }
    rec.onend = () => {
      if (this.wanted) {
        try {
          rec.start()
          return
        } catch {
          /* falls through to finishing */
        }
      }
      if (this.current) this.done = this.all
      this.current = ''
      this.finished?.(this.done)
      this.finished = undefined
    }
    this.rec = rec
    rec.start()
  }

  /** Stops and resolves with everything heard. */
  stop(): Promise<string> {
    this.wanted = false
    return new Promise((resolve) => {
      this.finished = resolve
      try {
        this.rec?.stop()
      } catch {
        resolve(this.all)
      }
      // Some browsers never fire "end" after stop.
      setTimeout(() => this.finished?.(this.all), 1500)
    })
  }
}
