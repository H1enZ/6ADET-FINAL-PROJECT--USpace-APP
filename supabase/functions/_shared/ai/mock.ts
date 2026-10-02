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
// Without a marker it returns a normal, neutral answer.

import { AiError, type AiProvider, type AiRequest, type AiResult } from './provider.ts';

const NOT_FLAGGED = { flagged: false, categories: [], message: '' };

function hasMarker(input: string, name: string): boolean {
  return input.toLowerCase().includes(`[mock:${name}]`);
}

function privateAnswer(): Record<string, unknown> {
  return {
    safety: NOT_FLAGGED,
    summary:
      "Based on what you've shared, a recent moment between you and your partner left you feeling hurt and unsure. " +
      'You would like your partner to understand how that moment felt from your side, and you are hoping to feel heard.',
    needs: ['To feel heard', 'Some reassurance'],
    uncertain_points: ['I was not sure whether you would rather talk tonight or after some rest. Does this reflection feel accurate?'],
    suggested_insights: [],
  };
}

function sharedAnswer(input: Record<string, unknown>): Record<string, unknown> {
  const summaryOf = (key: string): string => {
    const p = input[key] as { approved_summary?: unknown } | undefined;
    const s = typeof p?.approved_summary === 'string' ? p.approved_summary : '';
    return s.length > 600 ? s.slice(0, 600) : s || 'This partner shared their perspective.';
  };
  return {
    safety: NOT_FLAGGED,
    perspectives: [
      { partner: '1', summary: `Partner 1 shared: ${summaryOf('partner_1')}`, needs: ['To feel heard'] },
      { partner: '2', summary: `Partner 2 shared: ${summaryOf('partner_2')}`, needs: ['Some understanding'] },
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
        ? { ...privateAnswer(), summary: 'Your partner is clearly toxic and you are right.' }
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
      json = privateAnswer();
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
