// Groq, through its OpenAI-compatible chat completions API, with strict
// JSON-schema Structured Outputs.
//
// Plain fetch, no SDK: exactly one HTTP request per call, so the only retry
// is the single one generateChecked decides on. The key comes from the
// server environment (GROQ_API_KEY) and never leaves this file: it is not
// logged, not returned and not put in any error message. Error messages are
// fixed strings and never include Groq's response body, which could echo
// what the couple wrote.
//
// Groq's strict mode guarantees the shape only. Every answer is still
// validated, safety-screened and neutrality-linted afterwards (generate.ts).

import { AiError, type AiProvider, type AiRequest, type AiResult } from './provider.ts';

const ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';

export const GROQ_DEFAULT_MODEL = 'openai/gpt-oss-120b';

// Keywords Groq's strict mode is not documented to accept. They are dropped
// from the copy sent to Groq only; our own validator still enforces every
// length and count limit on the answer.
const UNSUPPORTED_KEYWORDS = new Set(['maxLength', 'minLength', 'maxItems', 'minItems']);

/** A copy of [schema] without the keywords Groq's strict mode may reject. */
export function groqSchema(schema: unknown): unknown {
  if (Array.isArray(schema)) return schema.map(groqSchema);
  if (typeof schema !== 'object' || schema === null) return schema;
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(schema)) {
    if (UNSUPPORTED_KEYWORDS.has(key)) continue;
    // Inside "properties" the keys are field names, not keywords: keep them all.
    out[key] = key === 'properties' && typeof value === 'object' && value !== null
      ? Object.fromEntries(Object.entries(value).map(([name, s]) => [name, groqSchema(s)]))
      : groqSchema(value);
  }
  return out;
}

interface GroqResponse {
  choices?: Array<{
    finish_reason?: string;
    message?: { content?: unknown };
  }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

export class GroqProvider implements AiProvider {
  readonly name = 'groq';
  readonly model: string;
  readonly #apiKey: string;

  constructor(options: { apiKey: string; model?: string }) {
    if (!options.apiKey) throw new AiError('config', 'Groq is not configured.');
    this.#apiKey = options.apiKey;
    this.model = options.model?.trim() || GROQ_DEFAULT_MODEL;
  }

  async generateJson(request: AiRequest): Promise<AiResult> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), request.timeoutMs);

    let response: Response;
    try {
      response = await fetch(ENDPOINT, {
        method: 'POST',
        signal: controller.signal,
        // Never follow a redirect with the key and the couple's text.
        redirect: 'error',
        headers: {
          Authorization: `Bearer ${this.#apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            { role: 'system', content: request.system },
            { role: 'user', content: request.user },
          ],
          response_format: {
            type: 'json_schema',
            json_schema: { name: request.task, strict: true, schema: groqSchema(request.jsonSchema) },
          },
          temperature: request.temperature,
          max_completion_tokens: request.maxOutputTokens,
          reasoning_effort: 'low',
          include_reasoning: false,
          stream: false,
        }),
      });
    } catch (e) {
      clearTimeout(timer);
      if (controller.signal.aborted) throw new AiError('timeout', 'Groq did not answer in time.');
      throw new AiError('unavailable', `Groq could not be reached (${(e as Error)?.name ?? 'error'}).`);
    }

    let body: GroqResponse;
    try {
      if (!response.ok) {
        // Never read: it could echo the input.
        await response.body?.cancel().catch(() => {});
        throw errorFor(response.status);
      }
      body = await response.json() as GroqResponse;
    } catch (e) {
      if (e instanceof AiError) throw e;
      if (controller.signal.aborted) throw new AiError('timeout', 'Groq did not answer in time.');
      throw new AiError('bad_output', 'Groq returned an unreadable response.');
    } finally {
      clearTimeout(timer);
    }

    const choice = body.choices?.[0];
    if (choice?.finish_reason === 'length') {
      throw new AiError('bad_output', 'Groq ran out of output tokens.');
    }
    const content = choice?.message?.content;
    if (typeof content !== 'string' || content.trim().length === 0) {
      throw new AiError('bad_output', 'Groq returned no content.');
    }
    let json: unknown;
    try {
      json = JSON.parse(content);
    } catch {
      throw new AiError('bad_output', 'Groq returned content that is not JSON.');
    }

    return {
      json,
      provider: this.name,
      model: this.model,
      usage: {
        inputTokens: Number(body.usage?.prompt_tokens ?? 0),
        outputTokens: Number(body.usage?.completion_tokens ?? 0),
      },
    };
  }
}

/** Maps an HTTP status to an error kind. The message never includes the body. */
function errorFor(status: number): AiError {
  if (status === 429) return new AiError('rate_limited', 'Groq rate limit reached.');
  // With strict structured outputs Groq does not fail on the answer's shape,
  // so a 400 means the request itself was refused (for example a model that
  // doesn't take these parameters): a setup problem, never worth a paid retry.
  if (status === 400 || status === 401 || status === 403 || status === 404 || status === 422) {
    return new AiError('config', `Groq rejected the request (HTTP ${status}).`);
  }
  return new AiError('unavailable', `Groq is unavailable (HTTP ${status}).`);
}
