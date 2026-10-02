// Validates the request body. Identity never comes from here: any user_id,
// couple_id or partner_id (or any other unknown field) is rejected, and the
// caller is always the verified JWT owner.

import { TherabotError } from './errors.ts';

export const MAX_BODY_BYTES = 8 * 1024;
export const MAX_MEMORY_IDS = 3;
export const MAX_MESSAGE_IDS = 10;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type TherabotRequest =
  | {
      action: 'summarize';
      sessionId: string;
      memoryIds: string[];
      messageIds: string[];
    }
  | { action: 'reflect'; sessionId: string };

function bad(message: string): never {
  throw new TherabotError('bad_input', message);
}

function uuid(x: unknown, field: string): string {
  if (typeof x !== 'string' || !UUID.test(x)) bad(`${field} must be a valid id.`);
  return (x as string).toLowerCase();
}

function ids(x: unknown, field: string, max: number): string[] {
  if (x === undefined || x === null) return [];
  if (!Array.isArray(x)) bad(`${field} must be a list of ids.`);
  const list = x as unknown[];
  if (list.length > max) bad(`You can share up to ${max} items.`);
  const out = list.map((v, i) => uuid(v, `${field}[${i}]`));
  if (new Set(out).size !== out.length) bad(`${field} has the same item twice.`);
  return out;
}

function onlyKeys(body: Record<string, unknown>, allowed: string[]): void {
  for (const key of Object.keys(body)) {
    if (!allowed.includes(key)) bad(`Unexpected field "${key}".`);
  }
}

export function parseRequest(body: unknown): TherabotRequest {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) bad('The request must be a JSON object.');
  const b = body as Record<string, unknown>;

  switch (b.action) {
    case 'summarize': {
      onlyKeys(b, ['action', 'session_id', 'memory_ids', 'memory_consent', 'message_ids', 'message_consent']);
      const memoryIds = ids(b.memory_ids, 'memory_ids', MAX_MEMORY_IDS);
      const messageIds = ids(b.message_ids, 'message_ids', MAX_MESSAGE_IDS);
      if (memoryIds.length > 0 && b.memory_consent !== true) {
        bad('Choose "Allow once" before sharing memories with Therabot.');
      }
      if (messageIds.length > 0 && b.message_consent !== true) {
        bad('Confirm the messages you want to share with Therabot first.');
      }
      // Sharing memories or chat messages arrives in a later phase (2e).
      // Until then nothing is read, so nothing can be sent by mistake.
      if (memoryIds.length > 0 || messageIds.length > 0) {
        bad('Sharing memories or messages with Therabot is not available yet.');
      }
      return { action: 'summarize', sessionId: uuid(b.session_id, 'session_id'), memoryIds, messageIds };
    }
    case 'reflect':
      onlyKeys(b, ['action', 'session_id']);
      return { action: 'reflect', sessionId: uuid(b.session_id, 'session_id') };
    default:
      bad('Unknown Therabot action.');
  }
}
