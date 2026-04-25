# Backpack Checkpoint PRDs — Pick Your Path

Three PRDs for the second polished MVP level. Pick one (or hybridize).

All three share the same anchors:
- 2-player asymmetric co-op
- Privacy + phishing taught together
- "Active Scanner" Guide with Scan / Highlight / Lane-Lock / Veto tools
- Server authority, `RemoteService`-routed remotes, `PlayAreaService` slot lifecycle (per `CLAUDE.md`)
- Cohesive art style, `Enum.Font.Cartoon`, no lectures
- Boss-test sentence drives every feature decision

What differs is **scope, ambition, risk, and the kind of demo it produces**.

---

## V1 — The Polished Conveyor

> Backpack Checkpoint is a 2-player TSA-for-the-internet co-op where the kid sorts items at the conveyor and the grownup runs the X-ray scanner — they have to talk to figure out what's safe to share and what's a scam.

- **What it is:** the original TSA conveyor, polished with combos, escalating waves, a Mini-Boss bag, and a redesigned Active Scanner Guide.
- **Build cost:** lowest of the three. ~3 days of work, half on the registry content.
- **Demo feeling:** tight, mechanical, "this would ship today."
- **Strongest on rubric:** Progress & Development.
- **Best for:** thin art bandwidth, tight schedule, betting on execution over vision.
- **Risk:** can read as a minigame rather than a level if the Pixel Post wrapper isn't sold hard.
- **File:** [`BACKPACK_CHECKPOINT_PRD_V1_POLISHED.md`](BACKPACK_CHECKPOINT_PRD_V1_POLISHED.md)

## V2 — Pixel Port Terminal (Airport World)

> Pixel Port is a 2-player co-op where the kid is a junior officer running passengers through an internet airport, and the grownup is in the control tower with the safety scanner — together they decide what gets shared, what gets blocked, and what's a scam in disguise.

- **What it is:** a small explorable airport hub with 4 stations (ID Counter, Baggage Belt, Customs, Boarding Gate), traveler NPCs with cross-station arcs, and a multi-camera Guide tower.
- **Build cost:** highest of the three. Aggressive for 36 hours; achievable with strict station scoping.
- **Demo feeling:** "this feels like a real place" — the Ecos La Brea benchmark the judges named.
- **Strongest on rubric:** Storyboarding & Message Quality, Learn-and-Explore eligibility.
- **Best for:** team with set-dressing capability, betting on wow-factor.
- **Risk:** half-built airport reads worse than polished single belt. Strict cut line: 2 stations + tower as floor.
- **File:** [`BACKPACK_CHECKPOINT_PRD_V2_AIRPORT_WORLD.md`](BACKPACK_CHECKPOINT_PRD_V2_AIRPORT_WORLD.md)

## V3 — Trust Garden (Reinvented)

> Trust Garden is a 2-player co-op where the kid plants seeds (things about themselves) into different garden plots (private vs. shared) and pulls weeds (scam attempts) — the grownup has the magic monocle that reveals which seeds are safe to plant where, and which "gifts from strangers" are actually weeds in disguise.

- **What it is:** a cozy gardening level. Three plots = three privacy scopes. Seeds = personal info. Weeds = phishing. The garden's appearance *is* the score.
- **Build cost:** comparable to V1 in code, more in art polish. Heavy reliance on cohesive visual feel.
- **Demo feeling:** "wait, is this the same hackathon?" — directly evokes Grow a Garden, the parent-child Roblox lane judges keep referencing.
- **Strongest on rubric:** Potential Impact (the X-Factor column).
- **Best for:** team with art / set-dressing capability that wants the boldest creative bet.
- **Risk:** the metaphor must land. Cozy must not become boring. Garden polish carries the level.
- **File:** [`BACKPACK_CHECKPOINT_PRD_V3_REINVENTED.md`](BACKPACK_CHECKPOINT_PRD_V3_REINVENTED.md)

---

## Side-by-Side

| Axis | V1 Polished | V2 Airport World | V3 Trust Garden |
|---|---|---|---|
| Build cost (eng) | Low | High | Mid |
| Build cost (art) | Low | High | Mid–High |
| World depth | Single room | 4 stations | One cohesive garden |
| Narrative | Light wrapper | Cross-station arcs | Mechanic = story |
| Asymmetric clarity | Strong | Strong | Strongest |
| "Boss test" punch | Strong | Strong | Strongest |
| Replayability | High (content rotation) | High (NPC arcs + content) | High (content + cozy retention) |
| Demo wow | Mechanical polish | Place / world | Vibe / novelty |
| Rubric: Progress & Dev | ★★★ | ★★★★ | ★★★ |
| Rubric: Storyboarding | ★★ | ★★★★ | ★★★★ |
| Rubric: Potential Impact | ★★★ | ★★★★ | ★★★★★ |
| Cuttable to demo floor | Easy | Hard | Mid |

---

## How to Pick

Ask three questions in order:

1. **Does the team have any meaningful art / set-dressing capacity?** If no → V1. If yes, continue.
2. **Is the team comfortable abandoning the current TSA mental model?** If no → V2. If yes, continue.
3. **Is the team confident they can make a single small space *look beautiful* in 36 hours?** If yes → V3. If no → V2.

Default for "we don't know yet" is **V1** with V2 as the upgrade path if execution moves faster than expected. V3 is the bold bet that needs explicit team agreement to chase.

---

## Hybridization Notes

These PRDs are not mutually exclusive. Worth considering:

- **V1 + V3 lobby tie-in:** ship V1 as the level, but make the lobby treehouse into a Trust Garden that grows from V1's seeds. Captures cozy without requiring a second level.
- **V2 + V3 station swap:** ship V2 with three stations (ID Counter + Belt + Customs) and replace Boarding Gate with a small Garden corner that closes the round. Cozy outro, less build cost.
- **All three share the registry:** if any version ships, the `ItemRegistry` content (privacy + phishing items) carries over verbatim. Content is not version-locked.

---

## Cross-References

These PRDs sit alongside the existing game-wide docs and inherit their rules:

- [`PRD.md`](PRD.md) — game-wide product requirements
- [`GAME_DESIGN.md`](GAME_DESIGN.md) — gameplay design
- [`TECHNICAL_DESIGN.md`](TECHNICAL_DESIGN.md) — architecture
- [`MVP_SCOPE.md`](MVP_SCOPE.md) — hackathon scope
- [`JUDGING_STRATEGY.md`](JUDGING_STRATEGY.md) — pitch framing

If the team picks one of these PRDs, the picked version supersedes the existing Backpack Checkpoint section in `GAME_DESIGN.md` and `PRD.md`. Update those docs to point here.
