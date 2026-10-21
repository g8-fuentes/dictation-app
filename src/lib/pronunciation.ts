import { align, bare, similarity, words } from './checker'

export interface SpokenWord {
  /** As printed in the text. */
  word: string
  status: 'ok' | 'review' | 'skipped'
  /** What the recogniser understood, for review. */
  heard?: string
}

const numbers: Record<string, string> = {
  0: 'zero', 1: 'one', 2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven',
  8: 'eight', 9: 'nine', 10: 'ten', 11: 'eleven', 12: 'twelve', 20: 'twenty', 100: 'hundred',
}

const norm = (w: string) => {
  const b = bare(w)
  return numbers[b] ?? b
}

/**
 * Compares the text with what the speech recogniser heard. A word heard as
 * something else is flagged for review: an approximation of pronunciation,
 * not a phonetic analysis.
 */
export function comparePronunciation(text: string, heard: string): SpokenWord[] {
  const orig = words(text)
  const said = words(heard)
  const o = orig.map(norm)
  const s = said.map(norm)
  const out: SpokenWord[] = []
  for (const op of align(o, s)) {
    if (op.o === null) continue // extra words the recogniser heard
    const word = orig[op.o]
    if (op.s === null) out.push({ word, status: 'skipped' })
    else if (o[op.o] === s[op.s] || similarity(o[op.o], s[op.s]) >= 0.85) out.push({ word, status: 'ok' })
    else out.push({ word, status: 'review', heard: said[op.s] })
  }
  return out
}

/** Share of words heard as written, 0–100. */
export function pronunciationScore(ws: SpokenWord[]): number {
  return ws.length ? Math.round((100 * ws.filter((w) => w.status === 'ok').length) / ws.length) : 0
}
