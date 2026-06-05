# AGENTS.md

`CLAUDE.md` is the primary agent guide for this repo. This file mirrors the
essentials for other AI coding tools (Codex, Cursor, etc.).

## Design system — read before any UI work

**When creating or modifying ANY UI, read and follow `DESIGN.md` first.** It is
the AI-facing design spec — tokens, components, and do's/don'ts, summarizing
`Shared/ReplrTheme.swift`. Never hardcode colors, fonts, radii, or spacing in
views; always use `ReplrTheme.*`. Design and verify both dark and light.

See `CLAUDE.md` for full project guidance: build commands, architecture, and
platform constraints (keyboard extension, App Group, backend).
