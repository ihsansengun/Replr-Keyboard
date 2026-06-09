// @peculiar/x509 pulls in tsyringe, which needs the reflect-metadata polyfill
// loaded before it. Bundled fine by wrangler/esbuild and vitest.
import 'reflect-metadata'
import * as x509 from '@peculiar/x509'
import { compactVerify, decodeProtectedHeader } from 'jose'

/** Apple Root CA - G3 (DER, base64). Downloaded 2026-06-09 from
 *  https://www.apple.com/certificateauthority/AppleRootCA-G3.cer and verified
 *  with openssl (CN "Apple Root CA - G3", valid to 2039-04-30). A StoreKit
 *  transaction JWS must chain to this pinned root to be accepted. */
export const APPLE_ROOT_CA_G3_B64 =
  'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA=='

// Apple PKI marker OIDs. Presence is required (values unused) so that any
// OTHER Apple-rooted certificate (e.g. a developer signing cert) can't pass:
const OID_APPLE_LEAF_RECEIPT_SIGNING = '1.2.840.113635.100.6.11.1'
const OID_APPLE_INTERMEDIATE_WWDR = '1.2.840.113635.100.6.2.1'

/** Decoded StoreKit 2 JWSTransaction payload (the fields we use). */
export interface AppStoreTransactionPayload {
  bundleId?: string
  productId?: string
  transactionId?: string
  originalTransactionId?: string
  type?: string          // e.g. 'Consumable'
  environment?: string   // 'Production' | 'Sandbox' | 'Xcode'
  purchaseDate?: number
}

export interface VerifyOptions {
  /** Trusted root certificates (DER). Defaults to the pinned Apple Root CA - G3.
   *  Overridable so tests can verify against a self-generated chain. */
  trustedRootsDER?: Uint8Array[]
  /** Validation time for certificate windows. Defaults to now. */
  at?: Date
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i]
  return diff === 0
}

/**
 * Verifies a StoreKit 2 transaction JWS (`Transaction.jwsRepresentation`) the
 * same way Apple's app-store-server-library does:
 *   1. the x5c header must carry exactly 3 certificates (leaf, intermediate, root)
 *   2. the root must be byte-identical to a pinned trust anchor
 *   3. intermediate must be signed by root, leaf by intermediate, both within validity
 *   4. leaf + intermediate must carry Apple's marker OIDs
 *   5. the JWS signature must verify against the leaf public key (ES256)
 *
 * Returns the decoded payload. Business checks (bundleId, productId, environment,
 * transactionId dedup) are the caller's responsibility.
 */
export async function verifyTransactionJWS(
  jws: string,
  opts: VerifyOptions = {}
): Promise<AppStoreTransactionPayload> {
  const trustedRoots = opts.trustedRootsDER ?? [b64ToBytes(APPLE_ROOT_CA_G3_B64)]
  const at = opts.at ?? new Date()

  const header = decodeProtectedHeader(jws)
  const x5c = header.x5c
  if (!Array.isArray(x5c) || x5c.length !== 3) {
    throw new Error('JWS must carry a 3-certificate x5c chain')
  }
  const [leaf, intermediate, root] = x5c.map(c => new x509.X509Certificate(b64ToBytes(c)))

  if (!trustedRoots.some(r => bytesEqual(new Uint8Array(root.rawData), r))) {
    throw new Error('Untrusted root certificate')
  }

  if (!(await intermediate.verify({ publicKey: root.publicKey, date: at }))) {
    throw new Error('Intermediate certificate not signed by root (or outside validity)')
  }
  if (!(await leaf.verify({ publicKey: intermediate.publicKey, date: at }))) {
    throw new Error('Leaf certificate not signed by intermediate (or outside validity)')
  }

  if (!leaf.getExtension(OID_APPLE_LEAF_RECEIPT_SIGNING)) {
    throw new Error('Leaf certificate missing the Apple receipt-signing OID')
  }
  if (!intermediate.getExtension(OID_APPLE_INTERMEDIATE_WWDR)) {
    throw new Error('Intermediate certificate missing the Apple WWDR OID')
  }

  const leafKey = await leaf.publicKey.export({ name: 'ECDSA', namedCurve: 'P-256' }, ['verify'])
  const { payload } = await compactVerify(jws, leafKey)
  return JSON.parse(new TextDecoder().decode(payload)) as AppStoreTransactionPayload
}
