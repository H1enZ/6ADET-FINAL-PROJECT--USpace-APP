// A deterministic stand-in for a real AI provider: no network, no randomness.
// The same input always gives the same answer, so the whole Therabot flow
// can be built and checked without an API key.
//
// For manual checks, and ONLY when markers are switched on (MOCK_MARKERS=1;
// off by default so nobody can break a shared demo by typing one), a marker
// anywhere in the input picks a special answer:
//   [mock:safety]       the model flags a safety concern (threats)
//   [mock:invalid]      an answer that fails schema validation, every time
//   [mock:biased]       an answer that fails the neutrality lint, every time
//   [mock:biased-once]  fails the lint on the first try, passes on the retry
//   [mock:unavailable]  the provider is down
// Without a marker it returns a normal, neutral answer built mechanically
// from the input (see below); it is never a real reflection.

import { AiError, type AiProvider, type AiRequest, type AiResult } from './provider.ts';

const NOT_FLAGGED = { flagged: false, categories: [], message: '' };

function hasMarker(input: string, name: string): boolean {
  return input.toLowerCase().includes(`[mock:${name}]`);
}

// ------------------------------------------------- private summary (mock)
//
// The mock does NOT understand anything. It echoes the person's own words
// into the sections with a mechanical first-to-second-person swap ("I have
// exams" -> "You have exams"), so the UI can be tested with the details the
// tester actually typed. Sentences that mention a priority or value go to
// "what matters to you". Same input, same output, always.

const SECTION_MAX = 200; // LIMITS.section

const SWAPS: Array<[RegExp, string]> = [
  [/\bI'm\b/g, "you're"],
  [/\bI am\b/g, 'you are'],
  [/\bI was\b/g, 'you were'],
  [/\bI've\b/g, "you've"],
  [/\bI'll\b/g, "you'll"],
  [/\bI'd\b/g, "you'd"],
  [/\bI\b/g, 'you'],
  [/\bmyself\b/gi, 'yourself'],
  [/\bmine\b/gi, 'yours'],
  [/\bmy\b/gi, 'your'],
  [/\bme\b/gi, 'you'],
];

function toSecondPerson(s: string): string {
  let out = s;
  for (const [pattern, replacement] of SWAPS) out = out.replace(pattern, replacement);
  return out.charAt(0).toUpperCase() + out.slice(1);
}

function sentences(s: unknown): string[] {
  if (typeof s !== 'string') return [];
  return s
    .split(/(?<=[.!?])\s+|\n+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

/** Cuts at a word boundary so it fits a section. */
function fit(s: string): string {
  if (s.length <= SECTION_MAX) return s;
  const cut = s.slice(0, SECTION_MAX - 1);
  const space = cut.lastIndexOf(' ');
  return `${(space > 0 ? cut.slice(0, space) : cut).trimEnd()}…`;
}

/** A stated priority or value: these go to "what matters to you". */
const PRIORITY =
  /\b(priorit\w*|first|focus\w*|matters?|important|values?|before (her|him|them|you|us|my partner|the relationship))\b/i;

const QUESTIONS: Array<[string, string]> = [
  ['what_happened_from_my_perspective', 'What happened from your perspective?'],
  ['how_i_am_feeling', 'How are you feeling?'],
  ['what_i_wish_my_partner_understood', 'What do you wish your partner understood?'],
  ['what_i_need_right_now', 'What do you need right now?'],
];

function privateAnswer(raw: string): Record<string, unknown> {
  let answers: Record<string, unknown> = {};
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.answers === 'object') answers = parsed.answers;
  } catch {
    // Not the expected input: every section stays empty below.
  }

  const priorities: string[] = [];
  // One answer's sentences. Stated priorities move to "what matters to
  // you", unless they are all this answer has (then they stay here).
  const section = (key: string): string => {
    const all = sentences(answers[key]);
    const rest = all.filter((t) => !PRIORITY.test(t));
    if (rest.length === 0) return fit(all.map(toSecondPerson).join(' '));
    for (const t of all) {
      if (PRIORITY.test(t) && !priorities.includes(t)) priorities.push(t);
    }
    return fit(rest.map(toSecondPerson).join(' '));
  };

  const sections = {
    what_happened: section('what_happened_from_my_perspective'),
    how_you_feel: section('how_i_am_feeling'),
    what_you_want_your_partner_to_understand: section('what_i_wish_my_partner_understood'),
    what_you_need: section('what_i_need_right_now'),
    what_matters_to_you: '',
  };
  sections.what_matters_to_you = fit(priorities.map(toSecondPerson).join(' '));

  // Only grounded questions: which of the four were left blank.
  const unanswered = QUESTIONS
    .filter(([key]) => sentences(answers[key]).length === 0)
    .slice(0, 3)
    .map(([, q]) => `You left "${q}" blank. Is there anything you want to add?`);

  return {
    safety: NOT_FLAGGED,
    sections,
    needs: [],
    uncertain_points: unanswered,
    suggested_insights: [],
  };
}

function sharedAnswer(input: Record<string, unknown>): Record<string, unknown> {
  const summaryOf = (key: string): string => {
    const p = input[key] as { approved_summary?: unknown } | undefined;
    const s = typeof p?.approved_summary === 'string' ? p.approved_summary : '';
    // Echoed as approved (headings and all), cut to fit a perspective.
    return s.length > 1100 ? `${s.slice(0, 1099)}…` : s || 'This partner shared their perspective.';
  };
  return {
    safety: NOT_FLAGGED,
    perspectives: [
      { partner: '1', summary: `Partner 1 shared: ${summaryOf('partner_1')}`, needs: [] },
      { partner: '2', summary: `Partner 2 shared: ${summaryOf('partner_2')}`, needs: [] },
    ],
    differences: ['You seem to have understood that moment differently.'],
    possible_misunderstandings: [
      'One possibility is that each of you was responding to a different part of the same moment.',
    ],
    common_ground: [],
    discussion_questions: [
      'What would help each of you feel heard right now?',
      'Does this reflection feel accurate to both of you?',
    ],
  };
}

export class MockProvider implements AiProvider {
  readonly name = 'mock';
  readonly model = 'mock-v1';
  private readonly markers: boolean;

  constructor(options: { markers?: boolean } = {}) {
    this.markers = options.markers === true;
  }

  generateJson(request: AiRequest): Promise<AiResult> {
    const raw = request.user;
    const marker = (name: string) => this.markers && hasMarker(raw, name);
    if (marker('unavailable')) {
      return Promise.reject(new AiError('unavailable', 'Mock provider is unavailable.'));
    }

    let json: unknown;
    if (marker('invalid')) {
      json = { summary: 42, verdict: 'not allowed' };
    } else if (marker('biased') || (marker('biased-once') && request.attempt === 1)) {
      json = request.task === 'private_reflection'
        ? {
          ...privateAnswer(raw),
          sections: { what_happened: 'Your partner is clearly toxic and you are right.' },
        }
        : { ...sharedAnswer(JSON.parse(raw)), differences: ['Partner 1 is wrong and should apologise.'] };
    } else if (marker('safety')) {
      json = {
        safety: {
          flagged: true,
          categories: ['threats'],
          message: 'What you shared sounds serious. Your safety matters most.',
        },
      };
    } else if (request.task === 'private_reflection') {
      json = privateAnswer(raw);
    } else {
      json = sharedAnswer(JSON.parse(raw));
    }

    return Promise.resolve({
      json,
      provider: this.name,
      model: this.model,
      usage: { inputTokens: 0, outputTokens: 0 },
    });
  }
}
