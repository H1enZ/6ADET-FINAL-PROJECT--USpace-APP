// The two Supabase clients an Edge Function may use.
//
//   userClient   acts AS the signed-in caller (their JWT), so every read is
//                limited by row-level security exactly like the app.
//   adminClient  uses the service-role key. Use it ONLY to call functions
//                that were designed as service-role-only in migration 011.
//                Never return anything about it to the app.
//
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided
// to Edge Functions by Supabase; they are not app settings. On projects that
// use the newer API keys, SUPABASE_PUBLISHABLE_KEY can be set as a function
// secret instead of the anon key.

// Pinned so a library update can't change behaviour or types unnoticed.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

export type Client = ReturnType<typeof createClient>;

const OPTIONS = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

function env(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value) return value;
  }
  throw new Error(`Missing function setting ${names[0]}`);
}

/** The caller's bearer token, or null when there isn't one. */
export function bearerToken(request: Request): string | null {
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer\s+([A-Za-z0-9._~+/=-]+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

export function userClient(token: string): Client {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEY'), {
    ...OPTIONS,
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

export function adminClient(): Client {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), OPTIONS);
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
