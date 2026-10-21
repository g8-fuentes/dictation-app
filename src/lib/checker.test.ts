import { describe, expect, test } from 'vitest'
import { check, dictationNumber, trimToMatch, words } from './checker'
import { markCorrect } from './models'
import { comparePronunciation, pronunciationScore } from './pronunciation'

export const original =
  'The teacher is standing in front of the class. She is writing some words on the blackboard, and the students are copying them into their exercise books.'
export const student =
  'The teacher is standing in front the class. She is writting some word on the blackbord, and the students are coping them into there exercise books'

describe('checker', () => {
  test('finds the classic dictation mistakes', () => {
    const c = check(original, student)
    expect(c.mistakes.map((m) => `${m.type}|${m.written}|${m.correct}`)).toEqual([
      'palavra faltando||of',
      'ortografia|writting|writing',
      'gramática|word|words',
      'ortografia|blackbord,|blackboard,',
      'ortografia|coping|copying',
      'homófono|there|their',
      'pontuação|books|books.',
    ])
    expect(c.mistakes[1].why).toBe('O "t" não é dobrado: "writing".')
    expect(c.mistakes[3].why).toBe('Faltou a letra "a": "blackboard".')
    expect(c.score).toBe('7.6')
  })

  test('a perfect copy scores 10', () => {
    const c = check(original, original)
    expect(c.mistakes).toEqual([])
    expect(c.score).toBe('10.0')
  })

  test('segments are short phrases covering the text in order', () => {
    const c = check(original, student)
    expect(c.segments.length).toBeGreaterThan(2)
    for (const s of c.segments) expect(words(s.original).length).toBeLessThanOrEqual(8)
    expect(c.segments.map((s) => s.original).join(' ')).toBe(original)
    const m = c.mistakes.find((m) => m.correct === 'blackboard,')!
    expect(c.segments[m.segment].original).toContain('blackboard')
  })

  test('capitals and extra words', () => {
    const c = check('My name is Peter.', 'my name is is peter.')
    expect(c.mistakes.map((m) => m.type)).toEqual(['maiúscula', 'palavra a mais', 'maiúscula'])
  })

  test('unrelated words count as an extra word', () => {
    expect(check('I like apples', 'I like dogs apples').mistakes.map((m) => m.type)).toEqual(['palavra a mais'])
  })

  test('marking as correct fixes the copy and the score', () => {
    let c = check(original, student)
    const writting = c.mistakes.find((m) => m.written === 'writting')!
    c = markCorrect(c, writting)
    expect(c.mistakes).toHaveLength(6)
    expect(c.segments[writting.segment].tokens.map((t) => t.t)).toContain('writing')
    expect(c.score).toBe('8.0')
    const missing = c.mistakes.find((m) => m.type === 'palavra faltando')!
    c = markCorrect(c, missing)
    expect(c.segments[missing.segment].tokens.filter((t) => t.s !== 'ok')).toEqual([])
  })

  test('trims the book page and finds the dictation number', () => {
    const page = 'Lesson 12 Dictation 34 The teacher is standing in front of the class. Exercise 5 Answer the questions.'
    expect(trimToMatch(page, 'The teacher is standing in front the class.')).toBe(
      'The teacher is standing in front of the class.',
    )
    expect(dictationNumber(page)).toBe(34)
    expect(dictationNumber('DICTATION No. 7')).toBe(7)
    expect(dictationNumber('nothing')).toBeUndefined()
  })
})

describe('pronunciation', () => {
  test('flags words heard differently and words left out', () => {
    const r = comparePronunciation(
      'The teacher is writing some words on the blackboard.',
      'the teacher is riding some word on blackboard',
    )
    expect(r.map((w) => w.status)).toEqual(['ok', 'ok', 'ok', 'review', 'ok', 'review', 'ok', 'skipped', 'ok'])
    expect(r[3].heard).toBe('riding')
    expect(pronunciationScore(r)).toBe(67)
  })

  test('digits count as the number word', () => {
    expect(comparePronunciation('I have two cats.', 'I have 2 cats').every((w) => w.status === 'ok')).toBe(true)
  })
})

describe('loose punctuation', () => {
  test('is never a missing or extra word', () => {
    const c = check('He said — quietly — " Good morning. "', 'He said quietly Good morning.')
    expect(c.mistakes).toEqual([])
    const d = check('The cat sat on the mat.', 'The cat - sat on the mat . "')
    expect(d.mistakes.some((m) => m.type === 'palavra a mais' || m.type === 'palavra faltando')).toBe(false)
  })
})

describe('Callan "Correct your dictation" page', () => {
  const page = `Correct your dictation: They go to bed at eleven / and get up at seven. / During the day / we can see the sun in the sky, / whilst during the night / we can see the moon and the stars. / A millionaire / is a rich person. / I forgot my camera, / so I took the photos / on my mobile instead. / We want to go / for a long walk, / but it depends on the weather. / Not every student is quick; / some are quick / and some are slow. / When the weather is cold / and there is snow, / we cover our bodies / with a lot of clothes. / I had to meet him / at the corner of the street, / and he asked me / to bring him some cash. / The opposite of heaven / is hell. / Learning to drive / was a struggle; / I found it quite hard. / Some people / are willing to die / for what they believe. / Smoking cigarettes / causes terrible health problems. / Parents often read / bedtime stories to their children. / In some ways, / life today is harder / than it was in the past, / but in other ways / it is easier. / If somebody wants / to buy my motorbike / before I go away, / I'll sell it / for almost nothing. / Many teenagers don't like / wearing a uniform for school.`
  const copy = `They go to bed at eleven and get up at seven. During The day we can see The sun in The sky, whilst during the night we can see the moon and The stars. A millionaire is a rich person. I forgot my camera, so I took the photos on my mobile instead. We want to go for a long walk, but it depends on the weather. Not every student is quick; some are quick and some are slow. When the weather is cold and there is snow we cover our bodies with a lot of clothes. I had to meet him at the corner of the streets and he asked me to bring him some cash. The opposite of heaven is hell. Learning to drive was a struggle; I found it quite hard. Some people are willing to die for what they believe. Smoking cigarettes causes terrible health problems. Parents often read bedtime stories to their children. In some ways, life today is harder than it was in the past, but in the others ways it is easier. If somebody wants to buy motorbike before I go away, I'll sell it for almost nothing. Many teenagers don't like wearing a uniform for school.`

  test('uses the "/" marks as the parts and never as words', () => {
    const c = check(trimToMatch(page, copy), copy)
    expect(c.originalText).not.toContain('/')
    expect(c.originalText.startsWith('They go')).toBe(true)
    expect(c.segments[0].original).toBe('They go to bed at eleven')
    expect(c.segments[1].original).toBe('and get up at seven.')
    expect(c.mistakes.map((m) => [m.written, m.correct])).toEqual([
      ['snow', 'snow,'],
      ['streets', 'street,'],
      ['the', ''],
      ['others', 'other'],
      ['', 'my'],
    ])
    expect(c.score).toBe('9.8')
  })
})
