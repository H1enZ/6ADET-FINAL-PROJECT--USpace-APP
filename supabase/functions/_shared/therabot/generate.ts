// Asks the provider for an answer, then: honours any safety signal first,
// validates the shape, screens the model's own words, and lints for
// neutrality. One retry at most (never after a timeout, which may already
// have been paid for); if the second answer is still unusable Therabot
// fails safely and stores nothing.

import { AiError, type AiProvider, type AiRequest } from '../ai/index.ts';
import { TherabotError, MESSAGES } from './errors.ts';
import { type LintInput, lintNeutrality } from './lint.ts';
import { prescreen, safetyMessage } from './safety.ts';
import { allStrings, modelSafetySignal, type SafetyCheck, type Validation } from './schemas.ts';

export interface Generated<T> {
  /** The validated answer; null when the result is a safety stop. */
  value: T | null;
  /** Final safety result (the model's signal merged with the floor). */
  safety: SafetyCheck;
  attempts: number;
  provider: string;
  model: string;
  usage?: { inputTokens: number; outputTokens: number };
  /** Rule names that caused a retry (safe to log: no text). */
  rejected: string[];
}

function stopped<T>(
  categories: SafetyCheck['categories'],
  attempts: number,
  provider: AiProvider,
  model: string,
  rejected: string[],
): Generated<T> {
  return {
    value: null,
    safety: { flagged: true, categories, message: safetyMessage(categories) },
    attempts,
    provider: provider.name,
    model,
    rejected,
  };
}

/**
 * Why the first answer was rejected, for the single retry. Built only from
 * rule names (never from user text or the rejected answer).
 */
function retryNote(reason: string | undefined): string {
  const why = reason === 'schema'
    ? 'it broke a limit: a section or list item was too long, a list had too many items, or a field was missing'
    : reason === 'provider_bad_output'
    ? 'it was cut off or was not valid JSON; keep it shorter'
    : reason === 'lint:label'
    ? 'it used a label word for a person; only repeat such a word in quotes, as theirs'
    : reason === 'lint:verdict'
    ? 'it said or implied who is right, wrong or to blame; describe without judging, quoting their own words'
    : reason === 'lint:command'
    ? 'it told them what to do about the relationship'
    : reason === 'lint:option_pick'
    ? 'it chose or recommended a next step; never pick one'
    : reason === 'lint:motive'
    ? "it stated someone's motives as fact"
    : 'it did not follow the rules';
  return `\n\nYour previous answer was rejected because ${why}. Write a new answer that fixes only that.`;
}

export async function generateChecked<T>(
  provider: AiProvider,
  base: Omit<AiRequest, 'attempt'>,
  validate: (json: unknown) => Validation<T>,
  /** Which fields restate whose words, and which are Therabot's own. */
  lintFields: (value: T) => LintInput,
): Promise<Generated<T>> {
  const rejected: string[] = [];
  // Summed over both attempts, so a retry's cost is visible too.
  const total = { inputTokens: 0, outputTokens: 0 };

  for (let attempt = 1; attempt <= 2; attempt++) {
    let json: unknown;
    let model = provider.model;
    try {
      const system = attempt > 1 ? base.system + retryNote(rejected.at(-1)) : base.system;
      const result = await provider.generateJson({ ...base, system, attempt });
      json = result.json;
      model = result.model;
      total.inputTokens += result.usage?.inputTokens ?? 0;
      total.outputTokens += result.usage?.outputTokens ?? 0;
    } catch (e) {
      if (e instanceof AiError) {
        if (e.kind === 'rate_limited') {
          throw new TherabotError('rate_limited', 'Therabot is busy. Please try again in a minute.');
        }
        if (e.kind === 'blocked') {
          // The provider refused the content itself: a safety stop, without
          // guessing which category it was.
          return stopped([], attempt, provider, model, [...rejected, 'provider_blocked']);
        }
        if (e.kind === 'bad_output' && attempt === 1) {
          rejected.push('provider_bad_output');
          continue;
        }
      }
      // timeouts, outages, config problems: no retry
      throw new TherabotError('ai_unavailable', MESSAGES.aiUnavailable);
    }

    // 1. Any safety signal from the model wins, even if the rest is malformed.
    const signal = modelSafetySignal(json);
    if (signal.flagged) return stopped(signal.categories, attempt, provider, model, rejected);

    // 2. Strict shape.
    const checked = validate(json);
    if (!checked.ok) {
      rejected.push('schema');
      continue;
    }

    // 3. The safety floor also runs over the model's own words.
    const floor = prescreen(allStrings(checked.value));
    if (floor.flagged) return stopped(floor.categories, attempt, provider, model, rejected);

    // 4. Neutrality.
    const lint = lintNeutrality(lintFields(checked.value));
    if (!lint.ok) {
      rejected.push(`lint:${lint.rule}`);
      continue;
    }

    return {
      value: checked.value,
      safety: floor,
      attempts: attempt,
      provider: provider.name,
      model,
      usage: total,
      rejected,
    };
  }

  throw new TherabotError('bad_output', MESSAGES.badOutput);
}
