// Therabot's structured outputs, and strict validators for them.
//
// Every model answer is parsed here before it is stored or returned. Unknown
// fields are rejected, so a model can never add a verdict, a diagnosis, a
// ranking or a "recommended option": those fields simply do not exist.

export const SAFETY_CATEGORIES = [
  'violence',
  'threats',
  'coercion',
  'stalking',
  'sexual_violence',
  'self_harm',
  'suicide',
  'immediate_danger',
] as const;

export type SafetyCategory = typeof SAFETY_CATEGORIES[number];

export interface SafetyCheck {
  flagged: boolean;
  categories: SafetyCategory[];
  message: string;
}

/** One partner's private reflection. Stored owner-only. */
export interface PrivateReflection {
  safety: SafetyCheck;
  summary: string;
  needs: string[];
  uncertain_points: string[];
  suggested_insights: string[];
}

export interface Perspective {
  partner: '1' | '2';
  summary: string;
  needs: string[];
}

/** The couple-visible reflection, built only from approved summaries. */
export interface SharedReflection {
  safety: SafetyCheck;
  perspectives: [Perspective, Perspective];
  differences: string[];
  possible_misunderstandings: string[];
  common_ground: string[];
  discussion_questions: string[];
}

export type Validation<T> = { ok: true; value: T } | { ok: false; error: string };

// Limits. Approved summaries are at most 1500 characters in the database.
export const LIMITS = {
  summary: 1200,
  item: 300,
  safetyMessage: 500,
  needs: 5,
  uncertainPoints: 3,
  suggestedInsights: 3,
  insight: 300,
  differences: 4,
  misunderstandings: 3,
  commonGround: 3,
  questionsMin: 2,
  questionsMax: 4,
} as const;

// Words that mark a statement as a possibility rather than a fact. A bare
// "may" is not enough: in Filipino "may" means "there is".
const HEDGE =
  /\b(might|could|possibly|perhaps|maybe|seem|seems|seemed|one possibility|it'?s possible|it is possible|(it|you|they|each of you|both of you|partner [12]) may|may (be|have|not|feel|mean|need|want|see))\b/i;

// ---------------------------------------------------------------- helpers

function isObject(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function onlyKeys(o: Record<string, unknown>, allowed: readonly string[]): string | null {
  for (const k of Object.keys(o)) {
    if (!allowed.includes(k)) return `unexpected field "${k}"`;
  }
  return null;
}

function text(x: unknown, max: number, field: string, allowEmpty = false): string {
  if (typeof x !== 'string') throw new Error(`${field} must be text`);
  const t = x.trim();
  if (!allowEmpty && t.length === 0) throw new Error(`${field} is empty`);
  if (t.length > max) throw new Error(`${field} is too long`);
  return t;
}

function list(x: unknown, min: number, max: number, itemMax: number, field: string): string[] {
  if (!Array.isArray(x)) throw new Error(`${field} must be a list`);
  if (x.length < min || x.length > max) throw new Error(`${field} must have ${min}-${max} items`);
  return x.map((item, i) => text(item, itemMax, `${field}[${i}]`));
}

export function validateSafety(x: unknown): SafetyCheck {
  if (!isObject(x)) throw new Error('safety is missing');
  const extra = onlyKeys(x, ['flagged', 'categories', 'message']);
  if (extra) throw new Error(`safety: ${extra}`);
  if (typeof x.flagged !== 'boolean') throw new Error('safety.flagged must be true or false');
  if (!Array.isArray(x.categories)) throw new Error('safety.categories must be a list');
  const categories: SafetyCategory[] = [];
  for (const c of x.categories) {
    if (!(SAFETY_CATEGORIES as readonly unknown[]).includes(c)) {
      throw new Error('safety.categories has an unknown category');
    }
    if (!categories.includes(c as SafetyCategory)) categories.push(c as SafetyCategory);
  }
  const message = text(x.message ?? '', LIMITS.safetyMessage, 'safety.message', true);
  if (x.flagged && categories.length === 0) throw new Error('flagged safety needs a category');
  if (!x.flagged && categories.length > 0) throw new Error('unflagged safety has categories');
  return { flagged: x.flagged, categories, message };
}

/**
 * Reads a model's safety signal leniently, BEFORE strict validation, so a
 * flag is never lost to a formatting mistake: flagged:true, or any category
 * at all (even an unknown one), counts as flagged. Only known categories
 * are kept.
 */
export function modelSafetySignal(json: unknown): { flagged: boolean; categories: SafetyCategory[] } {
  if (!isObject(json) || !isObject(json.safety)) return { flagged: false, categories: [] };
  const raw = Array.isArray(json.safety.categories) ? json.safety.categories : [];
  const categories = raw.filter((c): c is SafetyCategory =>
    (SAFETY_CATEGORIES as readonly unknown[]).includes(c)
  );
  return {
    flagged: json.safety.flagged === true || raw.length > 0,
    categories: [...new Set(categories)],
  };
}

function attempt<T>(fn: () => T): Validation<T> {
  try {
    return { ok: true, value: fn() };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'invalid output' };
  }
}

// --------------------------------------------------------------- validators

/**
 * A flagged answer only needs a valid safety block; the rest is discarded,
 * because normal reflection stops in safety mode.
 */
export function validatePrivateReflection(x: unknown): Validation<PrivateReflection> {
  return attempt(() => {
    if (!isObject(x)) throw new Error('answer must be an object');
    const safety = validateSafety(x.safety);
    if (safety.flagged) {
      return { safety, summary: '', needs: [], uncertain_points: [], suggested_insights: [] };
    }
    const extra = onlyKeys(x, ['safety', 'summary', 'needs', 'uncertain_points', 'suggested_insights']);
    if (extra) throw new Error(extra);
    return {
      safety,
      summary: text(x.summary, LIMITS.summary, 'summary'),
      needs: list(x.needs, 0, LIMITS.needs, LIMITS.item, 'needs'),
      uncertain_points: list(x.uncertain_points, 0, LIMITS.uncertainPoints, LIMITS.item, 'uncertain_points'),
      suggested_insights: list(x.suggested_insights, 0, LIMITS.suggestedInsights, LIMITS.insight, 'suggested_insights'),
    };
  });
}

export function validateSharedReflection(x: unknown): Validation<SharedReflection> {
  return attempt(() => {
    if (!isObject(x)) throw new Error('answer must be an object');
    const safety = validateSafety(x.safety);
    if (safety.flagged) {
      return {
        safety,
        perspectives: [
          { partner: '1', summary: '', needs: [] },
          { partner: '2', summary: '', needs: [] },
        ],
        differences: [],
        possible_misunderstandings: [],
        common_ground: [],
        discussion_questions: [],
      };
    }
    const extra = onlyKeys(x, [
      'safety',
      'perspectives',
      'differences',
      'possible_misunderstandings',
      'common_ground',
      'discussion_questions',
    ]);
    if (extra) throw new Error(extra);

    if (!Array.isArray(x.perspectives) || x.perspectives.length !== 2) {
      throw new Error('there must be exactly two perspectives');
    }
    const perspectives = x.perspectives.map((p, i) => {
      if (!isObject(p)) throw new Error(`perspectives[${i}] must be an object`);
      const more = onlyKeys(p, ['partner', 'summary', 'needs']);
      if (more) throw new Error(`perspectives[${i}]: ${more}`);
      if (p.partner !== '1' && p.partner !== '2') throw new Error('partner must be "1" or "2"');
      return {
        partner: p.partner,
        summary: text(p.summary, LIMITS.summary, `perspectives[${i}].summary`),
        needs: list(p.needs, 0, LIMITS.needs, LIMITS.item, `perspectives[${i}].needs`),
      } as Perspective;
    });
    if (perspectives[0].partner === perspectives[1].partner) {
      throw new Error('the two perspectives must be Partner 1 and Partner 2');
    }
    perspectives.sort((a, b) => a.partner.localeCompare(b.partner));

    const misunderstandings = list(
      x.possible_misunderstandings, 0, LIMITS.misunderstandings, LIMITS.item, 'possible_misunderstandings',
    );
    for (const m of misunderstandings) {
      if (!HEDGE.test(m)) throw new Error('a possible misunderstanding is stated as a fact');
    }
    const questions = list(
      x.discussion_questions, LIMITS.questionsMin, LIMITS.questionsMax, LIMITS.item, 'discussion_questions',
    );
    for (const q of questions) {
      if (!q.endsWith('?')) throw new Error('a discussion question is not a question');
    }

    return {
      safety,
      perspectives: [perspectives[0], perspectives[1]],
      differences: list(x.differences, 0, LIMITS.differences, LIMITS.item, 'differences'),
      possible_misunderstandings: misunderstandings,
      common_ground: list(x.common_ground, 0, LIMITS.commonGround, LIMITS.item, 'common_ground'),
      discussion_questions: questions,
    };
  });
}

// ------------------------------------------------- JSON Schemas for providers

const SAFETY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['flagged', 'categories', 'message'],
  properties: {
    flagged: { type: 'boolean' },
    categories: { type: 'array', items: { type: 'string', enum: [...SAFETY_CATEGORIES] } },
    message: { type: 'string', maxLength: LIMITS.safetyMessage },
  },
};

const STRINGS = (maxItems: number, minItems = 0) => ({
  type: 'array',
  minItems,
  maxItems,
  items: { type: 'string', minLength: 1, maxLength: LIMITS.item },
});

export const PRIVATE_REFLECTION_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: ['safety', 'summary', 'needs', 'uncertain_points', 'suggested_insights'],
  properties: {
    safety: SAFETY_SCHEMA,
    summary: { type: 'string', maxLength: LIMITS.summary },
    needs: STRINGS(LIMITS.needs),
    uncertain_points: STRINGS(LIMITS.uncertainPoints),
    suggested_insights: STRINGS(LIMITS.suggestedInsights),
  },
};

export const SHARED_REFLECTION_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: [
    'safety',
    'perspectives',
    'differences',
    'possible_misunderstandings',
    'common_ground',
    'discussion_questions',
  ],
  properties: {
    safety: SAFETY_SCHEMA,
    perspectives: {
      type: 'array',
      minItems: 2,
      maxItems: 2,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['partner', 'summary', 'needs'],
        properties: {
          partner: { type: 'string', enum: ['1', '2'] },
          summary: { type: 'string', maxLength: LIMITS.summary },
          needs: STRINGS(LIMITS.needs),
        },
      },
    },
    differences: STRINGS(LIMITS.differences),
    possible_misunderstandings: STRINGS(LIMITS.misunderstandings),
    common_ground: STRINGS(LIMITS.commonGround),
    discussion_questions: STRINGS(LIMITS.questionsMax, LIMITS.questionsMin),
  },
};

/** What is stored on the couple-visible session row: no safety block. */
export function storedReflection(r: SharedReflection): Record<string, unknown> {
  return {
    perspectives: r.perspectives,
    differences: r.differences,
    possible_misunderstandings: r.possible_misunderstandings,
    common_ground: r.common_ground,
    discussion_questions: r.discussion_questions,
  };
}

/** Every string in a value, for the safety screen and the neutrality lint. */
export function allStrings(x: unknown, out: string[] = []): string[] {
  if (typeof x === 'string') out.push(x);
  else if (Array.isArray(x)) x.forEach((v) => allStrings(v, out));
  else if (isObject(x)) Object.values(x).forEach((v) => allStrings(v, out));
  return out;
}
