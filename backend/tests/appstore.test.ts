import { describe, it, expect } from 'vitest'
import 'reflect-metadata'
import * as x509 from '@peculiar/x509'
import { CompactSign } from 'jose'
import { verifyTransactionJWS } from '../src/services/appstore'

const ALG = { name: 'ECDSA', namedCurve: 'P-256', hash: 'SHA-256' } as const

const OID_LEAF = '1.2.840.113635.100.6.11.1'
const OID_INTERMEDIATE = '1.2.840.113635.100.6.2.1'
const DER_NULL = new Uint8Array([0x05, 0x00]).buffer

interface Chain {
  root: x509.X509Certificate
  intermediate: x509.X509Certificate
  leaf: x509.X509Certificate
  leafKeys: CryptoKeyPair
}

/** Self-signed root → intermediate → leaf, mirroring Apple's StoreKit chain shape
 *  (including the Apple marker OIDs, unless disabled per-cert). */
async function makeChain(opts: {
  leafOID?: boolean
  intermediateOID?: boolean
  leafValidity?: { notBefore: Date; notAfter: Date }
} = {}): Promise<Chain> {
  // ECDSA generateKey always returns a key pair; TS's lib type is a union.
  const rootKeys = await crypto.subtle.generateKey(ALG, true, ['sign', 'verify']) as CryptoKeyPair
  const intKeys = await crypto.subtle.generateKey(ALG, true, ['sign', 'verify']) as CryptoKeyPair
  const leafKeys = await crypto.subtle.generateKey(ALG, true, ['sign', 'verify']) as CryptoKeyPair
  const notBefore = new Date(Date.now() - 86400_000)
  const notAfter = new Date(Date.now() + 86400_000)

  const root = await x509.X509CertificateGenerator.create({
    serialNumber: '01',
    subject: 'CN=Test Root',
    issuer: 'CN=Test Root',
    notBefore, notAfter,
    signingKey: rootKeys.privateKey,
    publicKey: rootKeys.publicKey,
    signingAlgorithm: ALG,
    extensions: [new x509.BasicConstraintsExtension(true, undefined, true)],
  })

  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: '02',
    subject: 'CN=Test Intermediate',
    issuer: 'CN=Test Root',
    notBefore, notAfter,
    signingKey: rootKeys.privateKey,
    publicKey: intKeys.publicKey,
    signingAlgorithm: ALG,
    extensions: [
      new x509.BasicConstraintsExtension(true, undefined, true),
      ...(opts.intermediateOID === false ? [] : [new x509.Extension(OID_INTERMEDIATE, false, DER_NULL)]),
    ],
  })

  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: '03',
    subject: 'CN=Test Leaf',
    issuer: 'CN=Test Intermediate',
    notBefore: opts.leafValidity?.notBefore ?? notBefore,
    notAfter: opts.leafValidity?.notAfter ?? notAfter,
    signingKey: intKeys.privateKey,
    publicKey: leafKeys.publicKey,
    signingAlgorithm: ALG,
    extensions: [
      ...(opts.leafOID === false ? [] : [new x509.Extension(OID_LEAF, false, DER_NULL)]),
    ],
  })

  return { root, intermediate, leaf, leafKeys }
}

function certB64(c: x509.X509Certificate): string {
  return Buffer.from(c.rawData).toString('base64')
}

function rootsOf(chain: Chain): Uint8Array[] {
  return [new Uint8Array(chain.root.rawData)]
}

const PAYLOAD = {
  bundleId: 'Theory-of-Web.Replr',
  productId: 'com.ihsan.replr.credits.300',
  transactionId: 'tx-12345',
  originalTransactionId: 'tx-12345',
  type: 'Consumable',
  environment: 'Production',
}

async function signJWS(chain: Chain, payload: object = PAYLOAD): Promise<string> {
  return await new CompactSign(new TextEncoder().encode(JSON.stringify(payload)))
    .setProtectedHeader({
      alg: 'ES256',
      x5c: [certB64(chain.leaf), certB64(chain.intermediate), certB64(chain.root)],
    })
    .sign(chain.leafKeys.privateKey)
}

describe('verifyTransactionJWS', () => {
  it('accepts a valid chain and returns the payload', async () => {
    const chain = await makeChain()
    const jws = await signJWS(chain)
    const payload = await verifyTransactionJWS(jws, { trustedRootsDER: rootsOf(chain) })
    expect(payload.bundleId).toBe('Theory-of-Web.Replr')
    expect(payload.productId).toBe('com.ihsan.replr.credits.300')
    expect(payload.transactionId).toBe('tx-12345')
    expect(payload.environment).toBe('Production')
  })

  it('rejects a chain not anchored at a trusted root', async () => {
    const chain = await makeChain()
    const otherChain = await makeChain()
    const jws = await signJWS(chain)
    await expect(verifyTransactionJWS(jws, { trustedRootsDER: rootsOf(otherChain) }))
      .rejects.toThrow(/untrusted root/i)
  })

  it('rejects a leaf missing the Apple receipt-signing OID', async () => {
    const chain = await makeChain({ leafOID: false })
    const jws = await signJWS(chain)
    await expect(verifyTransactionJWS(jws, { trustedRootsDER: rootsOf(chain) }))
      .rejects.toThrow(/receipt-signing/i)
  })

  it('rejects an intermediate missing the Apple WWDR OID', async () => {
    const chain = await makeChain({ intermediateOID: false })
    const jws = await signJWS(chain)
    await expect(verifyTransactionJWS(jws, { trustedRootsDER: rootsOf(chain) }))
      .rejects.toThrow(/wwdr/i)
  })

  it('rejects an expired leaf certificate', async () => {
    const chain = await makeChain({
      leafValidity: {
        notBefore: new Date(Date.now() - 2 * 86400_000),
        notAfter: new Date(Date.now() - 86400_000),
      },
    })
    const jws = await signJWS(chain)
    await expect(verifyTransactionJWS(jws, { trustedRootsDER: rootsOf(chain) }))
      .rejects.toThrow(/leaf/i)
  })

  it('rejects a tampered payload', async () => {
    const chain = await makeChain()
    const jws = await signJWS(chain)
    const [h, p, s] = jws.split('.')
    // Re-encode a modified payload, keep the original signature.
    const forged = Buffer.from(JSON.stringify({ ...PAYLOAD, productId: 'com.ihsan.replr.credits.2500' }))
      .toString('base64url')
    await expect(verifyTransactionJWS([h, forged, s].join('.'), { trustedRootsDER: rootsOf(chain) }))
      .rejects.toThrow()
  })

  it('rejects a JWS without a 3-certificate chain', async () => {
    const chain = await makeChain()
    const jws = await new CompactSign(new TextEncoder().encode(JSON.stringify(PAYLOAD)))
      .setProtectedHeader({ alg: 'ES256', x5c: [certB64(chain.leaf), certB64(chain.intermediate)] })
      .sign(chain.leafKeys.privateKey)
    await expect(verifyTransactionJWS(jws, { trustedRootsDER: rootsOf(chain) }))
      .rejects.toThrow(/x5c/i)
  })
})
