// Picks the AI provider from the AI_PROVIDER secret. Only providers listed
// here can run; anything else (including a missing value) fails safely.
// There is deliberately no fallback to another provider: if Groq is chosen
// but not configured, Therabot is unavailable rather than quietly mocked.
//
// Adding a provider: write a file implementing AiProvider, add one case
// below, set AI_PROVIDER. Flutter does not change.

import { AiError, type AiProvider } from './provider.ts';
import { GroqProvider } from './groq.ts';
import { MockProvider } from './mock.ts';

export interface ProviderOptions {
  /** Mock only: honour [mock:...] test markers (MOCK_MARKERS=1). */
  mockMarkers?: boolean;
  /** Groq only: the server-side GROQ_API_KEY. Never sent anywhere but Groq. */
  groqApiKey?: string;
  /** Groq only: GROQ_MODEL, or the default when empty. */
  groqModel?: string;
}

export function getProvider(name: string | undefined, options: ProviderOptions = {}): AiProvider {
  switch ((name ?? '').trim().toLowerCase()) {
    case 'mock':
      return new MockProvider({ markers: options.mockMarkers === true });
    case 'groq':
      return new GroqProvider({ apiKey: options.groqApiKey ?? '', model: options.groqModel });
    default:
      throw new AiError('config', 'Unsupported or missing AI provider.');
  }
}

export { AiError } from './provider.ts';
export type { AiProvider, AiRequest, AiResult, AiTask } from './provider.ts';
