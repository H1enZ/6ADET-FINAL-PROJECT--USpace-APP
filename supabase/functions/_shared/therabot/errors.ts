// Errors Therabot returns to the app. Messages are written for people and
// never include SQL, stack traces, keys or anyone's private text.

export type TherabotErrorCode =
  | 'bad_input'
  | 'not_signed_in'
  | 'not_allowed'
  | 'invalid_state'
  | 'expired'
  | 'rate_limited'
  | 'ai_unavailable'
  | 'bad_output'
  | 'internal';

const STATUS: Record<TherabotErrorCode, number> = {
  bad_input: 400,
  not_signed_in: 401,
  not_allowed: 403,
  invalid_state: 409,
  expired: 410,
  rate_limited: 429,
  ai_unavailable: 503,
  bad_output: 502,
  internal: 500,
};

export class TherabotError extends Error {
  readonly code: TherabotErrorCode;
  private readonly statusOverride?: number;

  constructor(code: TherabotErrorCode, message: string, status?: number) {
    super(message);
    this.name = 'TherabotError';
    this.code = code;
    this.statusOverride = status;
  }

  get status(): number {
    return this.statusOverride ?? STATUS[this.code];
  }
}

export const MESSAGES = {
  signIn: 'Sign in to use Therabot.',
  notFound: "This Therabot session isn't available. It may have ended.",
  expired: 'This Therabot session has ended after 24 hours.',
  aiUnavailable: 'Therabot is unavailable right now. Please try again in a moment.',
  badOutput: "Therabot couldn't write this reflection properly. Please try again.",
  internal: 'Something went wrong. Please try again.',
} as const;
