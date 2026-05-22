# AGENTS.md

> **Single source of truth: [CLAUDE.md](CLAUDE.md) in the repo root.**
>
> This project keeps one operating guide so the rules can't drift across tools.
> Any agent (Codex, Claude, etc.) should read `CLAUDE.md` before working here.
> It covers:
>
> - Build / analyze / lint / test / run commands and the `./scripts/ui_check.sh` one-shot check
> - Architecture overview (Provider wiring, the MQTT ViewModel → Controller → manager/scheduler core, UI layering, Lab design system)
> - State-management, i18n (ARB), and the three-layer UI design-system conventions (lint + golden + smoke)
> - The change→test mapping and preferred UI migration order
> - Business boundaries that must not be touched in UI-only work
> - Chinese emoji Conventional Commit style and the release flow

This file is intentionally thin — do not duplicate rules here.
