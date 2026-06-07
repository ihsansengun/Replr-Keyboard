import type { D1Database, KVNamespace } from '@cloudflare/workers-types'

export type Model =
  | 'gpt-5.4'
  | 'gpt-5.4-mini'
  | 'gpt-5.5'
  | 'claude-sonnet-4-6'
  | 'claude-opus-4-6'
  | 'claude-opus-4-7'
  | 'claude-haiku-4-5'
  | 'grok-4'
  | 'grok-4.3'
  | 'gemini-3.1-pro-preview'
  | 'gemini-3.1-pro-low'
  | 'gemini-3-flash-preview'
  | 'gemini-3.5-flash'
  | 'gemini-3.1-flash-lite'
  | 'gemini-2.5-pro'

export interface Env {
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY: string
  XAI_API_KEY: string
  GOOGLE_API_KEY: string
  FREE_DAILY_LIMIT: string
  RATE_LIMIT_KV: KVNamespace
  DB: D1Database
  SHORTCUT_INSTALL_URL?: string
}

export interface ReplyRequest {
  screenshotBase64?: string
  emailText?: string
  tone: string
  toneName?: string
  summary?: string
  previousContext?: string
  model: Model
  userId: string
}

export interface ReplyResponse {
  replies: string[]
  summary: string
  contactName: string
}

// Auth types
export interface User {
  id: string
  apple_id: string
  email: string | null
  name: string | null
  created_at: number
}

export interface Session {
  token: string
  user_id: string
  expires_at: number
  created_at: number
}

export interface AppleClaims {
  sub: string          // stable Apple user identifier
  email?: string
  email_verified?: boolean | string
  iss?: string
  aud?: string | string[]
  exp?: number
  iat?: number
}
