# Lessons

This file tracks corrections and patterns to avoid repeating.

## Current Rules

- Do not make the game feel like a quiz. No popup lessons.
- Do not add long educational text. The Guide manual is the only place rules live, and it's framed as gameplay reference.
- Every lesson must also be a fun mechanic.
- Explorer and Guide must have different information.
- Guide must have meaningful actions (manual + annotations), not just passive reading.
- Keep scope small for hackathon: **2 polished levels**, not many shallow ones. The judges asked for depth, not breadth.
- The two MVP levels are **Stranger Danger Park** and **Backpack Checkpoint**. Anything else is post-MVP.
- The role names are **Explorer** (action) and **Guide** (knowledge). Do not use "Runner" — old docs may have it; treat any remaining occurrence as a typo and update.
- Keep files under 500 lines.
- Parameterize reusable functions instead of hardcoding one-off behavior.
- Avoid hardcoded level-specific hacks in generic systems.
- Server owns gameplay truth.
- Client is display and input only.
- If a module sets up state or listeners, make sure bootstrap requires it.
- Every folder under `src/` must have an `init.meta.json` with `{ "ignoreUnknownInstances": true }` or Rojo will wipe Studio-built map content on sync.

## Pivots Logged

### 2026-04-24: educational framing flipped from hidden to explicit

After a follow-up with the judges, we reframed from "hide the learning" to "lean into the educational angle, target Roblox's Learn and Explore sort". Cut from 3 rooms to 2 polished levels. Renamed the runner role to Explorer. New levels: Stranger Danger Park and Backpack Checkpoint.

### 2026-04-25: doc drift between user1_map_prompt and TECHNICAL_DESIGN.md

While implementing M4 (Stranger Danger Park) we found the following items in `prompts/user1_map_prompt.md` that aren't yet documented in `docs/TECHNICAL_DESIGN.md` "Map Object Conventions". Treat User 1's prompt as authoritative for map data shape and update TECHNICAL_DESIGN.md when convenient:

- **`Anchor` attribute on `BuddyNpcSpawn`** — the scenario service biases NPC role assignment by anchor (`WhiteVan` → risky, `HotdogStand` → safe, etc.). See `Modules/NpcRegistry.lua` `AnchorBias` and `AnchorRequiredTraits`.
- **`PuppySpawn` tag** — used by `StrangerDangerScenario` to pick the puppy location.
- **`BeltStart` / `BeltEnd` tags** (not just attributes) — read by `BackpackCheckpointLevel`.
- **Knife accessory** — risky NPCs at the alley anchor get a kid-friendly cartoon knife server-attached at clone time; the rig itself stays unarmed. See `Levels/StrangerDangerLevel.lua` `attachKnifeAccessory`.

Apply: when building a new level template in Studio, use the tag names listed in `Modules/PlayAreaConfig.Tags` and the attribute names in `Modules/PlayAreaConfig.Attributes` — those are the single source of truth for the script side.

### 2026-04-24: judge specifics nailed down (Jenine + Andrew)

Two more judge conversations confirmed validation and tightened framing:

- **Boss-pitch test:** the Roblox judge needs to be able to repeat the game in one sentence to her boss. Headline pitch is now: *"Buddy Bridge is a 2-player co-op where the grownup has the safety rulebook and the kid has the actions — they have to talk to win, which is exactly the habit kids should build for the real internet."* If a feature can't be defended by that sentence, cut it.
- **Stranger Danger archetypes are explicit, not abstract.** Use the white van, the person with a knife, and the stranger asking your name as concrete NPC scenes — judges (Andrew) named these directly.
- **Visual consistency is mandatory.** One palette, one prop language, one font, one NPC style, one item style, one UI feel across the whole game. No franken-game.
- **Reference comp:** *Ecos La Brea* on Roblox — educational MMO that doesn't break its world. Aim there.

Apply: when reviewing any new feature or asset, run it past the boss-pitch sentence and the visual style bible (`prompts/user1_map_prompt.md`).
