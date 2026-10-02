// CORS for the web app. Only origins listed in the ALLOWED_ORIGINS secret
// (comma-separated, e.g. "https://h1enz.github.io,http://localhost:8080")
// get the Access-Control-Allow-Origin header; browsers block everyone else.

const BASE_HEADERS = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '600',
  Vary: 'Origin',
};

function allowedOrigins(): string[] {
  return (Deno.env.get('ALLOWED_ORIGINS') ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o.length > 0);
}

export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('origin');
  if (origin && allowedOrigins().includes(origin)) {
    return { ...BASE_HEADERS, 'Access-Control-Allow-Origin': origin };
  }
  return { ...BASE_HEADERS };
}
