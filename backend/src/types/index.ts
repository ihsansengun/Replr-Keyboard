export type Model = 'claude' | 'gpt4o'
export type Tier = 'free' | 'premium'

export interface Env {
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY: string
  FREE_DAILY_LIMIT: string
  RATE_LIMIT_KV: KVNamespace
}

export interface ReplyRequest {
  screenshotBase64?: string
  emailText?: string
  tone: string
  summary?: string
  model: Model
  userId: string
  transactionId?: string
}

export interface ReplyResponse {
  replies: string[]
}
