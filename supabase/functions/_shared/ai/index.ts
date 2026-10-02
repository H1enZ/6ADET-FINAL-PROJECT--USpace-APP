// Picks the AI provider from the AI_PROVIDER secret. Only providers listed
// here can run; anything else (including a missing value) fails safely.
// There is deliberately no fallback to another provider.
//
// Adding a provider later (e.g. Groq): write groq.ts implementing
// AiProvider, add one case below, set AI_PROVIDER. Flutter does not change.

import { AiError, type AiProvider } from './provider.ts';
import { MockProvider } from './mock.ts';

export interface ProviderOptions {
  /** Mock only: honour [mock:...] test markers (MOCK_MARKERS=1). */
  mockMarkers?: boolean;
}

export function getProvider(name: string | undefined, options: ProviderOptions = {}): AiProvider {
  switch ((name ?? '').trim().toLowerCase()) {
    case 'mock':
      return new MockProvider({ markers: options.mockMarkers === true });
    default:
      throw new AiError('config', 'Unsupported or missing AI provider.');
  }
}

export { AiError } from './provider.ts';
export type { AiProvider, AiRequest, AiResult, AiTask } from './provider.ts';
