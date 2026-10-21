export type TokenStatus = 'ok' | 'wrong' | 'missing' | 'extra'

/** One word of the student's copy, as compared with the original. */
export interface Token {
  t: string
  s: TokenStatus
  /** Correct form, for a wrong word. */
  c?: string
}

export interface Mistake {
  segment: number
  written: string
  correct: string
  type: string
  why: string
}

/** A short chunk of the dictation, the way the teacher reads it aloud. */
export interface Segment {
  original: string
  tokens: Token[]
}

export interface Correction {
  originalText: string
  studentText: string
  segments: Segment[]
  mistakes: Mistake[]
  score: string
}

/** One corrected dictation in the student's history. */
export interface DictationRecord {
  id: string
  date: string
  /** The number printed on the book page ("Dictation 59"), when found. */
  number?: number
  correction: Correction
}

export const recordTitle = (r: DictationRecord) => (r.number ? `Dictation ${r.number}` : 'Dictation')

/** Punctuation and capitals weigh half a word in the score. */
const weight = (m: Mistake) => (m.type === 'pontuação' || m.type === 'maiúscula' ? 0.5 : 1)

export function scoreFor(mistakes: Mistake[], words: number): string {
  if (words === 0) return ''
  const w = mistakes.reduce((sum, m) => sum + weight(m), 0)
  return Math.min(10, Math.max(0, 10 * (1 - w / words))).toFixed(1)
}

export const wordCount = (text: string) => text.trim().split(/\s+/).filter(Boolean).length

/**
 * The teacher's call that a flagged word was right after all (usually a
 * misread of the handwriting): the word turns correct and the score is
 * recalculated. Returns a new correction.
 */
export function markCorrect(c: Correction, mistake: Mistake): Correction {
  const segments = c.segments.map((s) => ({ ...s, tokens: s.tokens.map((t) => ({ ...t })) }))
  const seg = segments[mistake.segment]
  if (seg) {
    // The n-th flagged token of a segment belongs to its n-th mistake.
    const ofSeg = c.mistakes.filter((m) => m.segment === mistake.segment)
    const n = ofSeg.indexOf(mistake)
    const flagged = seg.tokens.filter((t) => t.s !== 'ok')
    const t = flagged[n]
    if (t) {
      if (t.s === 'wrong') {
        t.t = t.c ?? t.t
        delete t.c
        t.s = 'ok'
      } else if (t.s === 'missing') {
        t.s = 'ok'
      } else {
        seg.tokens.splice(seg.tokens.indexOf(t), 1)
      }
    }
  }
  const mistakes = c.mistakes.filter((m) => m !== mistake)
  return { ...c, segments, mistakes, score: scoreFor(mistakes, wordCount(c.originalText)) }
}
