/**
 * Verifies Firebase Authentication ID tokens.
 *
 * The endpoint has to be authenticated somehow, and a shared secret baked into
 * the APK would be exactly the problem this whole proxy exists to remove — just
 * moved one step along. The app already signs users in with Firebase, so the ID
 * token it already holds is the honest credential: it is short-lived, signed by
 * Google, and identifies a real account we can rate-limit individually.
 */

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

/** Cached across requests on a warm isolate; Google rotates these slowly. */
let jwksCache = { keys: null, expiresAt: 0 };

export class AuthError extends Error {
  constructor(reason) {
    super(reason);
    this.reason = reason;
  }
}

function base64UrlToBytes(input) {
  const padding = input.length % 4 === 0 ? '' : '='.repeat(4 - (input.length % 4));
  const base64 = (input + padding).replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeJson(segment) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment)));
}

async function signingKey(kid) {
  const now = Date.now();
  if (!jwksCache.keys || now >= jwksCache.expiresAt) {
    const response = await fetch(JWKS_URL);
    if (!response.ok) throw new AuthError('jwks_unavailable');
    const body = await response.json();
    // Honour Google's own cache header rather than refetching per request.
    const maxAge = Number(
      (String(response.headers.get('cache-control') || '').match(/max-age=(\d+)/) || [])[1] || 3600,
    );
    jwksCache = { keys: body.keys || [], expiresAt: now + maxAge * 1000 };
  }
  return jwksCache.keys.find((key) => key.kid === kid);
}

/**
 * Returns the verified Firebase uid, or throws [AuthError].
 *
 * Checks the signature and every claim that matters: algorithm, expiry,
 * not-issued-in-the-future, audience and issuer. A token for a *different*
 * Firebase project is a valid Google-signed JWT, so the audience check is what
 * stops it being accepted here.
 */
export async function verifyFirebaseIdToken(token, projectId) {
  if (!token) throw new AuthError('missing_token');
  if (!projectId) throw new AuthError('server_misconfigured');

  const parts = token.split('.');
  if (parts.length !== 3) throw new AuthError('malformed_token');

  let header;
  let payload;
  try {
    header = decodeJson(parts[0]);
    payload = decodeJson(parts[1]);
  } catch {
    throw new AuthError('malformed_token');
  }

  if (header.alg !== 'RS256') throw new AuthError('unexpected_algorithm');
  if (!header.kid) throw new AuthError('missing_key_id');

  const jwk = await signingKey(header.kid);
  if (!jwk) throw new AuthError('unknown_signing_key');

  // Strip alg/use: WebCrypto rejects a JWK whose own alg disagrees with the
  // algorithm we name here, and we name it explicitly on purpose.
  const { kty, n, e } = jwk;
  const key = await crypto.subtle.importKey(
    'jwk',
    { kty, n, e },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const verified = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!verified) throw new AuthError('bad_signature');

  const nowSeconds = Math.floor(Date.now() / 1000);
  const skew = 60;
  if (typeof payload.exp !== 'number' || payload.exp <= nowSeconds - skew) {
    throw new AuthError('token_expired');
  }
  if (typeof payload.iat === 'number' && payload.iat > nowSeconds + 300) {
    throw new AuthError('token_issued_in_future');
  }
  if (payload.aud !== projectId) throw new AuthError('wrong_audience');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new AuthError('wrong_issuer');
  }
  if (!payload.sub || typeof payload.sub !== 'string') {
    throw new AuthError('missing_subject');
  }

  return payload.sub;
}
