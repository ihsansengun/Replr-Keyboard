import { describe, it, expect } from 'vitest'
import { validateAppleToken } from '../src/services/auth'

describe('validateAppleToken', () => {
  it('rejects a malformed token', async () => {
    await expect(validateAppleToken('not-a-jwt', 'com.ihsan.replr')).rejects.toThrow()
  })
})
