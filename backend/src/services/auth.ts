import { importJWK, jwtVerify } from 'jose'
import type { AppleClaims } from '../types'

interface AppleJWK {
  kty: string
  kid: string
  use: string
  alg: string
  n: string
  e: string
}

// Fetch Apple's public JWKS (cached by the CF edge runtime via normal HTTP caching).
async function fetchApplePublicKeys(): Promise<AppleJWK[]> {
  const res = await fetch('https://appleid.apple.com/auth/keys', {
    cf: { cacheTtl: 300, cacheEverything: true },
  } as RequestInit)
  if (!res.ok) throw new Error(`Apple JWKS fetch failed: ${res.status}`)
  const body = (await res.json()) as { keys: AppleJWK[] }
  return body.keys
}

/**
 * Validates an Apple identity token (JWT) returned by Sign in with Apple on iOS.
 *
 * @param identityToken  The raw JWT string from ASAuthorizationAppleIDCredential.identityToken
 * @param audience       The app's bundle ID — e.g. "com.ihsan.replr"
 * @throws               If the token is invalid, expired, or the signature doesn't verify
 */
export async function validateAppleToken(
  identityToken: string,
  audience: string
): Promise<AppleClaims> {
  const keys = await fetchApplePublicKeys()

  // Apple rotates keys; try each until one succeeds (matched by `kid` header in the JWT).
  let lastError: unknown
  for (const jwk of keys) {
    try {
      const key = await importJWK(jwk, jwk.alg)
      const { payload } = await jwtVerify(identityToken, key, {
        issuer: 'https://appleid.apple.com',
        audience,
      })
      if (typeof payload.sub !== 'string') throw new Error('Missing sub claim')
      return payload as unknown as AppleClaims
    } catch (err) {
      lastError = err
    }
  }
  throw lastError ?? new Error('Apple token validation failed: no valid key')
}
