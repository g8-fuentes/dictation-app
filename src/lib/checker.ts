import { scoreFor, type Correction, type Mistake, type Token } from './models'

// Compares the student's copy with the original entirely on the device:
// aligns the words, labels each mistake and explains it in Portuguese.

const edgePunct = /^[^\p{L}\p{N}']+|[^\p{L}\p{N}']+$/gu

export const words = (text: string) => text.trim().split(/\s+/).filter(Boolean)

/** The bare word: no punctuation around it, lower case. */
export const bare = (w: string) => w.replace(edgePunct, '').toLowerCase()

const noPunct = (w: string) => w.replace(edgePunct, '')

export function check(original: string, student: string): Correction {
  const orig = words(original)
  const stud = words(student)
  const ops = align(orig, stud)
  const segOf = segmentIndex(orig)
  const segCount = orig.length ? segOf[segOf.length - 1] + 1 : 0
  const segTokens: Token[][] = Array.from({ length: segCount }, () => [])
  const mistakes: Mistake[] = []
  let lastSeg = 0
  for (const op of ops) {
    if (!segCount) break
    const seg = op.o !== null ? segOf[op.o] : lastSeg
    lastSeg = seg
    if (op.o !== null && op.s !== null) {
      const o = orig[op.o], s = stud[op.s]
      if (o === s) {
        segTokens[seg].push({ t: s, s: 'ok' })
      } else {
        segTokens[seg].push({ t: s, s: 'wrong', c: o })
        const [type, why] = explain(s, o)
        mistakes.push({ segment: seg, written: s, correct: o, type, why })
      }
    } else if (op.o !== null) {
      const o = orig[op.o]
      segTokens[seg].push({ t: o, s: 'missing' })
      mistakes.push({ segment: seg, written: '', correct: o, type: 'palavra faltando', why: `Faltou escrever "${bare(o)}".` })
    } else if (op.s !== null) {
      const s = stud[op.s]
      segTokens[seg].push({ t: s, s: 'extra' })
      mistakes.push({ segment: seg, written: s, correct: '', type: 'palavra a mais', why: `"${bare(s)}" não está no texto original.` })
    }
  }
  const segments = segTokens.map((tokens, i) => ({
    original: orig.filter((_, j) => segOf[j] === i).join(' '),
    tokens,
  }))
  return {
    originalText: orig.join(' '),
    studentText: stud.join(' '),
    segments,
    mistakes,
    score: scoreFor(mistakes, orig.length),
  }
}

/** Splits the original into short phrases, the way a teacher dictates: at punctuation, never more than 8 words. */
function segmentIndex(orig: string[]): number[] {
  const seg: number[] = []
  let current = 0, len = 0
  orig.forEach((w, i) => {
    seg.push(current)
    len++
    const endsPhrase = /[.,;:!?)"]$/.test(w)
    const remaining = orig.length - i - 1
    if (remaining > 0 && ((endsPhrase && len >= 2 && remaining >= 2) || len >= 8)) {
      current++
      len = 0
    }
  })
  return seg
}

/** Picks the stretch of the book page that best matches the student's copy, leaving out headings and other exercises. */
export function trimToMatch(original: string, student: string): string {
  const orig = words(original)
  const stud = words(student)
  if (!orig.length || !stud.length) return original.trim()
  const ops = align(orig, stud, true)
  const matched = ops
    .filter((op) => op.o !== null && op.s !== null && subCost(orig[op.o], stud[op.s]) < 1)
    .map((op) => op.o as number)
  if (!matched.length) return orig.join(' ')
  return orig.slice(matched[0], matched[matched.length - 1] + 1).join(' ')
}

function subCost(o: string, s: string): number {
  if (o === s) return 0
  const bo = bare(o), bs = bare(s)
  if (bo === bs) return 0.3 // only capitals or punctuation differ
  const sim = similarity(bo, bs)
  if (sim >= 0.5 || homophone(bo, bs)) return 1 - sim * 0.4
  return 2.5 // unrelated words: better to call it missing + extra
}

export interface AlignOp {
  /** Index in the original, null for an extra word. */
  o: number | null
  /** Index in the copy, null for a missing word. */
  s: number | null
}

/**
 * Word-level alignment with costs: equal 0, small differences < 1,
 * missing/extra 1. With freeEnds, skipping the start or end of the
 * original costs nothing.
 */
export function align(orig: string[], stud: string[], freeEnds = false): AlignOp[] {
  const n = orig.length, m = stud.length
  const d = Array.from({ length: n + 1 }, () => new Float64Array(m + 1))
  for (let i = 1; i <= n; i++) d[i][0] = freeEnds ? 0 : i
  for (let j = 1; j <= m; j++) d[0][j] = j
  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      d[i][j] = Math.min(d[i - 1][j - 1] + subCost(orig[i - 1], stud[j - 1]), d[i - 1][j] + 1, d[i][j - 1] + 1)
    }
  }
  let i = n, j = m
  const ops: AlignOp[] = []
  if (freeEnds) {
    let best = n
    for (let k = 0; k <= n; k++) if (d[k][m] < d[best][m]) best = k
    for (let k = n; k > best; k--) ops.push({ o: k - 1, s: null })
    i = best
  }
  const eq = (a: number, b: number) => Math.abs(a - b) < 1e-9
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && eq(d[i][j], d[i - 1][j - 1] + subCost(orig[i - 1], stud[j - 1]))) {
      ops.push({ o: i - 1, s: j - 1 })
      i--
      j--
    } else if (i > 0 && eq(d[i][j], d[i - 1][j] + (freeEnds && j === 0 ? 0 : 1))) {
      ops.push({ o: i - 1, s: null })
      i--
    } else {
      ops.push({ o: null, s: j - 1 })
      j--
    }
  }
  return ops.reverse()
}

function lev(a: string, b: string): number {
  const prev = Array.from({ length: b.length + 1 }, (_, i) => i)
  for (let i = 1; i <= a.length; i++) {
    let diag = prev[0]
    prev[0] = i
    for (let j = 1; j <= b.length; j++) {
      const tmp = prev[j]
      prev[j] = Math.min(prev[j] + 1, prev[j - 1] + 1, diag + (a[i - 1] === b[j - 1] ? 0 : 1))
      diag = tmp
    }
  }
  return prev[b.length]
}

export function similarity(a: string, b: string): number {
  if (!a && !b) return 1
  return 1 - lev(a, b) / Math.max(a.length, b.length)
}

const homophoneGroups = [
  ['there', 'their', "they're"], ['your', "you're"], ['its', "it's"],
  ['to', 'too', 'two'], ['where', 'wear', 'were'], ['here', 'hear'],
  ['know', 'no'], ['knew', 'new'], ['write', 'right'], ['whose', "who's"],
  ['then', 'than'], ['buy', 'by', 'bye'], ['see', 'sea'], ['for', 'four'],
  ['which', 'witch'], ['weather', 'whether'], ['piece', 'peace'],
  ['hole', 'whole'], ['our', 'hour'], ['son', 'sun'], ['one', 'won'],
  ['eight', 'ate'], ['meet', 'meat'], ['week', 'weak'], ['road', 'rode'],
  ['made', 'maid'], ['wait', 'weight'], ['would', 'wood'], ['flower', 'flour'],
  ['allowed', 'aloud'], ['brake', 'break'], ['mail', 'male'], ['pair', 'pear'],
  ['sale', 'sail'], ['tail', 'tale'], ['through', 'threw'], ['an', 'and'],
  ['of', 'off'],
]

const homophone = (a: string, b: string) => homophoneGroups.some((g) => g.includes(a) && g.includes(b))

/** Names the kind of mistake and explains it in a short sentence. */
export function explain(written: string, correct: string): [string, string] {
  const w = noPunct(written), c = noPunct(correct)
  if (w === c) return ['pontuação', `A pontuação certa é "${correct}".`]
  if (w.toLowerCase() === c.toLowerCase()) {
    const upper = c[0] === c[0]?.toUpperCase()
    return ['maiúscula', upper ? `"${c}" começa com letra maiúscula.` : `"${c}" se escreve com letra minúscula.`]
  }
  const bw = w.toLowerCase(), bc = c.toLowerCase()
  if (homophone(bw, bc)) return ['homófono', `"${bc}" e "${bw}" soam parecido, mas aqui o certo é "${bc}".`]
  if (`${bw}s` === bc || `${bw}es` === bc) return ['gramática', `É plural: "${bc}".`]
  if (`${bc}s` === bw || `${bc}es` === bw) return ['gramática', `É singular: "${bc}", sem o "s".`]
  return ['ortografia', spellingHint(bw, bc)]
}

function spellingHint(w: string, c: string): string {
  if (w.length === c.length) {
    const diffs = [...c].map((_, i) => i).filter((i) => w[i] !== c[i])
    if (diffs.length === 2 && diffs[1] === diffs[0] + 1 && w[diffs[0]] === c[diffs[1]] && w[diffs[1]] === c[diffs[0]]) {
      return `Letras trocadas de lugar: o certo é "${c}".`
    }
    if (diffs.length === 1) return `Trocou "${w[diffs[0]]}" por "${c[diffs[0]]}": o certo é "${c}".`
  }
  if (w.length + 1 === c.length) {
    for (let i = 0; i < c.length; i++) {
      if (c.slice(0, i) + c.slice(i + 1) === w) {
        const l = c[i]
        const doubled = c[i - 1] === l || c[i + 1] === l
        return doubled ? `O "${l}" é dobrado: "${c}".` : `Faltou a letra "${l}": "${c}".`
      }
    }
  }
  if (w.length === c.length + 1) {
    for (let i = 0; i < w.length; i++) {
      if (w.slice(0, i) + w.slice(i + 1) === c) {
        const l = w[i]
        const doubled = w[i - 1] === l || w[i + 1] === l
        return doubled ? `O "${l}" não é dobrado: "${c}".` : `Sobrou a letra "${l}": "${c}".`
      }
    }
  }
  return `A grafia certa é "${c}".`
}

/** "Dictation 59" (or "Dictation No. 59") printed on the book page. */
export function dictationNumber(pageText: string): number | undefined {
  const m = /dictation\s*(?:n[oº°]\.?\s*)?(\d{1,3})/i.exec(pageText)
  return m ? Number(m[1]) : undefined
}
