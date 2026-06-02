export type Model =
  | 'gpt-5.4'
  | 'gpt-5.4-mini'
  | 'gpt-5.5'
  | 'claude-sonnet-4-6'
  | 'claude-opus-4-6'
  | 'grok-4'
  | 'grok-4.3'

export interface Env {
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY: string
  XAI_API_KEY: string        // xAI (Grok) — get from console.x.ai
  FREE_DAILY_LIMIT: string
  RATE_LIMIT_KV: KVNamespace
}

export interface ReplyRequest {
  screenshotBase64?: string
  emailText?: string
  tone: string
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
