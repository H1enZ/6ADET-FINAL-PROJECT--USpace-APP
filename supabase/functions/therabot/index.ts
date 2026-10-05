// Therabot Edge Function: "A private relationship reflection assistant".
//
// POST { action: "summarize", session_id }  one person's private summary
// POST { action: "reflect",   session_id }  the couple's shared reflection
//
// Security boundary (see supabase/migrations/011_therabot.sql):
//   * The caller is always the verified JWT owner; the only id in the body
//     is the session id. Reads use the caller's JWT, so row-level security
//     applies: a person can only ever load THEIR OWN private answers.
//   * The service-role client is used only for the server-only functions
//     (purge, reserve/store summary, claim/release, approved-summary input,
//     store reflection), each of which re-checks the session state itself.
//   * The shared reflection is built only from the two approved summaries
//     returned by therabot_reflection_input(). Raw answers never reach it.
//   * Logs carry ids, action, provider, timings and outcome codes only.

import { getProvider, type AiProvider } from '../_shared/ai/index.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { adminClient, bearerToken, type Client, userClient, verifiedUserId } from '../_shared/supabase.ts';
import {
  CHAT_SYSTEM,
  CHAT_TASK,
  type ChatMessage,
  type ChatMode,
  type ChatTurn,
  chatInput,
  COUPLE_JOIN_CHIPS,
  COUPLE_JOIN_OPENER,
  COUPLE_JOIN_REASONS,
  COUPLE_START_GREETING,
  COUPLE_START_REASONS,
  COUPLE_WRAP,
  ENOUGH_REPLY,
  GOAL_AFTER_TURNS,
  GOAL_CHIPS,
  GOAL_QUESTION,
  GOALS,
  HEARD_REPLY,
  MAX_AI_TURNS,
  MAX_NOTES,
  MAX_STORED_MESSAGES,
  opening,
  PERSPECTIVE_NOTE,
  perspectiveAnswers,
  TALK_GREETING,
  TALK_REASONS,
  TALK_SUMMARY_TASK,
  TALK_WRAP,
  type TalkSummary,
  talkSummaryInput,
  userWords,
  validateChatTurn,
  validateTalkSummary,
} from '../_shared/therabot/chat.ts';
import { MESSAGES, TherabotError } from '../_shared/therabot/errors.ts';
import { generateChecked } from '../_shared/therabot/generate.ts';
import { PRIVATE_TASK, SHARED_TASK, privateInput, sharedInput } from '../_shared/therabot/prompts.ts';
import { MAX_BODY_BYTES, parseRequest, type TherabotRequest } from '../_shared/therabot/request.ts';
import { prescreen } from '../_shared/therabot/safety.ts';
import {
  type PrivateReflection,
  type SafetyCheck,
  type SharedReflection,
  storedReflection,
  validatePrivateReflection,
  validateSharedReflection,
} from '../_shared/therabot/schemas.ts';

const MAX_AI_ATTEMPTS = 3; // matches the ai_attempts check in migration 011

interface LogEntry {
  action: string;
  session_id?: string;
  provider?: string;
  model?: string;
  attempts?: number;
  rejected?: string[];
  /** Token counts only (summed over a retry); never any text. */
  input_tokens?: number;
  output_tokens?: number;
  outcome: string;
  ms: number;
}

function log(entry: LogEntry): void {
  // Ids, timings and codes only: never answers, summaries or reflections.
  console.log(JSON.stringify({ fn: 'therabot', ...entry }));
}

function reply(request: Request, status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), 'Content-Type': 'application/json; charset=utf-8' },
  });
}

/** Turns a database error into a safe app error. Only our own raised messages pass through. */
function fromDb(error: { code?: string; message?: string } | null): TherabotError {
  if (error?.code === 'P0001' && error.message) {
    if (error.message.startsWith('The summary limit')) return new TherabotError('rate_limited', error.message);
    return new TherabotError('invalid_state', error.message);
  }
  return new TherabotError('internal', MESSAGES.internal);
}

/** Reads the body as a stream and stops as soon as it is too large. */
async function readBody(request: Request): Promise<string> {
  const declared = Number(request.headers.get('content-length'));
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) {
    throw new TherabotError('bad_input', 'The request is too large.');
  }
  if (!request.body) return '';
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new TherabotError('bad_input', 'The request is too large.');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    bytes.set(c, offset);
    offset += c.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

async function purgeExpired(admin: Client): Promise<void> {
  const { error } = await admin.rpc('therabot_purge_expired');
  // Expired rows are already unreadable through row-level security, so a
  // failed clean-up must not block the request; it runs again next time.
  if (error) log({ action: 'purge', outcome: `purge_failed:${error.code ?? 'unknown'}`, ms: 0 });
}

interface SessionRow {
  id: string;
  status: string;
  expires_at: string;
  shared_reflection: Record<string, unknown> | null;
  reflection_attempts: number;
}

/** The session as the caller is allowed to see it (participant, own couple). */
async function loadSession(user: Client, sessionId: string): Promise<SessionRow> {
  const { data, error } = await user
    .from('therabot_sessions')
    .select('id, status, expires_at, shared_reflection, reflection_attempts')
    .eq('id', sessionId)
    .maybeSingle();
  if (error) throw fromDb(error);
  if (!data) throw new TherabotError('not_allowed', MESSAGES.notFound);
  return data as SessionRow;
}

function isExpired(session: SessionRow): boolean {
  return new Date(session.expires_at).getTime() <= Date.now();
}

// ------------------------------------------------------------------ summarize

async function summarize(
  req: Extract<TherabotRequest, { action: 'summarize' }>,
  userId: string,
  user: Client,
  admin: Client,
  provider: AiProvider,
  entry: LogEntry,
): Promise<unknown> {
  await purgeExpired(admin);

  const session = await loadSession(user, req.sessionId);
  if (isExpired(session)) throw new TherabotError('expired', MESSAGES.expired);
  if (session.status !== 'collecting') {
    throw new TherabotError('invalid_state', 'This session is no longer collecting answers.');
  }

  // Row-level security returns only the caller's own submission; the user
  // id filter just makes that explicit. The partner's row is never queried.
  const { data: sub, error: subError } = await user
    .from('therabot_submissions')
    .select('id, status, ai_attempts')
    .eq('session_id', session.id)
    .eq('user_id', userId)
    .maybeSingle();
  if (subError) throw fromDb(subError);
  if (!sub) throw new TherabotError('invalid_state', 'Save your answers before asking for a summary.');
  const subId = String(sub.id); // the caller's own row, from the RLS-scoped read above
  if (sub.status !== 'draft' && sub.status !== 'summary_ready') {
    throw new TherabotError('invalid_state', 'Your summary can no longer be changed in this session.');
  }
  if (Number(sub.ai_attempts) >= MAX_AI_ATTEMPTS) {
    throw new TherabotError('rate_limited', 'You have used all your summaries for this session.');
  }

  // Use up one attempt BEFORE calling the AI (a failed call still counts).
  // The returned version ties the stored summary to these exact answers.
  const { data: version, error: reserveError } = await admin.rpc('therabot_reserve_summary_attempt', {
    p_submission_id: subId,
  });
  if (reserveError) throw fromDb(reserveError);

  // Read the answers AFTER reserving, as the caller (row-level security).
  const { data: row, error: rowError } = await user
    .from('therabot_submissions')
    .select('what_happened, feelings, wish_understood, need_now')
    .eq('id', subId)
    .eq('user_id', userId)
    .maybeSingle();
  if (rowError) throw fromDb(rowError);
  if (!row) throw new TherabotError('invalid_state', 'Save your answers before asking for a summary.');
  const answers = {
    what_happened: row.what_happened as string | null,
    feelings: row.feelings as string | null,
    wish_understood: row.wish_understood as string | null,
    need_now: row.need_now as string | null,
  };

  // Insights the caller saved earlier (owner-only by row-level security).
  const { data: insightRows, error: insightError } = await user
    .from('therabot_insights')
    .select('body')
    .order('created_at', { ascending: false })
    .limit(20);
  if (insightError) throw fromDb(insightError);
  const insights = (insightRows ?? []).map((r) => String(r.body));

  const context = {}; // memories / chat messages arrive in phase 2e
  const store = async (summary: Record<string, unknown>, flagged: boolean) => {
    const { error } = await admin.rpc('therabot_store_summary', {
      p_submission_id: subId,
      p_version: version,
      p_summary: summary,
      p_context: context,
      p_flagged: flagged,
    });
    if (error) throw fromDb(error);
  };
  const safetyReply = (categories: string[], message: string) => ({
    status: 'safety',
    safety: { categories, message }, // the owner only; the partner never sees this
  });

  // 1. Deterministic safety floor on the caller's own words. If it flags,
  //    the AI is never called, so no model can override it.
  const ownWords = Object.values(answers);
  const floor = prescreen(ownWords);
  if (floor.flagged) {
    await store({ safety: floor }, true);
    entry.outcome = 'safety_floor';
    return safetyReply(floor.categories, floor.message);
  }

  // 2. The model, with safety-first checks, validation, lint, one retry.
  const generated = await generateChecked<PrivateReflection>(
    provider,
    { ...PRIVATE_TASK, user: privateInput(answers, insights) },
    validatePrivateReflection,
    (r) => ({
      restating: [{
        texts: [r.summary, ...r.needs],
        source: [...ownWords.filter((t): t is string => typeof t === 'string'), ...insights],
      }],
      authored: [...r.uncertain_points, ...r.suggested_insights],
    }),
  );
  entry.model = generated.model;
  entry.attempts = generated.attempts;
  entry.rejected = generated.rejected;
  entry.input_tokens = generated.usage?.inputTokens;
  entry.output_tokens = generated.usage?.outputTokens;

  if (generated.safety.flagged || !generated.value) {
    await store({ safety: generated.safety }, true);
    entry.outcome = 'safety_model';
    return safetyReply(generated.safety.categories, generated.safety.message);
  }

  const reflection = generated.value;
  await store(reflection as unknown as Record<string, unknown>, false);

  entry.outcome = 'summary_ready';
  return {
    status: 'summary_ready',
    reflection: {
      summary: reflection.summary, // built from sections; kept for older apps
      sections: reflection.sections,
      needs: reflection.needs,
      uncertain_points: reflection.uncertain_points,
      suggested_insights: reflection.suggested_insights,
    },
    summaries_left: Math.max(0, MAX_AI_ATTEMPTS - (Number(sub.ai_attempts) + 1)),
  };
}

// -------------------------------------------------------------------- reflect

async function reflect(
  req: Extract<TherabotRequest, { action: 'reflect' }>,
  user: Client,
  admin: Client,
  provider: AiProvider,
  entry: LogEntry,
): Promise<unknown> {
  await purgeExpired(admin);

  const session = await loadSession(user, req.sessionId);

  // Already written (e.g. the partner's request got there first): return it.
  if ((session.status === 'reflection_ready' || session.status === 'completed') && session.shared_reflection) {
    entry.outcome = 'already_ready';
    return { status: session.status, reflection: session.shared_reflection };
  }
  if (session.status === 'closed') {
    entry.outcome = 'closed';
    return { status: 'closed' };
  }
  if (isExpired(session)) throw new TherabotError('expired', MESSAGES.expired);
  if (session.status !== 'reflecting') {
    throw new TherabotError('invalid_state', 'Both of you need to approve your summaries first.');
  }

  // Both partners approved? (Progress is couple-visible; no content.)
  const { data: people, error: peopleError } = await user
    .from('therabot_participants')
    .select('progress')
    .eq('session_id', session.id);
  if (peopleError) throw fromDb(peopleError);
  if ((people ?? []).length !== 2 || !(people ?? []).every((p) => p.progress === 'approved')) {
    throw new TherabotError('invalid_state', 'Both of you need to approve your summaries first.');
  }

  // Only one request writes the reflection at a time, at most 3 tries.
  const { data: claim, error: claimError } = await admin.rpc('therabot_claim_reflection', {
    p_session_id: session.id,
  });
  if (claimError) throw fromDb(claimError);
  if (typeof claim !== 'string' || claim.length === 0) {
    if (Number(session.reflection_attempts) >= 3) {
      throw new TherabotError(
        'rate_limited',
        "Therabot couldn't write your reflection this time. You can end this session and start again later.",
      );
    }
    throw new TherabotError('invalid_state', 'Your reflection is already being written. Try again in a moment.');
  }

  let stored = false;
  try {
    // The ONLY input: both approved summaries, labelled Partner 1 / Partner 2.
    const { data: rows, error: inputError } = await admin.rpc('therabot_reflection_input', {
      p_session_id: session.id,
    });
    if (inputError) throw fromDb(inputError);
    const input = (rows ?? []) as Array<{ partner: number; approved_summary: string }>;
    const p1 = input.find((r) => Number(r.partner) === 1);
    const p2 = input.find((r) => Number(r.partner) === 2);
    if (input.length !== 2 || !p1 || !p2) {
      throw new TherabotError('invalid_state', "This session can't be reflected on right now.");
    }

    // Safety floor over the approved summaries. A flag closes the session
    // for both, with no reason recorded anywhere the couple can read.
    const floor = prescreen([p1.approved_summary, p2.approved_summary]);
    let flagged = floor.flagged;
    let reflectionToStore: Record<string, unknown> | null = null;

    if (!flagged) {
      const generated = await generateChecked<SharedReflection>(
        provider,
        { ...SHARED_TASK, user: sharedInput(p1.approved_summary, p2.approved_summary) },
        validateSharedReflection,
        (r) => ({
          // Each perspective may only repeat ITS OWN partner's words.
          restating: r.perspectives.map((p) => ({
            texts: [p.summary, ...p.needs],
            source: [p.partner === '1' ? p1.approved_summary : p2.approved_summary],
            // Both partners read this: a verdict or next-step pick from one
            // partner's words must stay visibly theirs, in quotes.
            quoteAll: true,
          })),
          authored: [
            ...r.differences,
            ...r.possible_misunderstandings,
            ...r.common_ground,
            ...r.something_to_try,
            ...r.discussion_questions,
          ],
        }),
      );
      entry.model = generated.model;
      entry.attempts = generated.attempts;
      entry.rejected = generated.rejected;
      entry.input_tokens = generated.usage?.inputTokens;
      entry.output_tokens = generated.usage?.outputTokens;
      flagged = generated.safety.flagged || !generated.value;
      if (!flagged && generated.value) reflectionToStore = storedReflection(generated.value);
    }

    const { error: storeError } = await admin.rpc('therabot_store_reflection', {
      p_session_id: session.id,
      p_claim: claim,
      p_reflection: reflectionToStore,
      p_title: null,
      p_flagged: flagged,
    });
    if (storeError) throw fromDb(storeError);
    stored = true;

    if (flagged) {
      // Same answer for both partners, and the same as a manual end.
      entry.outcome = floor.flagged ? 'closed_safety_floor' : 'closed_safety_model';
      return { status: 'closed' };
    }
    entry.outcome = 'reflection_ready';
    return { status: 'reflection_ready', reflection: reflectionToStore };
  } finally {
    // Any failure gives OUR claim back at once, so the couple can retry.
    if (!stored) {
      const { error } = await admin.rpc('therabot_release_reflection', { p_session_id: session.id, p_claim: claim });
      if (error) log({ action: 'release', session_id: session.id, outcome: `release_failed:${error.code ?? 'unknown'}`, ms: 0 });
    }
  }
}

// --------------------------------------------------------------- guided chat
//
// Private Talk and the Couple Reflection chat share one turn engine. Fixed
// steps (openers, quick replies, the goal question, "just needed to be
// heard") never call the AI. An AI turn gets the topic, the goal, the AI's
// own short working notes and the last few messages: never the whole chat.
// The working notes stay on the server: they are read with the service-role
// client after the caller's ownership is confirmed through row-level
// security, and they are never returned to the app.

interface ChatState {
  id: string;
  version: string;
  messages: ChatMessage[];
  notes: string[];
  stage: string;
  reason: string | null;
  goal: string | null;
  turns: number;
}

function asMessages(x: unknown): ChatMessage[] {
  if (!Array.isArray(x)) return [];
  return x.filter((m) => m && typeof m === 'object' && typeof (m as ChatMessage).text === 'string')
    .map((m) => {
      const msg = m as ChatMessage;
      return { role: msg.role === 'user' ? 'user' : 'therabot', text: msg.text, ...(msg.chips ? { chips: msg.chips } : {}) };
    });
}

function asNotes(x: unknown): string[] {
  return Array.isArray(x) ? x.filter((n): n is string => typeof n === 'string').slice(0, MAX_NOTES) : [];
}

/** Older messages lose their quick replies: only the newest offer is live. */
function withoutChips(messages: ChatMessage[]): ChatMessage[] {
  return messages.map(({ role, text }) => ({ role, text }));
}

function append(state: ChatState, ...add: ChatMessage[]): ChatMessage[] {
  const all = [...withoutChips(state.messages), ...add];
  if (all.length > MAX_STORED_MESSAGES) {
    throw new TherabotError('invalid_state', "This conversation has reached its length. Let's wrap it up.");
  }
  return all;
}

/** What the app gets back: the visible chat and where it is. Never the notes. */
function publicState(state: ChatState, extra: Record<string, unknown> = {}) {
  return {
    messages: state.messages,
    stage: state.stage,
    goal: state.goal,
    turns_left: Math.max(0, MAX_AI_TURNS - state.turns),
    ...extra,
  };
}

const safetyReply = (categories: string[], message: string) => ({
  status: 'safety',
  safety: { categories, message }, // the owner only; the partner never sees this
});

/**
 * One guided AI turn (or the fixed closing line once the cap is reached).
 * Returns the reply, the new notes, whether it's enough, and whether the AI
 * was used (so the turn counts).
 */
async function guidedTurn(
  provider: AiProvider,
  mode: ChatMode,
  state: ChatState,
  message: string | null,
  entry: LogEntry,
): Promise<{ reply: string; notes: string[]; enough: boolean; ai: boolean } | { safety: SafetyCheck }> {
  if (state.turns >= MAX_AI_TURNS) {
    return { reply: ENOUGH_REPLY, notes: state.notes, enough: true, ai: false };
  }
  const ownWords = [...userWords(state.messages), ...(message === null ? [] : [message])];
  const generated = await generateChecked<ChatTurn>(
    provider,
    {
      ...CHAT_TASK,
      system: CHAT_SYSTEM[mode],
      user: chatInput({
        topic: state.reason,
        goal: state.goal,
        notes: state.notes,
        recent: state.messages,
        message,
        // The next step asks what would help: no question of its own then.
        wrapUp: state.goal === null && state.stage !== 'goal' && state.turns + 1 >= GOAL_AFTER_TURNS,
      }),
    },
    validateChatTurn,
    // The reply may repeat their own words, but a label or verdict only in
    // quotes, as theirs; everything else in it is held to the strict rules.
    (r) => ({ restating: [{ texts: [r.reply], source: ownWords, quoteAll: true }], authored: [] }),
  );
  entry.model = generated.model;
  entry.attempts = generated.attempts;
  entry.rejected = generated.rejected;
  entry.input_tokens = generated.usage?.inputTokens;
  entry.output_tokens = generated.usage?.outputTokens;
  if (generated.safety.flagged || !generated.value) return { safety: generated.safety };
  return { reply: generated.value.reply, notes: generated.value.notes, enough: generated.value.enough, ai: true };
}

/** Puts quick replies on the last Therabot message. */
function attachChips(messages: ChatMessage[], chips: Array<[string, string]>): ChatMessage[] {
  const last = messages[messages.length - 1];
  if (!last || last.role !== 'therabot') return messages;
  return [...messages.slice(0, -1), { ...last, chips }];
}

/**
 * Where the chat goes after a Therabot reply: ask what would help once
 * enough is understood (or after a few turns), offer the wrap-up once a goal
 * is chosen or the turns run out, otherwise keep talking.
 */
function settle(
  state: ChatState,
  userText: string | null,
  reply: string,
  enough: boolean,
  turnsAfter: number,
  wrap: Array<[string, string]>,
): { messages: ChatMessage[]; stage: string } {
  const base = append(
    state,
    ...(userText === null ? [] : [{ role: 'user', text: userText } as ChatMessage]),
    { role: 'therabot', text: reply },
  );
  if (state.goal === null) {
    // They typed instead of choosing: offer the same choices again.
    if (state.stage === 'goal') return { messages: attachChips(base, GOAL_CHIPS), stage: 'goal' };
    if (enough || turnsAfter >= GOAL_AFTER_TURNS) {
      if (base.length + 1 > MAX_STORED_MESSAGES) return { messages: attachChips(base, wrap), stage: 'wrap' };
      return { messages: [...base, { role: 'therabot', text: GOAL_QUESTION, chips: GOAL_CHIPS }], stage: 'goal' };
    }
    if (turnsAfter >= MAX_AI_TURNS) return { messages: attachChips(base, wrap), stage: 'wrap' };
    return { messages: base, stage: 'chat' };
  }
  return { messages: attachChips(base, wrap), stage: 'wrap' };
}

// ------------------------------------------------------------ Private Talk

async function loadTalk(user: Client, admin: Client, talkId: string, userId: string) {
  // Row-level security: only the caller's own, unexpired talk comes back.
  const { data, error } = await user
    .from('therabot_private_talks')
    .select('id, reason, goal, stage, messages, ai_turns, summary, summary_attempts, updated_at')
    .eq('id', talkId)
    .maybeSingle();
  if (error) throw fromDb(error);
  if (!data) throw new TherabotError('not_allowed', 'This private talk has ended.');
  const { data: hidden, error: notesError } = await admin
    .from('therabot_private_talks')
    .select('notes')
    .eq('id', talkId)
    .eq('user_id', userId)
    .maybeSingle();
  if (notesError) throw fromDb(notesError);
  const state: ChatState = {
    id: String(data.id),
    version: String(data.updated_at),
    messages: asMessages(data.messages),
    notes: asNotes(hidden?.notes),
    stage: String(data.stage),
    reason: (data.reason as string | null) ?? null,
    goal: (data.goal as string | null) ?? null,
    turns: Number(data.ai_turns),
  };
  return { state, summary: (data.summary as string | null) ?? null, summaryAttempts: Number(data.summary_attempts) };
}

async function writeTalk(
  admin: Client,
  userId: string,
  state: ChatState,
  changes: { messages?: ChatMessage[]; notes?: string[]; stage?: string; goal?: string; summary?: string; aiTurn?: boolean; summaryAttempt?: boolean },
): Promise<ChatState> {
  const { data, error } = await admin.rpc('therabot_talk_write', {
    p_talk_id: state.id,
    p_user: userId,
    p_version: state.version,
    p_messages: changes.messages ?? null,
    p_notes: changes.notes ?? null,
    p_stage: changes.stage ?? null,
    p_goal: changes.goal ?? null,
    p_summary: changes.summary ?? null,
    p_ai_turn: changes.aiTurn ?? false,
    p_summary_attempt: changes.summaryAttempt ?? false,
  });
  if (error) throw fromDb(error);
  return {
    ...state,
    version: String(data),
    messages: changes.messages ?? state.messages,
    notes: changes.notes ?? state.notes,
    stage: changes.stage ?? state.stage,
    goal: changes.goal ?? state.goal,
    turns: state.turns + (changes.aiTurn ? 1 : 0),
  };
}

async function talkSafety(admin: Client, userId: string, state: ChatState, entry: LogEntry, categories: string[], message: string) {
  await writeTalk(admin, userId, state, { stage: 'safety' });
  entry.outcome = 'talk_safety';
  return safetyReply(categories, message);
}

async function talkAction(
  req: Extract<TherabotRequest, { action: 'talk_start' | 'talk_message' | 'talk_goal' | 'talk_summary' }>,
  userId: string,
  user: Client,
  admin: Client,
  provider: AiProvider,
  entry: LogEntry,
): Promise<unknown> {
  await purgeExpired(admin);

  if (req.action === 'talk_start') {
    let open: { label: string; reply: string };
    try {
      open = opening(TALK_REASONS, req.reasonKey, req.reasonText);
    } catch {
      throw new TherabotError('bad_input', 'Choose what brought you here.');
    }
    const messages: ChatMessage[] = [
      { role: 'therabot', text: TALK_GREETING },
      { role: 'user', text: open.label },
      { role: 'therabot', text: open.reply },
    ];
    const floor = prescreen([open.label]);
    const { data: id, error } = await admin.rpc('therabot_talk_create', {
      p_user: userId,
      p_reason: open.label,
      p_messages: messages,
    });
    if (error) throw fromDb(error);
    const { state } = await loadTalk(user, admin, String(id), userId);
    if (floor.flagged) return await talkSafety(admin, userId, state, entry, floor.categories, floor.message);
    entry.outcome = 'talk_started';
    return { talk_id: state.id, ...publicState(state) };
  }

  const loaded = await loadTalk(user, admin, req.talkId, userId);
  let state = loaded.state;
  if (state.stage === 'safety' || state.stage === 'done') {
    throw new TherabotError('invalid_state', 'This private talk is closed.');
  }

  if (req.action === 'talk_message') {
    if (!['chat', 'wrap', 'goal', 'summary'].includes(state.stage)) {
      throw new TherabotError('invalid_state', 'This private talk is closed.');
    }
    const floor = prescreen([req.text]);
    if (floor.flagged) {
      state = await writeTalk(admin, userId, state, { messages: append(state, { role: 'user', text: req.text }) });
      return await talkSafety(admin, userId, state, entry, floor.categories, floor.message);
    }
    const turn = await guidedTurn(provider, 'talk', state, req.text, entry);
    if ('safety' in turn) {
      state = await writeTalk(admin, userId, state, { messages: append(state, { role: 'user', text: req.text }) });
      return await talkSafety(admin, userId, state, entry, turn.safety.categories, turn.safety.message);
    }
    const next = settle(state, req.text, turn.reply, turn.enough, state.turns + (turn.ai ? 1 : 0), TALK_WRAP);
    state = await writeTalk(admin, userId, state, {
      messages: next.messages,
      notes: turn.notes,
      stage: next.stage,
      aiTurn: turn.ai,
    });
    entry.outcome = 'talk_turn';
    return publicState(state);
  }

  if (req.action === 'talk_goal') {
    if (state.stage !== 'goal') throw new TherabotError('invalid_state', 'Answer the question first.');
    const label = GOALS[req.goal];
    const picked: ChatState = { ...state, goal: req.goal };
    if (req.goal === 'heard') {
      const messages = attachChips(
        append(state, { role: 'user', text: label }, { role: 'therabot', text: HEARD_REPLY }),
        TALK_WRAP,
      );
      state = await writeTalk(admin, userId, state, { messages, stage: 'wrap', goal: req.goal });
      entry.outcome = 'talk_goal_heard';
      return publicState(state);
    }
    const withGoal: ChatState = { ...picked, messages: append(state, { role: 'user', text: label }) };
    const turn = await guidedTurn(provider, 'talk', withGoal, null, entry);
    if ('safety' in turn) return await talkSafety(admin, userId, state, entry, turn.safety.categories, turn.safety.message);
    const messages = attachChips([...withGoal.messages, { role: 'therabot', text: turn.reply }], TALK_WRAP);
    state = await writeTalk(admin, userId, state, { messages, notes: turn.notes, stage: 'wrap', goal: req.goal, aiTurn: turn.ai });
    entry.outcome = 'talk_goal';
    return publicState(state);
  }

  // talk_summary: "Here's what I heard", private to them.
  if (!userWords(state.messages).length) throw new TherabotError('invalid_state', 'Tell Therabot something first.');
  if (loaded.summaryAttempts >= 2) {
    throw new TherabotError('rate_limited', 'You have used the summaries for this talk. You can still edit it yourself.');
  }
  // Count the attempt BEFORE calling the AI (a failed call still counts).
  state = await writeTalk(admin, userId, state, { summaryAttempt: true });
  const words = userWords(state.messages);
  const generated = await generateChecked<TalkSummary>(
    provider,
    { ...TALK_SUMMARY_TASK, user: talkSummaryInput(state.reason, state.goal, state.messages) },
    validateTalkSummary,
    (r) => ({ restating: [{ texts: r.points, source: words, quoteAll: true }], authored: [] }),
  );
  entry.model = generated.model;
  entry.attempts = generated.attempts;
  entry.input_tokens = generated.usage?.inputTokens;
  entry.output_tokens = generated.usage?.outputTokens;
  if (generated.safety.flagged || !generated.value) {
    return await talkSafety(admin, userId, state, entry, generated.safety.categories, generated.safety.message);
  }
  const summary = generated.value.points.map((p) => `• ${p}`).join('\n');
  state = await writeTalk(admin, userId, state, { summary, stage: 'summary' });
  entry.outcome = 'talk_summary';
  return publicState(state, { summary });
}

// ------------------------------------------------- Couple Reflection chat

async function loadMyChat(user: Client, admin: Client, sessionId: string, userId: string) {
  const { data, error } = await user
    .from('therabot_submissions')
    .select('id, status, reason, goal, chat_stage, messages, chat_turns, consented_at, ai_attempts, updated_at')
    .eq('session_id', sessionId)
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw fromDb(error);
  if (!data) return null;
  const { data: hidden, error: notesError } = await admin
    .from('therabot_submissions')
    .select('notes')
    .eq('id', String(data.id))
    .eq('user_id', userId)
    .maybeSingle();
  if (notesError) throw fromDb(notesError);
  return {
    status: String(data.status),
    consented: data.consented_at !== null,
    aiAttempts: Number(data.ai_attempts),
    state: {
      id: String(data.id),
      version: String(data.updated_at),
      messages: asMessages(data.messages),
      notes: asNotes(hidden?.notes),
      stage: String(data.chat_stage),
      reason: (data.reason as string | null) ?? null,
      goal: (data.goal as string | null) ?? null,
      turns: Number(data.chat_turns),
    } as ChatState,
  };
}

async function writeChat(
  admin: Client,
  userId: string,
  state: ChatState,
  changes: { messages?: ChatMessage[]; notes?: string[]; stage?: string; reason?: string; goal?: string; aiTurn?: boolean },
): Promise<ChatState> {
  const { data, error } = await admin.rpc('therabot_chat_write', {
    p_submission_id: state.id,
    p_user: userId,
    p_version: state.version,
    p_messages: changes.messages ?? null,
    p_notes: changes.notes ?? null,
    p_stage: changes.stage ?? null,
    p_reason: changes.reason ?? null,
    p_goal: changes.goal ?? null,
    p_ai_turn: changes.aiTurn ?? false,
  });
  if (error) throw fromDb(error);
  return {
    ...state,
    version: String(data),
    messages: changes.messages ?? state.messages,
    notes: changes.notes ?? state.notes,
    stage: changes.stage ?? state.stage,
    reason: changes.reason ?? state.reason,
    goal: changes.goal ?? state.goal,
    turns: state.turns + (changes.aiTurn ? 1 : 0),
  };
}

/** A safety stop in a Couple Reflection: closes the session, as in 011. */
async function chatSafety(admin: Client, state: ChatState, entry: LogEntry, safety: SafetyCheck) {
  const { error } = await admin.rpc('therabot_chat_finish', {
    p_submission_id: state.id,
    p_version: state.version,
    p_summary: { safety },
    p_approved: null,
    p_flagged: true,
  });
  if (error) throw fromDb(error);
  entry.outcome = 'chat_safety';
  return safetyReply(safety.categories, safety.message);
}

async function chatAction(
  req: Extract<TherabotRequest, { action: 'chat_open' | 'chat_pick' | 'chat_message' | 'chat_goal' | 'chat_finish' }>,
  userId: string,
  user: Client,
  admin: Client,
  provider: AiProvider,
  entry: LogEntry,
): Promise<unknown> {
  await purgeExpired(admin);

  const session = await loadSession(user, req.sessionId);
  if (isExpired(session)) throw new TherabotError('expired', MESSAGES.expired);
  if (session.status !== 'collecting') {
    throw new TherabotError('invalid_state', 'This session is no longer collecting reflections.');
  }

  if (req.action === 'chat_open') {
    // Who started it decides which opening they get. Read through the
    // caller's own access (couple-visible session row).
    const { data: started, error: startedError } = await user
      .from('therabot_sessions')
      .select('started_by')
      .eq('id', session.id)
      .maybeSingle();
    if (startedError) throw fromDb(startedError);
    const iStarted = started?.started_by === userId;

    let messages: ChatMessage[];
    let reason: string | null = null;
    if (iStarted) {
      if (!req.reasonKey) throw new TherabotError('bad_input', 'Choose what you would like to reflect on.');
      let open: { label: string; reply: string };
      try {
        open = opening(COUPLE_START_REASONS, req.reasonKey, req.reasonText);
      } catch {
        throw new TherabotError('bad_input', 'Choose what you would like to reflect on.');
      }
      reason = open.label;
      messages = [
        { role: 'therabot', text: COUPLE_START_GREETING },
        { role: 'user', text: open.label },
        { role: 'therabot', text: open.reply },
      ];
    } else {
      // The partner who joins starts neutrally: nothing about how the other
      // partner framed it, not even their topic.
      messages = [{ role: 'therabot', text: COUPLE_JOIN_OPENER, chips: COUPLE_JOIN_CHIPS }];
    }
    const { error } = await admin.rpc('therabot_chat_open', {
      p_user: userId,
      p_session: session.id,
      p_reason: reason,
      p_messages: messages,
    });
    if (error) throw fromDb(error);
    const mine = await loadMyChat(user, admin, session.id, userId);
    if (!mine) throw new TherabotError('internal', MESSAGES.internal);
    if (reason !== null) {
      const floor = prescreen([reason]);
      if (floor.flagged) return await chatSafety(admin, mine.state, entry, floor);
    }
    entry.outcome = 'chat_opened';
    return publicState(mine.state);
  }

  const mine = await loadMyChat(user, admin, session.id, userId);
  if (!mine || !mine.consented) throw new TherabotError('invalid_state', 'Start your part of the reflection first.');
  if (mine.status !== 'draft') throw new TherabotError('invalid_state', 'Your part of this reflection is already finished.');
  let state = mine.state;

  if (req.action === 'chat_pick') {
    if (state.stage !== 'open') throw new TherabotError('invalid_state', 'You have already started.');
    let open: { label: string; reply: string };
    try {
      open = opening(COUPLE_JOIN_REASONS, req.reasonKey, req.reasonText);
    } catch {
      throw new TherabotError('bad_input', 'Choose how you would like to start.');
    }
    const floor = prescreen([open.label]);
    state = await writeChat(admin, userId, state, {
      messages: append(state, { role: 'user', text: open.label }, { role: 'therabot', text: open.reply }),
      stage: 'chat',
      reason: open.label,
    });
    if (floor.flagged) return await chatSafety(admin, state, entry, floor);
    entry.outcome = 'chat_picked';
    return publicState(state);
  }

  if (req.action === 'chat_message') {
    if (!['open', 'chat', 'wrap', 'goal'].includes(state.stage)) {
      throw new TherabotError('invalid_state', 'Your part of this reflection is already finished.');
    }
    const floor = prescreen([req.text]);
    if (floor.flagged) {
      state = await writeChat(admin, userId, state, { messages: append(state, { role: 'user', text: req.text }) });
      return await chatSafety(admin, state, entry, floor);
    }
    const turn = await guidedTurn(provider, 'couple', state, req.text, entry);
    if ('safety' in turn) {
      state = await writeChat(admin, userId, state, { messages: append(state, { role: 'user', text: req.text }) });
      return await chatSafety(admin, state, entry, turn.safety);
    }
    const next = settle(state, req.text, turn.reply, turn.enough, state.turns + (turn.ai ? 1 : 0), COUPLE_WRAP);
    state = await writeChat(admin, userId, state, { messages: next.messages, notes: turn.notes, stage: next.stage, aiTurn: turn.ai });
    entry.outcome = 'chat_turn';
    return publicState(state);
  }

  if (req.action === 'chat_goal') {
    if (state.stage !== 'goal') throw new TherabotError('invalid_state', 'Answer the question first.');
    const label = GOALS[req.goal];
    if (req.goal === 'heard') {
      const messages = attachChips(
        append(state, { role: 'user', text: label }, { role: 'therabot', text: HEARD_REPLY }),
        COUPLE_WRAP,
      );
      state = await writeChat(admin, userId, state, { messages, stage: 'wrap', goal: req.goal });
      entry.outcome = 'chat_goal_heard';
      return publicState(state);
    }
    const withGoal: ChatState = { ...state, goal: req.goal, messages: append(state, { role: 'user', text: label }) };
    const turn = await guidedTurn(provider, 'couple', withGoal, null, entry);
    if ('safety' in turn) return await chatSafety(admin, state, entry, turn.safety);
    const messages = attachChips([...withGoal.messages, { role: 'therabot', text: turn.reply }], COUPLE_WRAP);
    state = await writeChat(admin, userId, state, { messages, notes: turn.notes, stage: 'wrap', goal: req.goal, aiTurn: turn.ai });
    entry.outcome = 'chat_goal';
    return publicState(state);
  }

  // chat_finish: the perspective summary, approved for the shared
  // reflection as agreed at the start. Built from THEIR OWN words only.
  const words = userWords(state.messages);
  if (words.length < 2) {
    throw new TherabotError('invalid_state', 'Tell Therabot a little more before you finish.');
  }
  if (mine.aiAttempts >= MAX_AI_ATTEMPTS) {
    throw new TherabotError('rate_limited', 'You have used all your summaries for this session.');
  }
  const { data: version, error: reserveError } = await admin.rpc('therabot_reserve_summary_attempt', {
    p_submission_id: state.id,
  });
  if (reserveError) throw fromDb(reserveError);
  state = { ...state, version: String(version) };

  const { data: insightRows, error: insightError } = await user
    .from('therabot_insights')
    .select('body')
    .order('created_at', { ascending: false })
    .limit(20);
  if (insightError) throw fromDb(insightError);
  const insights = (insightRows ?? []).map((r) => String(r.body));

  const answers = perspectiveAnswers(state.reason, state.messages);
  const generated = await generateChecked<PrivateReflection>(
    provider,
    {
      ...PRIVATE_TASK,
      system: PRIVATE_TASK.system + PERSPECTIVE_NOTE,
      user: JSON.stringify({
        answers: {
          what_happened_from_my_perspective: answers.what_happened,
          how_i_am_feeling: null,
          what_i_wish_my_partner_understood: null,
          what_i_need_right_now: null,
        },
        saved_preferences: insights.slice(0, 20),
      }),
    },
    validatePrivateReflection,
    (r) => ({ restating: [{ texts: [r.summary, ...r.needs], source: [...words, ...insights] }], authored: [...r.uncertain_points, ...r.suggested_insights] }),
  );
  entry.model = generated.model;
  entry.attempts = generated.attempts;
  entry.rejected = generated.rejected;
  entry.input_tokens = generated.usage?.inputTokens;
  entry.output_tokens = generated.usage?.outputTokens;
  if (generated.safety.flagged || !generated.value) return await chatSafety(admin, state, entry, generated.safety);

  const reflection = generated.value;
  const { data: both, error: finishError } = await admin.rpc('therabot_chat_finish', {
    p_submission_id: state.id,
    p_version: state.version,
    p_summary: reflection as unknown as Record<string, unknown>,
    p_approved: reflection.summary,
    p_flagged: false,
  });
  if (finishError) throw fromDb(finishError);
  entry.outcome = both === true ? 'chat_finished_both' : 'chat_finished';
  // Their own perspective summary is not returned: it is used only for the
  // shared reflection, as they agreed before starting.
  return { stage: 'done', both_finished: both === true };
}

// ----------------------------------------------------------------- the server

Deno.serve(async (request: Request): Promise<Response> => {
  const started = Date.now();
  const entry: LogEntry = { action: 'unknown', outcome: 'started', ms: 0 };

  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(request) });

  try {
    if (request.method !== 'POST') throw new TherabotError('bad_input', 'Use POST.', 405);

    // Who is calling, before anything else is looked at.
    const token = bearerToken(request);
    if (!token) throw new TherabotError('not_signed_in', MESSAGES.signIn);
    const user = userClient(token);
    const userId = await verifiedUserId(user, token);
    if (!userId) throw new TherabotError('not_signed_in', MESSAGES.signIn);

    let body: unknown;
    try {
      body = JSON.parse(await readBody(request));
    } catch (e) {
      if (e instanceof TherabotError) throw e;
      throw new TherabotError('bad_input', 'The request must be JSON.');
    }
    const parsed = parseRequest(body);
    entry.action = parsed.action;
    entry.session_id = 'sessionId' in parsed ? parsed.sessionId : ('talkId' in parsed ? parsed.talkId : undefined);

    let provider: AiProvider;
    try {
      provider = getProvider(Deno.env.get('AI_PROVIDER'), {
        mockMarkers: Deno.env.get('MOCK_MARKERS') === '1',
        groqApiKey: Deno.env.get('GROQ_API_KEY'),
        groqModel: Deno.env.get('GROQ_MODEL'),
      });
    } catch {
      throw new TherabotError('ai_unavailable', MESSAGES.aiUnavailable);
    }
    entry.provider = provider.name;

    const admin = adminClient();
    let data: unknown;
    switch (parsed.action) {
      case 'summarize':
        data = await summarize(parsed, userId, user, admin, provider, entry);
        break;
      case 'reflect':
        data = await reflect(parsed, user, admin, provider, entry);
        break;
      case 'talk_start':
      case 'talk_message':
      case 'talk_goal':
      case 'talk_summary':
        data = await talkAction(parsed, userId, user, admin, provider, entry);
        break;
      default:
        data = await chatAction(parsed, userId, user, admin, provider, entry);
    }

    entry.ms = Date.now() - started;
    log(entry);
    return reply(request, 200, { ok: true, data });
  } catch (e) {
    const error = e instanceof TherabotError ? e : new TherabotError('internal', MESSAGES.internal);
    // Unexpected errors are logged by type only: their messages could
    // contain data.
    entry.outcome = e instanceof TherabotError ? `error:${error.code}` : `error:internal:${(e as Error)?.name ?? 'unknown'}`;
    entry.ms = Date.now() - started;
    log(entry);
    return reply(request, error.status, { ok: false, code: error.code, message: error.message });
  }
});
