import Foundation

struct Tone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String      // the LLM prompt (not shown to the user)
    var blurb: String            // concise, human-readable line shown in Settings → Tones
    var isPreset: Bool
    var isEnabled: Bool
    /// CUSTOM tones only: which keyboard modes show this tone ("chat"/"dating"/"email").
    /// Picked in the tone builder. Presets ignore it — their availability comes from
    /// the per-mode name sets below.
    var modes: Set<String>

    // Custom decode so old saved tones (missing isEnabled / blurb / modes keys) migrate cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        instruction = try c.decode(String.self, forKey: .instruction)
        blurb       = try c.decodeIfPresent(String.self, forKey: .blurb) ?? ""
        isPreset    = try c.decode(Bool.self,   forKey: .isPreset)
        isEnabled   = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        // Pre-mode custom tones appeared everywhere — keep that on migrate.
        modes       = try c.decodeIfPresent(Set<String>.self, forKey: .modes) ?? ["chat", "dating", "email"]
    }

    init(id: UUID, name: String, instruction: String, blurb: String = "", isPreset: Bool,
         isEnabled: Bool = true, modes: Set<String> = ["chat", "dating", "email"]) {
        self.id          = id
        self.name        = name
        self.instruction = instruction
        self.blurb       = blurb
        self.isPreset    = isPreset
        self.isEnabled   = isEnabled
        self.modes       = modes
    }

    // MARK: - Mode availability

    /// Tone names that can appear in the CHAT keyboard row.
    /// Custom tones (isPreset: false) are always available in both modes.
    static let chatToneNames: Set<String> = [
        "Natural", "Friendly", "Casual", "Chill", "Supportive",
        "Playful", "Witty", "Joker", "Sarcastic", "Gen Z", "Savage",
        "Flirty", "Romantic", "Mysterious", "Seductive",
        "Empathetic", "Thoughtful", "Excited", "Apologetic", "Passive Aggressive",
        "Confident", "Direct", "Firm",
    ]

    /// Tone names that can appear in the EMAIL keyboard row.
    static let emailToneNames: Set<String> = [
        "Warm Professional", "Professional", "Diplomatic", "Assertive",
        "Enthusiastic", "Concise", "Formal",
        // Cross-mode tones also available in email:
        "Confident", "Direct", "Empathetic", "Friendly",
    ]

    /// Whether this tone is available for the chat keyboard row.
    var availableInChat: Bool {
        isPreset ? Tone.chatToneNames.contains(name) : modes.contains("chat")
    }

    /// Whether this tone is available for the email keyboard row.
    var availableInEmail: Bool {
        isPreset ? Tone.emailToneNames.contains(name) : modes.contains("email")
    }

    /// Tone names that can appear in the DATING keyboard row.
    /// 11 dating-specific presets + 4 everyday tones shared from chat.
    static let datingToneNames: Set<String> = [
        "Tease", "Smooth", "Bold", "Banter", "Intrigue", "Challenge",
        "Closer", "Revive", "Recovery", "Slow Burn", "Spice",
        // Shared everyday tones:
        "Natural", "Casual", "Chill", "Confident",
    ]

    /// Names that ONLY exist in dating mode — drives the Settings "Dating" section.
    static let datingOnlyToneNames: Set<String> = datingToneNames.subtracting(chatToneNames)

    /// Whether this tone is available for the dating keyboard row.
    var availableInDating: Bool {
        isPreset ? Tone.datingToneNames.contains(name) : modes.contains("dating")
    }

    // MARK: - Presets (30 tones, all enabled, ordered by category)
    //
    // Category order: Everyday → Playful/Humour → Romance → Emotional → Assertive → Professional
    // This drives both the Settings list and the default keyboard-row order.
    // Users can drag to reorder in Settings → Tones; that order persists and drives the row.

    static let presets: [Tone] = [

        // ── 1. Everyday / Neutral ────────────────────────────────────────────

        Tone(id: UUID(), name: "Natural",
             instruction: "A clean, natural reply — well-written and human, no special personality.",
             blurb: "Clean, well-written replies with no added personality — just reads the room.",
             isPreset: true),

        Tone(id: UUID(), name: "Friendly",
             instruction: "Open with something personal from the chat. Warm but grounded — no exclamation marks after every sentence. Make them feel seen, not managed.",
             blurb: "Warm and personal, without trying too hard.",
             isPreset: true),

        Tone(id: UUID(), name: "Casual",
             instruction: "Text like a close friend. Contractions, fragments, and shorthand are all fine. Match their spelling and punctuation style exactly. Never be more polished than they are.",
             blurb: "Texts like a close friend — relaxed, unpolished, real.",
             isPreset: true),

        Tone(id: UUID(), name: "Chill",
             instruction: "Completely unbothered. Reply like you've got things going on but you're happy to be here. Short, easy, no try. Never sound needy or eager.",
             blurb: "Effortlessly unbothered — no try whatsoever.",
             isPreset: true),

        Tone(id: UUID(), name: "Supportive",
             instruction: "Be the person they needed to hear from right now. Name exactly what they said, then tell them why you believe in them. Specific beats generic every time.",
             blurb: "Their biggest fan — builds them up with something real.",
             isPreset: true),

        // ── 2. Playful / Humour ──────────────────────────────────────────────

        Tone(id: UUID(), name: "Playful",
             instruction: "Be light and a little teasing — the kind of reply that makes them smile without trying too hard. Keep it breezy. A touch of mischief is welcome; don't commit to a full bit. Make the conversation feel effortless and fun to be in.",
             blurb: "Light and a little teasing — makes them smile.",
             isPreset: true),

        Tone(id: UUID(), name: "Witty",
             instruction: "Find the unexpected angle. Understatement over enthusiasm. One dry observation beats three forced jokes. Never explain the wit.",
             blurb: "Dry and clever — finds the unexpected angle.",
             isPreset: true),

        Tone(id: UUID(), name: "Joker",
             instruction: "Find the joke in whatever they said. Puns if they land naturally, absurdist takes, unexpected callbacks — commit to the bit. If there's no obvious angle, make the mundane ridiculous. Never explain the joke.",
             blurb: "Goes for the laugh — puns and playful absurdity.",
             isPreset: true),

        Tone(id: UUID(), name: "Sarcastic",
             instruction: "Deadpan and magnificently condescending. Respond with exaggerated sincerity — the more obvious their point, the more impressed you seem. Celebrate mediocrity as if it's genius. Short, punchy delivery. Never break the facade. Never explain it.",
             blurb: "Deadpan and dryly condescending — straight-faced throughout.",
             isPreset: true),

        Tone(id: UUID(), name: "Gen Z",
             instruction: "Lowercase everything. Use 'no cap', 'lowkey', 'it's giving', 'not me', 'slay' sparingly — only when they'd actually land. Never try too hard. One emoji max, only if it adds something. Vibes over grammar.",
             blurb: "Lowercase, low-effort cool — internet slang, used sparingly.",
             isPreset: true),

        Tone(id: UUID(), name: "Savage",
             instruction: "Light roast energy — say the thing only someone very comfortable with them would say. Short and cutting, never mean-spirited. The tone is the joke; don't explain it.",
             blurb: "Zero filter, playful roast — for close friends only.",
             isPreset: true),

        // ── 3. Romance / Dating ──────────────────────────────────────────────

        Tone(id: UUID(), name: "Flirty",
             instruction: "Show romantic interest without showing all your cards. Slightly unpredictable — don't give them exactly what they expect. Tease without explaining it. One question that shows you were paying attention. Playful tension over obvious enthusiasm.",
             blurb: "Shows romantic interest while keeping a little mystery.",
             isPreset: true),

        Tone(id: UUID(), name: "Romantic",
             instruction: "Tender and affectionate — assume the closeness between you. Reference something specific to them. Make them feel genuinely chosen, not just liked.",
             blurb: "Tender and affectionate — for someone you're close to.",
             isPreset: true),

        Tone(id: UUID(), name: "Mysterious",
             instruction: "Say just enough to make them want more. Leave an obvious question hanging unanswered. Vague isn't cold — make it feel deliberate.",
             blurb: "Just enough to keep them hooked — nothing more.",
             isPreset: true),

        Tone(id: UUID(), name: "Seductive",
             instruction: "Suggestive and explicitly sensual. Take whatever they said and turn the heat up. Bold, specific, no euphemisms. Make the reply impossible to ignore.",
             blurb: "Suggestive and sensual — turns up the heat.",
             isPreset: true),

        // ── 4. Emotional / Intentional ───────────────────────────────────────

        Tone(id: UUID(), name: "Empathetic",
             instruction: "Acknowledge what they're feeling before addressing content. Reflect their emotion back in your own words first. Don't jump to solutions.",
             blurb: "Warm and understanding — leads with how they feel.",
             isPreset: true),

        Tone(id: UUID(), name: "Thoughtful",
             instruction: "Slow down and give it weight. Notice something subtle in what they said that others might gloss over. Respond to the feeling underneath, not just the surface.",
             blurb: "Takes it seriously — reads what's under the surface.",
             isPreset: true),

        Tone(id: UUID(), name: "Excited",
             instruction: "Let the enthusiasm out — don't hold it back. Match their energy and add yours. One punchy sentence of genuine excitement lands better than three measured ones.",
             blurb: "Full-on enthusiasm — can't contain it.",
             isPreset: true),

        Tone(id: UUID(), name: "Apologetic",
             instruction: "A real apology — not a hedge, not an excuse with 'sorry' attached. Name the specific thing you did. Own it without deflecting. Keep it short and clean.",
             blurb: "A proper apology — no hedging, no excuses.",
             isPreset: true),

        Tone(id: UUID(), name: "Passive Aggressive",
             instruction: "Agree with everything but make it slightly sting. Use 'no worries' and 'totally fine' liberally. End with something that sounds supportive but clearly isn't. Never be openly rude — the vibe does the work.",
             blurb: "Agreeable on the surface, with a little sting underneath.",
             isPreset: true),

        // ── 5. Assertive / Direct ────────────────────────────────────────────

        Tone(id: UUID(), name: "Confident",
             instruction: "Reply from a place of self-assurance — like someone who has options but finds this conversation worth their time. Don't over-explain or qualify. Grounded and brief beats long and eager. Leave them a little curious, not fully satisfied.",
             blurb: "Self-assured and unbothered — never over-eager.",
             isPreset: true),

        Tone(id: UUID(), name: "Direct",
             instruction: "Lead with the answer. One sentence when possible, two at most. Cut the closing line — it's usually filler.",
             blurb: "Straight to the point. No filler.",
             isPreset: true),

        Tone(id: UUID(), name: "Firm",
             instruction: "A calm, clean no or limit. Acknowledge the ask once. Decline without over-explaining. Don't soften it into ambiguity — end it clearly.",
             blurb: "Clear boundary, no drama — firm but not cold.",
             isPreset: true),

        // ── 6. Professional / Email ──────────────────────────────────────────

        Tone(id: UUID(), name: "Warm Professional",
             instruction: "Write like a trusted colleague, not a corporate auto-reply. Professional structure — clear point, brief support — but with genuine warmth. Make them feel like a person, not a ticket number. Close with something specific to the situation.",
             blurb: "Polished but personable — a trusted colleague, not a corporate reply.",
             isPreset: true),

        Tone(id: UUID(), name: "Professional",
             instruction: "No contractions. State your point first, support it second. Close with a clear next step. No idioms or slang.",
             blurb: "Clear and businesslike — structured and to the point.",
             isPreset: true),

        Tone(id: UUID(), name: "Diplomatic",
             instruction: "Acknowledge their position before presenting yours. Never dismiss the concern, even if you disagree. Find common ground first, then navigate toward your point. Preserve the relationship while holding your position. End on something constructive.",
             blurb: "Tactful — pushes back or declines without burning bridges.",
             isPreset: true),

        Tone(id: UUID(), name: "Assertive",
             instruction: "State your position clearly and without apology. No hedging, no excessive qualifiers. Explain your reasoning briefly — once. Don't over-justify. Firm but not aggressive. End with a clear next step or expectation.",
             blurb: "Firm and clear about your position — without aggression.",
             isPreset: true),

        Tone(id: UUID(), name: "Enthusiastic",
             instruction: "Match and slightly amplify their energy. Lead with what genuinely excites you about what they said. One well-placed exclamation mark, not three.",
             blurb: "Upbeat and energetic — matches their excitement.",
             isPreset: true),

        Tone(id: UUID(), name: "Concise",
             instruction: "Two sentences maximum. If you've written three, delete one. Every word must earn its place.",
             blurb: "Short and sharp — every word earns its place.",
             isPreset: true),

        Tone(id: UUID(), name: "Formal",
             instruction: "Full words only — no contractions or abbreviations. State your purpose in the first sentence. Complete sentences, clean close.",
             blurb: "No contractions, complete sentences — buttoned-up and correct.",
             isPreset: true),

        // ── 7. Dating mode (hidden from chat/email — see datingToneNames) ───
        // Style tones: how you sound. Scenario tones: the moments that happen.
        // Backend pairs each name with temperature + examples in TONE_LIBRARY.

        Tone(id: UUID(), name: "Tease",
             instruction: "Playful challenge and push-pull. Find the one detail in their profile or messages that's gently mockable and build the bit around it. Mock-accuse, never insult. Compliments arrive disguised as complaints. End somewhere they have to defend themselves — playfully.",
             blurb: "Playful push-pull — turns their profile into a bit.",
             isPreset: true),

        Tone(id: UUID(), name: "Smooth",
             instruction: "Charm that looks effortless. Compliments must be specific and earned from their profile — never about generic beauty. Interest should read as good taste, not eagerness. Unhurried sentences; let one line do the work of three.",
             blurb: "Effortless charm — compliments with craft.",
             isPreset: true),

        Tone(id: UUID(), name: "Bold",
             instruction: "Direct intent. Say what you want — the match, the drink, the date — without hedging or apology. Concrete plans beat abstract interest: name a day and a place when the conversation allows. Short. Confidence is the content.",
             blurb: "States intent, makes the plan.",
             isPreset: true),

        Tone(id: UUID(), name: "Banter",
             instruction: "Go for the laugh, anchored to THEIR specifics — their photos, bio lines, contradictions. Absurd scenarios, rankings, mock-petitions, callbacks. Commit fully to the bit. If the joke could be sent to anyone, start over.",
             blurb: "Committed humor built on their details.",
             isPreset: true),

        Tone(id: UUID(), name: "Intrigue",
             instruction: "Curiosity gaps. Refer to a thought you don't finish, an observation you withhold, a theory about them you won't explain yet. Shorter than expected. They should have to ask. Deliberate, never cold.",
             blurb: "Says less — opens loops they must close.",
             isPreset: true),

        Tone(id: UUID(), name: "Challenge",
             instruction: "Qualification energy: playful skepticism about compatibility — make them earn the next step. Challenge the claims in their profile. High standards worn lightly. Challenge the situation or the claim, never their worth or looks.",
             blurb: "Flips the frame — they convince you.",
             isPreset: true),

        Tone(id: UUID(), name: "Closer",
             instruction: "The close. Assume the yes; propose a concrete time and place drawn from the conversation or their profile. Move off-app naturally. One clean ask — no double-asking, no 'maybe sometime'.",
             blurb: "Locks in the number or the date.",
             isPreset: true),

        Tone(id: UUID(), name: "Revive",
             instruction: "The conversation died — restart it with zero guilt and zero reference to the silence being anyone's fault. Call back to an earlier thread or open a fresh specific angle. Make replying effortless. Never 'hey stranger', never ask why they vanished.",
             blurb: "Resurrects a dead conversation.",
             isPreset: true),

        Tone(id: UUID(), name: "Recovery",
             instruction: "Your last message didn't land or got left on read. Reset with self-aware humor — acknowledge lightly, never grovel or over-apologize. Pivot to a new specific topic. Unbothered is the whole game.",
             blurb: "Left on read? Reset the frame, unbothered.",
             isPreset: true),

        Tone(id: UUID(), name: "Slow Burn",
             instruction: "For matches worth investing in. Trade one layer of banter for one layer of genuine curiosity about their life. Specific questions over flirty volleys — but keep one ember of spark so it never reads platonic. Patience as confidence.",
             blurb: "The long game — depth with a spark.",
             isPreset: true),

        Tone(id: UUID(), name: "Spice",
             instruction: "Escalation when the energy is already mutual. Forward and suggestive — tension over explicitness; say less, imply more. Read the room hard: if their energy is not clearly matching, dial back to charm. Never crude openers to a cold profile.",
             blurb: "Turns up the heat — for mutual energy.",
             isPreset: true),
    ]
}
