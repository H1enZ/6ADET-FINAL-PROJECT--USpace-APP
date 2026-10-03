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
import { MESSAGES, TherabotError } from '../_shared/therabot/errors.ts';
import { generateChecked } from '../_shared/therabot/generate.ts';
import { PRIVATE_TASK, SHARED_TASK, privateInput, sharedInput } from '../_shared/therabot/prompts.ts';
import { MAX_BODY_BYTES, parseRequest, type TherabotRequest } from '../_shared/therabot/request.ts';
import { prescreen } from '../_shared/therabot/safety.ts';
import {
  type PrivateReflection,
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
    entry.session_id = parsed.sessionId;

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
    const data = parsed.action === 'summarize'
      ? await summarize(parsed, userId, user, admin, provider, entry)
      : await reflect(parsed, user, admin, provider, entry);

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
