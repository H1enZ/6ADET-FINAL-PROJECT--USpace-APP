// Realtime private-channel check (migration 021), against a real Supabase
// project. Run it against DEV only, never production: it creates two
// temporary couples (four throwaway users), runs the checks, then deletes
// them again.
//
//   USPACE_TEST_PROJECT=dev \
//   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \
//   deno run -A supabase/test/realtime_private_channels.ts
//
// The service-role key is only used here, server side, to create and remove
// the temporary users. Never put it in the app or commit it.
import {
  createClient,
  type RealtimeChannel,
  type SupabaseClient,
} from 'npm:@supabase/supabase-js@2';

if (Deno.env.get('USPACE_TEST_PROJECT') !== 'dev') {
  console.log('Refusing to run: set USPACE_TEST_PROJECT=dev (DEV project only).');
  Deno.exit(1);
}
const url = Deno.env.get('SUPABASE_URL')!;
const pub = Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const client = () => createClient(url, pub, { auth: { persistSession: false } });
const admin = (path: string, init: RequestInit = {}) =>
  fetch(`${url}/auth/v1${path}`, {
    ...init,
    headers: { apikey: service, Authorization: `Bearer ${service}`, 'Content-Type': 'application/json' },
  });

const created: string[] = [];
const signedIn: SupabaseClient[] = [];
async function user(label: string): Promise<SupabaseClient> {
  const email = `rt-check-${label}-${Date.now()}@example.invalid`;
  const password = crypto.randomUUID();
  const r = await admin('/admin/users', {
    method: 'POST',
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  created.push((await r.json()).id);
  const c = client();
  await c.auth.signInWithPassword({ email, password });
  await c.realtime.setAuth((await c.auth.getSession()).data.session!.access_token);
  signedIn.push(c);
  return c;
}
async function couple(a: SupabaseClient, b: SupabaseClient): Promise<string> {
  const made = await a.rpc('create_couple', { anniversary: null });
  await b.rpc('join_couple', { code: made.data.pairing_code });
  return made.data.id;
}

const heard: Record<string, string[]> = {};
function join(c: SupabaseClient, who: string, topic: string, priv: boolean) {
  return new Promise<{ ch: RealtimeChannel; status: string }>((resolve) => {
    const ch = c
      .channel(topic, { config: { private: priv } })
      .on('broadcast', { event: 'changed' }, (m: { payload?: { table?: string } }) =>
        (heard[who] ??= []).push(String(m.payload?.table)));
    let done = false;
    const finish = (status: string) => {
      if (!done) { done = true; resolve({ ch, status }); }
    };
    ch.subscribe((s: string) => { if (s !== 'CLOSED') finish(s); });
    setTimeout(() => finish('NO_REPLY'), 8000);
  });
}
const take = (who: string) => { const h = heard[who] ?? []; heard[who] = []; return h; };

const results: Array<[string, boolean, string]> = [];
const check = (name: string, pass: boolean, detail: string) => results.push([name, pass, detail]);

try {
  const [a1, a2, b1, b2] = await Promise.all(['a1', 'a2', 'b1', 'b2'].map(user));
  const anon = client();
  const anonPublic = client();
  const coupleA = await couple(a1, a2);
  const coupleB = await couple(b1, b2);

  const A1 = await join(a1, 'A1', `couple-${coupleA}`, true);
  const A2 = await join(a2, 'A2', `couple-${coupleA}`, true);
  const A2shared = await join(a2, 'A2', `couple-shared-${coupleA}`, true);
  check('members join their own private channels',
    [A1, A2, A2shared].every((x) => x.status === 'SUBSCRIBED'), [A1, A2, A2shared].map((x) => x.status).join(', '));
  await sleep(1500);

  await A1.ch.send({ type: 'broadcast', event: 'changed', payload: { table: 'notes' } });
  await sleep(2000);
  let h = take('A2');
  check('A1 -> A2 is delivered once', h.length === 1 && h[0] === 'notes', `[${h}]`);
  await A2.ch.send({ type: 'broadcast', event: 'changed', payload: { table: 'memories' } });
  await sleep(2000);
  h = take('A1');
  check('A2 -> A1 is delivered once', h.length === 1 && h[0] === 'memories', `[${h}]`);

  for (const topic of [`couple-${coupleA}`, `couple-shared-${coupleA}`]) {
    const x = await join(b1, 'B1', topic, true);
    check(`another couple cannot join ${topic.startsWith('couple-shared') ? 'shared' : 'main'}`, x.status !== 'SUBSCRIBED', x.status);
    await x.ch.send({ type: 'broadcast', event: 'changed', payload: { table: 'inject' } }).catch(() => {});
  }
  const signedOut = await join(anon, 'ANON', `couple-${coupleA}`, true);
  check('signed-out client cannot join', signedOut.status !== 'SUBSCRIBED', signedOut.status);
  await signedOut.ch.send({ type: 'broadcast', event: 'changed', payload: { table: 'inject' } }).catch(() => {});
  await sleep(2500);
  h = [...take('A1'), ...take('A2')];
  check('injected signals from outside are never delivered', h.length === 0, `[${h}]`);

  // The original attack: a PUBLIC channel with the same name is a separate room.
  const pubCh = await join(anonPublic, 'PUB', `couple-${coupleA}`, false);
  await sleep(1000);
  await A1.ch.send({ type: 'broadcast', event: 'changed', payload: { table: 'bucket_items' } });
  await sleep(2000);
  const leaked = take('PUB');
  take('A2');
  await pubCh.ch.send({ type: 'broadcast', event: 'changed', payload: { table: 'inject' } });
  await sleep(2000);
  h = [...take('A1'), ...take('A2')];
  check('a public channel of the same name hears nothing', leaked.length === 0, `[${leaked}]`);
  check('a public channel of the same name cannot inject', h.length === 0, `[${h}]`);

  const B1own = await join(b1, 'B1own', `couple-${coupleB}`, true);
  check('the other couple still has its own channel', B1own.status === 'SUBSCRIBED', B1own.status);
  for (const c of [a1, a2, b1, b2, anon, anonPublic]) await c.removeAllChannels();
} finally {
  // Leave first: the last member leaving deletes the couple itself, so no
  // empty couples are left behind when the users are removed.
  for (const c of signedIn) await c.rpc('leave_couple');
  for (const id of created) await admin(`/admin/users/${id}`, { method: 'DELETE' });
}

for (const [name, pass, detail] of results) console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}  ${detail}`);
const failed = results.filter(([, pass]) => !pass).length;
console.log(`${results.length - failed}/${results.length} passed`);
Deno.exit(failed === 0 ? 0 : 1);
