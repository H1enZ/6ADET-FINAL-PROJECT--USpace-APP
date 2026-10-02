// The one interface every AI provider implements. The provider is chosen on
// the server (AI_PROVIDER secret); the Flutter app never knows which one it
// is talking to, and never holds a provider key.

export type AiTask = 'private_reflection' | 'shared_reflection';

export interface AiRequest {
  task: AiTask;
  /** Fixed Therabot rules for this task (prompts.ts). */
  system: string;
  /** The task input as JSON text (prompts.ts). Never contains names or ids. */
  user: string;
  /** JSON Schema of the expected answer, for providers that support it. */
  jsonSchema: Record<string, unknown>;
  maxOutputTokens: number;
  temperature: number;
  timeoutMs: number;
  /** 1 on the first try, 2 on the single retry. */
  attempt: number;
}

export interface AiResult {
  /** Parsed JSON from the model. Always validated afterwards; never trusted. */
  json: unknown;
  provider: string;
  model: string;
  usage?: { inputTokens: number; outputTokens: number };
}

export type AiErrorKind =
  | 'timeout'
  | 'rate_limited'
  | 'blocked'
  | 'bad_output'
  | 'unavailable'
  | 'config';

export class AiError extends Error {
  readonly kind: AiErrorKind;

  constructor(kind: AiErrorKind, message: string) {
    super(message);
    this.name = 'AiError';
    this.kind = kind;
  }
}

export interface AiProvider {
  readonly name: string;
  readonly model: string;
  generateJson(request: AiRequest): Promise<AiResult>;
}
