# PHISH!

> *Spot the scam. Save the sea.*

A cozy Roblox fishing world where players reel in suspicious messages instead of fish — and learn to outsmart scams by **doing**, not memorizing. Built in 36 hours for the **Roblox Civility Challenge** at LAHacks.

## Inspiration

Cybersecurity training for kids usually feels like a lecture. PHISH! flips that: scam detection becomes a game you *want* to play. Learning lives inside the verb — verifying before reeling **is** fact-checking; cutting bait **is** refusing a phishing lure.

## Core Loop

**Cast → Reel → Inspect → Keep or Cut Bait → Earn → Repeat**

1. **Cast** into the digital sea
2. **Reel** in a message-fish
3. **Inspect** sender, links, and language
4. **Decide:** Keep (legit) or Cut Bait (phish)
5. **Earn** coins + XP, unlock **PhishDex** entries, upgrade gear

## Progression

- Better rods unlock deeper, riskier zones with harder-to-spot scams
- Harder catches pay more coins and XP
- Level up to unlock cosmetics (boat skins, etc.)
- Tycoon-style auto-catchers for passive income
- One-time consumable boosts for catch quality and sell value

## Why It Fits the Civility Challenge

- **Civility & Life Skills** — rewards media literacy and scam-spotting
- **Digital Literacy** — gamifies phishing defense and AI-lie detection
- **Real-World Impact** — kids build pattern recognition that transfers off-platform
- **Storyboarding** — safety lessons are woven into the questline (Field Guide entries as angler's-journal lore), not popup quizzes

> *Learning Retention ∝ Playful Repetition × Immediate Feedback*

## How We Built It

- **Engine:** Roblox + Luau
- **Architecture:** server-authoritative validation (anti-cheat, fairness)
- **Workflow:** Rojo + Git for fast team iteration
- **Systems:** fishing loop, inspection UI, economy/progression, PhishDex collection, onboarding, polished 3D/UI card rendering

## Project Layout

```
src/                  Lua source (Rojo-synced)
  ReplicatedStorage/    Shared modules, RemoteService
  ServerScriptService/  Authoritative services
  StarterPlayerScripts/ Client controllers, UI
docs/                 PRD, content catalog, core loop
tasks/                todo.md, lessons.md
```

## Build & Run

```bash
rojo serve default.project.json           # live sync to Studio
rojo build default.project.json -o build.rbxl
selene src/                                # lint
```

Tools pinned via [`aftman.toml`](aftman.toml): Rojo 7.7.0-rc.1, Selene 0.27.1.

## Engineering Rules

- **Server authority** for fish spawn, catch validation, XP, journal grants
- **All remotes through `RemoteService.lua`** with validation + rate limiting
- **No Lua file over 500 lines**
- See [`CLAUDE.md`](CLAUDE.md) for full conventions

## Challenges

- Pivoted from a completely different game with 10 hours left
- Balancing education vs. entertainment so it never felt preachy

## What's Next

- New zones and scam species (DMs, smishing, deepfakes)
- Co-op/social features and live events
- Classroom pilots with measurable outcomes

## Key Docs

- [`docs/PHISH_PRD.md`](docs/PHISH_PRD.md) — canonical design
- [`docs/PHISH_CONTENT.md`](docs/PHISH_CONTENT.md) — fish catalog
- [`docs/PHISH_MVP_PLAN.md`](docs/PHISH_MVP_PLAN.md) — hackathon scope
- [`tasks/todo.md`](tasks/todo.md) — implementation checklist
