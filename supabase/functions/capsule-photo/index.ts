// capsule-photo Edge Function: the only way to see or tidy a Time Capsule's
// photo before it is opened.
//
// POST { action: "preview", capsule_id }  the photo's bytes (sender only)
// POST { action: "prune",   capsule_id }  remove files the capsule no
//                                          longer uses (a replaced photo)
// POST { action: "remove",  capsule_id }  remove all of the capsule's files
//                                          (before cancelling or deleting)
//
// Security boundary (see supabase/migrations/014_time_capsules.sql, section 5):
//   * Nobody's own session can read a capsule photo before it is opened, so
//     nobody can make a signed link to it. This function serves the bytes
//     itself instead, and never returns a link or a storage path.
//   * The caller is the verified JWT owner. The body carries only a capsule
//     id; whether the caller may act on it (they are its sender, and it is a
//     draft or being edited) is decided in the database by
//     capsule_photo_access(). A sealed capsule, even within its ten minutes,
//     must be reopened (edit_time_capsule) before its photo can be seen or
//     changed; once opened, the photo is permanent.
//   * The folder and photo path come from the database, never the request,
//     so no other object can be named. Every refusal looks the same.
//   * Responses are never cached: a preview fetched before sealing must not
//     be served again once the capsule is sealed.
//   * Logs carry the action, outcome and timing only.

import { corsHeaders } from '../_shared/cors.ts';
import { adminClient, bearerToken, userClient, verifiedUserId } from '../_shared/supabase.ts';

const BUCKET = 'capsule-photos';
const MAX_BODY_BYTES = 512;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ACTIONS = new Set(['preview', 'prune', 'remove']);

const NO_STORE = {
  'Cache-Control': 'private, no-store, max-age=0',
  Pragma: 'no-cache',
  Expires: '0',
  'X-Content-Type-Options': 'nosniff',
};

function log(action: string, outcome: string, started: number): void {
  console.log(JSON.stringify({ fn: 'capsule-photo', action, outcome, ms: Date.now() - started }));
}

function json(request: Request, status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), ...NO_STORE, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

/** One answer for every refusal: no hint whether the capsule exists. */
const notFound = (request: Request) => json(request, 404, { error: 'not_found' });

async function readBody(request: Request): Promise<{ action: string; capsuleId: string } | null> {
  const text = await request.text();
  if (text.length === 0 || text.length > MAX_BODY_BYTES) return null;
  try {
    const body: unknown = JSON.parse(text);
    if (typeof body !== 'object' || body === null) return null;
    const { action, capsule_id: capsuleId } = body as Record<string, unknown>;
    if (typeof action !== 'string' || !ACTIONS.has(action)) return null;
    if (typeof capsuleId !== 'string' || !UUID.test(capsuleId)) return null;
    return { action, capsuleId };
  } catch {
    return null;
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  const started = Date.now();
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(request) });
  if (request.method !== 'POST') return json(request, 405, { error: 'method_not_allowed' });

  let action = 'unknown';
  try {
    const token = bearerToken(request);
    if (!token) {
      log(action, 'no_token', started);
      return json(request, 401, { error: 'unauthorized' });
    }
    const userId = await verifiedUserId(userClient(token), token);
    if (!userId) {
      log(action, 'bad_token', started);
      return json(request, 401, { error: 'unauthorized' });
    }
    const body = await readBody(request);
    if (!body) {
      log(action, 'bad_request', started);
      return json(request, 400, { error: 'bad_request' });
    }
    action = body.action;

    const admin = adminClient();
    const { data, error } = await admin.rpc('capsule_photo_access', {
      p_capsule: body.capsuleId,
      p_user: userId,
    });
    const access = Array.isArray(data) ? data[0] : null;
    if (error || !access || typeof access.folder !== 'string') {
      log(action, error ? 'access_error' : 'denied', started);
      return notFound(request);
    }
    const folder: string = access.folder;
    const photoPath: string | null = typeof access.photo_path === 'string' ? access.photo_path : null;
    // The path is the database's, but check it is inside the capsule's own
    // folder anyway before touching storage with full privileges.
    if (photoPath !== null && !photoPath.startsWith(`${folder}/`)) {
      log(action, 'path_mismatch', started);
      return notFound(request);
    }
    const storage = admin.storage.from(BUCKET);

    if (action === 'preview') {
      if (!photoPath) {
        log(action, 'no_photo', started);
        return notFound(request);
      }
      const { data: file, error: downloadError } = await storage.download(photoPath);
      if (downloadError || !file) {
        log(action, 'download_error', started);
        return notFound(request);
      }
      log(action, 'ok', started);
      return new Response(await file.arrayBuffer(), {
        status: 200,
        headers: { ...corsHeaders(request), ...NO_STORE, 'Content-Type': 'application/octet-stream' },
      });
    }

    // prune / remove: only files directly inside this capsule's folder.
    const { data: files, error: listError } = await storage.list(folder, { limit: 100 });
    if (listError) {
      log(action, 'list_error', started);
      return notFound(request);
    }
    const doomed = (files ?? [])
      .map((f) => `${folder}/${f.name}`)
      .filter((path) => action === 'remove' || path !== photoPath);
    if (doomed.length > 0) {
      const { error: removeError } = await storage.remove(doomed);
      if (removeError) {
        log(action, 'remove_error', started);
        return json(request, 500, { error: 'try_again' });
      }
    }
    log(action, 'ok', started);
    return json(request, 200, { removed: doomed.length });
  } catch (_) {
    log(action, 'exception', started);
    return json(request, 500, { error: 'try_again' });
  }
});
