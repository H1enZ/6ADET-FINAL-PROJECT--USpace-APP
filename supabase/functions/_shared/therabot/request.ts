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
  | { action: 'reflect'; sessionId: string }
  // Private Talk (never linked to a couple session)
  | { action: 'talk_start'; reasonKey: string; reasonText: string | null }
  | { action: 'talk_message'; talkId: string; text: string }
  | { action: 'talk_goal'; talkId: string; goal: string }
  | { action: 'talk_summary'; talkId: string }
  // Couple Reflection chat (your own private part of a session)
  | { action: 'chat_open'; sessionId: string; reasonKey: string | null; reasonText: string | null }
  | { action: 'chat_pick'; sessionId: string; reasonKey: string; reasonText: string | null }
  | { action: 'chat_message'; sessionId: string; text: string }
  | { action: 'chat_goal'; sessionId: string; goal: string }
  | { action: 'chat_finish'; sessionId: string };

const KEY = /^[a-z_]{1,20}$/;
const GOAL_KEYS = ['understand', 'advice', 'explain', 'solution', 'calm', 'heard'];

function key(x: unknown, field: string): string {
  if (typeof x !== 'string' || !KEY.test(x)) bad(`${field} is not valid.`);
  return x as string;
}

function optionalText(x: unknown, max: number, field: string): string | null {
  if (x === undefined || x === null) return null;
  if (typeof x !== 'string') bad(`${field} must be text.`);
  const t = (x as string).trim();
  if (t.length === 0) return null;
  if (t.length > max) bad(`${field} can be up to ${max} characters.`);
  return t;
}

function message(x: unknown): string {
  const t = optionalText(x, 2000, 'Your message');
  if (t === null) bad('Write something first.');
  return t as string;
}

function goal(x: unknown): string {
  if (typeof x !== 'string' || !GOAL_KEYS.includes(x)) bad('Choose what would help.');
  return x as string;
}

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
    case 'talk_start':
      onlyKeys(b, ['action', 'reason_key', 'reason_text']);
      return {
        action: 'talk_start',
        reasonKey: key(b.reason_key, 'reason_key'),
        reasonText: optionalText(b.reason_text, 120, 'Your reason'),
      };
    case 'talk_message':
      onlyKeys(b, ['action', 'talk_id', 'text']);
      return { action: 'talk_message', talkId: uuid(b.talk_id, 'talk_id'), text: message(b.text) };
    case 'talk_goal':
      onlyKeys(b, ['action', 'talk_id', 'goal']);
      return { action: 'talk_goal', talkId: uuid(b.talk_id, 'talk_id'), goal: goal(b.goal) };
    case 'talk_summary':
      onlyKeys(b, ['action', 'talk_id']);
      return { action: 'talk_summary', talkId: uuid(b.talk_id, 'talk_id') };
    case 'chat_open':
      onlyKeys(b, ['action', 'session_id', 'reason_key', 'reason_text']);
      return {
        action: 'chat_open',
        sessionId: uuid(b.session_id, 'session_id'),
        reasonKey: b.reason_key === undefined || b.reason_key === null ? null : key(b.reason_key, 'reason_key'),
        reasonText: optionalText(b.reason_text, 120, 'Your reason'),
      };
    case 'chat_pick':
      onlyKeys(b, ['action', 'session_id', 'reason_key', 'reason_text']);
      return {
        action: 'chat_pick',
        sessionId: uuid(b.session_id, 'session_id'),
        reasonKey: key(b.reason_key, 'reason_key'),
        reasonText: optionalText(b.reason_text, 120, 'Your reason'),
      };
    case 'chat_message':
      onlyKeys(b, ['action', 'session_id', 'text']);
      return { action: 'chat_message', sessionId: uuid(b.session_id, 'session_id'), text: message(b.text) };
    case 'chat_goal':
      onlyKeys(b, ['action', 'session_id', 'goal']);
      return { action: 'chat_goal', sessionId: uuid(b.session_id, 'session_id'), goal: goal(b.goal) };
    case 'chat_finish':
      onlyKeys(b, ['action', 'session_id']);
      return { action: 'chat_finish', sessionId: uuid(b.session_id, 'session_id') };
    default:
      bad('Unknown Therabot action.');
  }
}
