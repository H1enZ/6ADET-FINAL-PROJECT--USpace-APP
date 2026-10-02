// Neutrality lint: runs on every validated model answer.
//
// Therabot assists; the couple decides. An answer is rejected (and retried
// once) if it contains an obvious verdict, a psychological label, a command
// about the relationship, a pick among the four next steps, or certainty
// about someone's motives. Reported behaviour may still be described
// ("You said your partner raised their voice").
//
// Two kinds of fields are checked differently:
//   * restating fields (a summary or one partner's perspective) may repeat a
//     phrase that person used themselves - but only THEIR OWN words: each
//     perspective is checked against its own partner's text only, so a word
//     one partner used can't be turned into a label for the other. A label
//     word ("toxic", "avoidant", ...) is only allowed in quotes, i.e. clearly
//     attributed: You described it as "toxic";
//   * Therabot's own fields (differences, misunderstandings, questions, ...)
//     are always strict.
//
// Like the safety screen this is a floor: it catches plain phrasings only.

export interface LintResult {
  ok: boolean;
  /** Which rule matched (never the matched text, so it is safe to log). */
  rule?: string;
}

/** Text that restates one person's words, and what that person wrote. */
export interface Restatement {
  texts: readonly string[];
  source: readonly string[];
}

export interface LintInput {
  restating: readonly Restatement[];
  /** Fields Therabot writes in its own voice. */
  authored: readonly string[];
}

const RULES: Array<[string, RegExp]> = [
  // Psychological labels or diagnoses applied to a person.
  ['label', /\bnarcissis(t|tic|m)\b/g],
  ['label', /\btoxic\b/g],
  ['label', /\b(is|are|was|being|an?)\s+(abusive|an abuser|manipulative|a manipulator|controlling person|selfish)\b/g],
  ['label', /\b(abuser|manipulator|gaslighter|sociopath|psychopath)\b/g],
  ['label', /\b(avoidant|codependen(t|cy)|bipolar|borderline|personality disorder|mentally ill|mental illness)\b/g],
  ['label', /\b(trauma response|attachment (disorder|style|issues?)|insecure(ly)? attached)\b/g],
  ['label', /\b(is|are|seems?)\s+(depressed|paranoid|unstable|crazy|insane|hysterical)\b/g],
  ['label', /\b(overreact(ed|ing|s)?|gaslight(s|ed|ing)?|gaslit)\b/g],

  // Verdicts: who is right, wrong, or to blame.
  ['verdict', /\b(partner [12]|you|they|he|she|your partner)\s+(is|are|was|were)\s+(right|wrong|correct|at fault|to blame|in the wrong|in the right)\b/g],
  ['verdict', /\b(it'?s|it is|it was)\s+(your|their|his|her|partner [12]'?s)\s+fault\b/g],
  ['verdict', /\b(should|must|needs? to|ought to)\s+(apologi[sz]e|say sorry)\b/g],
  ['verdict', /\bowes?\s+(you|them|him|her|partner [12])\s+an apology\b/g],
  ['verdict', /\b(more|mostly|entirely)\s+(at fault|to blame|responsible for (this|the fight|the argument))\b/g],
  ['verdict', /\bkasalanan (mo|niya|nila|ko)\b/g],
  ['verdict', /\b(ikaw|siya|sila) ang (may )?(mali|tama)\b/g],

  // Commands or decisions about the relationship.
  ['command', /\b(should|must|need to|have to|ought to)\s+(break up|separate|divorce|leave (him|her|them|your partner)|stay together|get back together|forgive)\b/g],
  ['command', /\bi think you (both )?should\b/g],
  ['command', /\bdapat (kang |siyang |kayong )?(mag-?sorry|humingi ng tawad|maghiwalay|makipaghiwalay|patawarin)\b/g],

  // Choosing one of the four human-selected next steps.
  ['option_pick', /\b(i recommend|i suggest|i'?d recommend|i'?d suggest|i would recommend|i would suggest|the best (option|choice|next step) is)\b/g],
  ['option_pick', /\b(you should|best to|try)\s+(choose|pick|go with)\b/g],
  ['option_pick', /\b(choos(e|ing)|pick(ing)?|going with)\s+(comfort|talk|take space|reconnect)\b/g],
  ['option_pick', /\b(comfort|talk|take space|reconnect)\s+(is|would be|may be|might be)\s+(the )?(best|right|better|most helpful)\b/g],

  // Unsupported certainty about motives.
  ['motive', /\b(clearly|obviously|definitely|certainly)\s+(wanted|meant|intended|tried|wants|means|intends|doesn'?t care|does not care)\b/g],
  ['motive', /\b(real|true|hidden)\s+(motive|intention|reason)\b/g],
  ['motive', /\bdid (it|this|that) (on purpose|deliberately|intentionally)\b/g],
];

function normalise(s: string): string {
  return s
    .toLowerCase()
    .replace(/[‘’ʼ]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, ' ');
}

/** Is the match at [start, end) inside a "double-quoted" phrase? */
function quoted(text: string, start: number, end: number): boolean {
  const open = text.lastIndexOf('"', start);
  if (open === -1) return false;
  const before = text.slice(0, open).split('"').length - 1; // quotes before the opening one
  if (before % 2 !== 0) return false; // that quote closes an earlier phrase
  const close = text.indexOf('"', end);
  return close !== -1;
}

/** Lints an answer. Restating fields may only repeat that person's own words. */
export function lintNeutrality(input: LintInput): LintResult {
  const authored = normalise(input.authored.join('\n'));
  const restating = input.restating.map((r) => ({
    texts: r.texts.map(normalise),
    source: normalise(r.source.join('\n')),
  }));

  for (const [rule, pattern] of RULES) {
    pattern.lastIndex = 0;
    if (pattern.test(authored)) return { ok: false, rule };

    for (const group of restating) {
      for (const text of group.texts) {
        pattern.lastIndex = 0;
        for (const match of text.matchAll(pattern)) {
          const start = match.index ?? 0;
          const end = start + match[0].length;
          const ownWords = group.source.includes(match[0]);
          const attributed = rule !== 'label' || quoted(text, start, end);
          if (!ownWords || !attributed) return { ok: false, rule };
        }
      }
    }
  }
  return { ok: true };
}
