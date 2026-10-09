/** Local-only screenshot fixture server. No upstream proxy, database, or real credentials.
 * Serves an isolated build of the real Flutter app from ignored qa/flutter-demo/.
 * All identities and content below are fictional. Session values exist only in memory.
 */
import http from 'node:http';
import { randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const build = fileURLToPath(new URL('../qa/flutter-demo/build/web/', import.meta.url));
const ashley = '10000000-0000-4000-8000-000000000001';
const partner = '10000000-0000-4000-8000-000000000002';
const couple = '20000000-0000-4000-8000-000000000001';
const now = '2026-10-09T01:00:00Z';
const profiles = [
  { user_id: ashley, display_name: 'Ashley', couple_id: couple, created_at: '2024-12-07T00:00:00Z' },
  { user_id: partner, display_name: 'Sam', couple_id: couple, created_at: '2024-12-07T00:00:01Z' },
];
const data = {
  profiles,
  couples: [{ id: couple, pairing_code: 'DEMO00', anniversary_date: '2024-12-07' }],
  moods: profiles.map((p, i) => ({ id: `mood-${i}`, user_id: p.user_id, couple_id: couple, mood: 'loved', note: null, is_shared: true, created_at: now })),
  messages: [
    [partner, 'Morning, love. Did you sleep well?', '00:30'],
    [ashley, 'I did. I had a dream about our next little adventure.', '00:32'],
    [partner, 'The cabin by the lake?', '00:33'],
    [ashley, 'Yes! Coffee on the porch. No alarms. Just us.', '00:34'],
    [partner, 'Adding it to our list. I love doing life with you.', '00:35'],
    [ashley, 'My favourite person. See you tonight.', '00:36'],
  ].map(([sender_id, body, time], i) => ({ id: `message-${i}`, couple_id: couple, sender_id, body, created_at: `2026-10-09T${time}:00Z`, read_at: now })),
  notes: [
    { id: 'note-1', author_id: partner, body: 'Thank you for making the ordinary days feel like something worth remembering. I would choose this little life with you, every time.', sent_at: now, capsule_title: 'My favourite place is with you', category: 'love', is_favorite: true },
    { id: 'note-2', author_id: ashley, body: 'The best part of my day is the moment I get to tell you about it. Here is to all our small adventures.', sent_at: '2026-10-08T12:00:00Z', capsule_title: 'A little reminder', category: 'just_because', is_favorite: false },
  ],
  bucket_items: [
    { id: 'goal-1', couple_id: couple, title: 'A quiet weekend by the lake', location_area: 'Tagaytay', location_spot: 'A cabin with a view', budget: 8000, target_date: '2026-12-05', is_done: false },
    { id: 'goal-2', couple_id: couple, title: 'Find our favourite coffee spot', location_area: 'Pampanga', budget: 1200, target_date: '2026-10-24', is_done: false },
    { id: 'goal-3', couple_id: couple, title: 'Watch a sunrise together', location_area: 'Our next adventure', is_done: true, completed_at: '2026-10-02T22:00:00Z' },
  ],
  bucket_contributions: [{ item_id: 'goal-1', amount: 3500 }, { item_id: 'goal-2', amount: 600 }],
};
const sealed = [{ id: 'capsule-1', author_id: ashley, sent_at: '2026-09-07T01:00:00Z', unlock_at: '2026-12-07T01:00:00Z', capsule_title: 'For our next anniversary' }, { id: 'capsule-2', author_id: partner, sent_at: now, unlock_at: '2027-01-01T01:00:00Z', capsule_title: 'A wish for our new year' }];
const user = { id: ashley, aud: 'authenticated', role: 'authenticated', email: 'ashley@example.invalid', created_at: '2024-12-07T00:00:00Z', app_metadata: { provider: 'email', providers: ['email'] }, user_metadata: { display_name: 'Ashley' } };
const encoded = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const localSession = () => ({
  access_token: [encoded({ alg: 'HS256', typ: 'JWT' }), encoded({ sub: ashley, aud: 'authenticated', exp: Math.floor(Date.now() / 1000) + 86400 }), randomBytes(24).toString('base64url')].join('.'),
  token_type: 'bearer', expires_in: 86400, refresh_token: randomBytes(24).toString('hex'), user,
});
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.ttf': 'font/ttf' };

http.createServer(async (request, response) => {
  response.setHeader('Access-Control-Allow-Origin', 'http://127.0.0.1:54329');
  response.setHeader('Access-Control-Allow-Headers', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.setHeader('Cache-Control', 'no-store');
  if (request.method === 'OPTIONS') { response.writeHead(204); response.end(); return; }
  const url = new URL(request.url, 'http://127.0.0.1:54329');
  const json = (body, status = 200) => { response.writeHead(status, { 'Content-Type': 'application/json' }); response.end(JSON.stringify(body)); };
  if (url.pathname === '/auth/v1/token') { request.resume(); json(localSession()); return; }
  if (url.pathname === '/auth/v1/user') { json(user); return; }
  if (url.pathname.startsWith('/rest/v1/rpc/')) {
    const rpc = url.pathname.split('/').pop();
    request.resume(); json(rpc === 'sealed_notes' ? sealed : rpc.startsWith('mark_') ? null : []); return;
  }
  if (url.pathname.startsWith('/rest/v1/')) {
    if (request.method !== 'GET' && request.method !== 'HEAD') { request.resume(); json({ message: 'Read-only screenshot dataset' }, 405); return; }
    const table = url.pathname.split('/').pop();
    let rows = [...(data[table] || [])];
    for (const [key, value] of url.searchParams) {
      if (value.startsWith('eq.')) rows = rows.filter((row) => String(row[key]) === value.slice(3));
    }
    if (table === 'messages') rows.reverse();
    if (table === 'notes' && url.searchParams.has('unlock_at')) rows = [];
    response.setHeader('Content-Range', `0-${Math.max(0, rows.length - 1)}/${rows.length}`);
    if (request.method === 'HEAD') { response.writeHead(200); response.end(); return; }
    json(request.headers.accept?.includes('vnd.pgrst.object') ? rows[0] ?? null : rows); return;
  }
  if (url.pathname.startsWith('/realtime/')) { response.writeHead(404); response.end(); return; }
  const path = resolve(build, `.${decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname)}`);
  if (!path.startsWith(resolve(build) + sep)) { response.writeHead(403); response.end(); return; }
  try { const body = await readFile(path); response.writeHead(200, { 'Content-Type': mime[extname(path)] || 'application/octet-stream' }); response.end(body); }
  catch { response.writeHead(404); response.end(); }
}).listen(54329, '127.0.0.1', () => console.log('Isolated Flutter screenshot preview: http://127.0.0.1:54329/'));
