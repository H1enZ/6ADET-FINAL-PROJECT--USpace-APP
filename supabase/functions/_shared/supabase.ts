// The two Supabase clients an Edge Function may use.
//
//   userClient   acts AS the signed-in caller (their JWT), so every read is
//                limited by row-level security exactly like the app.
//   adminClient  uses the secret (service-role) key. Use it ONLY to call functions
//                that were designed as service-role-only in migration 011.
//                Never return anything about it to the app.
//
// Keys come from the function environment, never from the app. Hosted Edge
// Functions get SUPABASE_URL plus the newer key sets SUPABASE_PUBLISHABLE_KEYS
// and SUPABASE_SECRET_KEYS (JSON objects; we use their "default" entry), and
// on older projects the legacy SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY.
// The newer keys are tried first. SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY
// cover a local server run from an env file.
//
// A key of the wrong kind is refused rather than used: a secret key in the
// user client would bypass row-level security, and a publishable key in the
// admin client would quietly fail every service-role call. Missing or
// unusable settings fail closed. No error message ever contains a key.

// Pinned so a library update can't change behaviour or types unnoticed.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

export type Client = ReturnType<typeof createClient>;

const OPTIONS = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

type KeyKind = 'publishable' | 'secret';

function plain(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  return value ? value : null;
}

/** The "default" entry of a JSON key set such as SUPABASE_SECRET_KEYS. */
function fromKeySet(name: string): string | null {
  const raw = plain(name);
  if (!raw) return null;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return null;
    const key = (parsed as Record<string, unknown>)['default'];
    return typeof key === 'string' && key.trim() ? key.trim() : null;
  } catch {
    // Not JSON. Never echo it: it is a key.
    return null;
  }
}

/** The role claim of a legacy JWT key, or null when it isn't one. */
function legacyRole(key: string): string | null {
  const parts = key.split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    return typeof payload?.role === 'string' ? payload.role : null;
  } catch {
    return null;
  }
}

/** True when [key] is not obviously the other kind of key. */
function looksLike(kind: KeyKind, key: string): boolean {
  const role = legacyRole(key);
  if (kind === 'publishable') {
    return !key.startsWith('sb_secret_') && role !== 'service_role';
  }
  return !key.startsWith('sb_publishable_') && (role === null || role === 'service_role');
}

function key(kind: KeyKind): string {
  const candidates = kind === 'publishable'
    ? [fromKeySet('SUPABASE_PUBLISHABLE_KEYS'), plain('SUPABASE_ANON_KEY'), plain('SUPABASE_PUBLISHABLE_KEY')]
    : [fromKeySet('SUPABASE_SECRET_KEYS'), plain('SUPABASE_SERVICE_ROLE_KEY'), plain('SUPABASE_SECRET_KEY')];
  for (const candidate of candidates) {
    if (candidate && looksLike(kind, candidate)) return candidate;
  }
  throw new Error(`No usable ${kind} Supabase key in the function settings`);
}

function url(): string {
  const value = plain('SUPABASE_URL');
  if (!value) throw new Error('Missing function setting SUPABASE_URL');
  return value;
}

/** The caller's bearer token, or null when there isn't one. */
export function bearerToken(request: Request): string | null {
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer\s+([A-Za-z0-9._~+/=-]+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

export function userClient(token: string): Client {
  return createClient(url(), key('publishable'), {
    ...OPTIONS,
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

export function adminClient(): Client {
  return createClient(url(), key('secret'), OPTIONS);
}

/**
 * Verifies the token with Supabase Auth and returns the caller's user id.
 * The id always comes from here, never from the request body. An expired
 * token, or a plain anon/publishable key used as a bearer, has no user and
 * is refused.
 */
export async function verifiedUserId(client: Client, token: string): Promise<string | null> {
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}
