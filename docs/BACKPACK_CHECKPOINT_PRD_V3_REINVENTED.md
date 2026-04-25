# Backpack Checkpoint — PRD V3: The Trust Garden

> **Evolution path:** Treat "Backpack Checkpoint" as a metaphor we've outgrown. Replace the TSA framing with a cozy gardening-and-greenhouse mechanic that teaches the same privacy + phishing lessons more naturally and lands directly in the "Grow a Garden" parent-child Roblox lane the judges keep referencing.

This is the **highest-X-factor, highest-narrative-novelty** version of the three. It bets that a cozy mechanic teaches digital citizenship better than a security mechanic, because cozy is what kids actually return to.

---

## One-Line Pitch (Boss Test)

> Trust Garden is a 2-player co-op where the kid plants seeds (things about themselves) into different garden plots (private vs. shared) and pulls weeds (scam attempts) — the grownup has the magic monocle that reveals which seeds are safe to plant where, and which "gifts from strangers" are actually weeds in disguise.

That sentence has to survive every feature decision. If a feature can't be defended by it, cut it.

---

## Why This Version

**Pros**
- Most original mechanic of the three. Judges have not seen this before.
- Sits naturally next to **Grow a Garden** — the exact reference the judges spontaneously raised. We are not chasing a trend; we are reframing a safety lesson in a vocabulary kids already love.
- The plant / garden metaphor *teaches by analogy*: planting a seed in the wrong plot shows that information, once shared, *grows there*. Pulling a weed shows that some "gifts" actively harm you.
- "Cozy" is the word judges used. This level is cozy.
- Trust Seeds (already in the game's economy) are now literal seeds in this level. The mechanic and the meta-progression are the same noun. That's design economy.

**Cons**
- Furthest from the existing concept on disk. Highest "throw away what we already designed" cost.
- Mechanic is novel, which means it will take longer to converge on what's fun. Less reference material.
- The metaphor needs to land cleanly — if a kid doesn't understand "the seed represents you sharing your name," the whole thing collapses into pretty visuals.

**Mitigations:** the tutorial garden plot makes the metaphor explicit in 30 seconds. The Guide's monocle prompts make the "this seed represents X" reading unmissable. And the seed/weed visual language is overstated on purpose — privacy seeds glow, weed seeds wriggle.

---

## Educational Anchor: Privacy AND Phishing as Seeds and Weeds

The metaphor does double duty cleanly:

- **Outgoing → Seeds.** The Explorer is given seeds that represent things about *them*: their name, their school, their birthday, their favorite game, their address. They choose where in the garden to plant each seed. Garden plots are visibility scopes.
- **Incoming → Weeds.** Strangers (NPCs walking past the fence) toss "gifts" into the garden — wrapped boxes, strange seeds, mystery envelopes. Most of these are **weeds in disguise**. The Explorer must pull the bad ones out before they take root and choke the garden.

Privacy is *what to plant*. Phishing is *what to uproot*. Same garden. Same gardener. One coherent fantasy.

---

## The World: Trust Garden

A small, gorgeous, palette-coordinated outdoor garden. Mid-day light. Friendly birdsong loop. A picket fence around the perimeter (so strangers can drop "gifts" over it but never walk in).

### Garden plots (the bins, reframed)

Three plots laid out in the garden. Same three educational lanes from the existing PRD, but expressed as places that **grow**:

1. **Heart Plot (private)** — a small enclosed plot near a cottage door. Things planted here only the Explorer and Guide can see. Replaces "Leave It" — but with a positive framing: this isn't a trash can, it's a treasured garden behind your house.
2. **Friendship Plot (ask first)** — a mid-sized plot with a low fence. Things planted here are visible to "friends and family" — represented in-game by a rotating cast of named, friendly NPC neighbors who occasionally stroll by and admire them.
3. **Town Square Plot (public)** — a big plot connected to the town path. Anything planted here is visible to everyone who walks by. This plot has the most visual reward when used correctly (flowers bloom big and bright) and the most consequence when misused (planting an "address seed" here makes a literal house-shaped flower visible from the street).

The visual logic teaches the lesson: when you put something in the public plot, the whole town sees it. **The metaphor is the lesson.** No popup needed.

### Garden inhabitants

- **The Explorer's avatar** roams freely within the garden.
- **The Guide** is in the **Greenhouse** — a glass building at the edge of the garden, instanced privately to the duo. They look out through windows and through their **Monocle UI**.
- **Friendly Town Neighbors** (NPCs) walk past the fence on a path. They occasionally admire correct plantings.
- **Sketchy Strangers** (NPCs) walk past too — they toss "gifts" over the fence at scripted intervals. These are the weed events.

---

## Core Loop

A round is a **single tended-garden session**, ~4–6 minutes long. Two interleaved activities run simultaneously:

### Activity A — Planting Seeds (privacy)

1. A **seed packet** drops into the Explorer's basket. The packet has a label visible to both players (e.g., "Your Real Name," "Your School Crest," "Your Birthday Cake," "Your Favorite Color").
2. The Explorer carries the seed packet to one of the three plots.
3. The Guide consults the **Field Guide** (their manual) and tells the Explorer which plot each seed belongs in.
4. Plant. The seed sprouts. If it's the right plot, it blooms beautifully (privacy lesson reinforced visually). If it's the wrong plot, the bloom is *visible* in the wrong place — and the Explorer has to **dig it up** to fix. Mistake counter +1.

There are 6–8 seed packets per round.

### Activity B — Pulling Weeds (phishing)

1. At scripted intervals (~every 45 seconds), a **stranger** ambles up to the fence and tosses something into the garden — a wrapped gift, a glowing seed, a balloon, a "free Robux pebble," a chat-bubble bouquet.
2. The Guide's **Monocle scan** can identify whether the gift is a weed or a real friendly gift (occasionally a real friendly thing comes from a verified neighbor — see "Why not all gifts are weeds" below).
3. If it's a weed, the Explorer has ~15 seconds to **uproot it** before it takes root. If it takes root, it spreads — choking nearby plants, costing combo, dimming the garden.
4. If it's a real gift from a verified neighbor, planting / accepting it gives a small bonus.

There are 3–5 weed events per round.

The two activities **share the Explorer's attention** — that's where the difficulty comes from. The Guide must triage: "There's a seed in your basket and a weed at the fence — pull the weed first, the seed can wait."

That triage moment is *exactly* the cognitive habit we want kids to practice online: not all incoming things are gifts, not all sharing is urgent, your grownup helps you sort priority.

### Why not all gifts are weeds

This is the most important nuance in the level. The internet is not "everyone is a scammer." It's "most things are fine, some things are weeds." The Guide must read the gift carefully — a wrapped box from "Aunt Rina, the verified neighbor" is a real gift. A wrapped box from "FreeRobux99" is a weed.

Teaching kids that the world is mostly safe **but you check** is the actual lesson, and it's the lesson V1 and V2 only partly land.

---

## Asymmetric Mechanic — The Greenhouse Monocle

The Guide is in a private greenhouse with a wide bay window looking out over the duo's garden plot. They cannot enter the garden. They have:

### Greenhouse UI panel

- **Monocle View (top center)** — the active focal item the Guide is examining. Click any seed packet, gift, or planted bloom in the garden to bring it into the monocle.
- **Field Guide (left)** — the searchable manual. Auto-surfaces relevant entries based on what's in the monocle.
- **Plot Lock toggles (right)** — three little gates, one per plot. The Explorer cannot plant in a plot that isn't unlocked. (Same Lane Lock pattern from V1/V2 — re-skinned as garden gates.)
- **Compost button (bottom)** — the veto. One per round. Freezes the garden for 5 seconds, lets the duo regroup. Visually, a tiny compost bin appears in the garden to signal the freeze.

### Guide tools

1. **Monocle Scan** — Reveals hidden truths: which plot a seed belongs in, which "gifts" are weeds, which strangers are verified vs. sketchy.
2. **Glow Highlight** — Hover over a plot to make it pulse in the Explorer's view. The primary directional callout: "plant here."
3. **Plot Gate Lock** — Each plot starts locked. Guide unlocks the right one for the seed in the Explorer's basket.
4. **Field Guide** — Manual entries written for the seeds and weeds the duo encounters. The manual is the most kid-readable copy in the game.
5. **Compost (veto)** — One-per-round freeze button. Costs combo.

### Why this asymmetry is sharp

The Explorer cannot plant a seed in a locked plot. Period. So the Guide's read on each seed is the gate. The Guide cannot pull a weed — only the Explorer can run to the fence and yank it. So the Explorer's action is the gate. Neither player can solo the round.

This is the asymmetric-info-relayed-for-life-skills mechanic Andrew validated, expressed in a cozy frame.

---

## Gamification Layer

### Bloom Combo

- Every correct seed planted in the right plot grows the **Bloom Meter**.
- Every weed pulled before rooting grows it more.
- High meter = the garden brightens, more butterflies appear, neighbors stop and admire.
- Low meter = the garden visibly dims, weeds spread, neighbors look concerned.

The combo system is **the look of the garden**. There is no separate UI bar. The garden *is* the UI.

This is the most important design choice in the whole level: **the feedback is the world**, not a number.

### Trust Seeds (game-wide currency)

The Trust Seeds you earn at end of round (existing system) are now visually consistent with the seeds you planted. The lobby treehouse / garden is fed directly by what you tended here. Lore consistency, no extra build cost.

### Per-run rank

- Bronze: round complete, garden alive.
- Silver: ≤ 1 mistake, no rooted weeds.
- Gold: 0 mistakes, full Bloom Meter at end.
- "Verdant Run" badge: 0 mistakes, 0 weeds rooted, 0 Compost vetoes used.

### Replayability

- **Seed pool**: 30+ seed packets each tagged Heart / Friendship / Town Square. Each round randomly draws 6–8.
- **Weed pool**: 20+ weed events with templated flavor text ("a strange wrapped present from Robux_Real_99," "a balloon that says 'free skin click here'"). Each round draws 3–5.
- **Stranger NPCs**: rotating cast of ~6 visual archetypes. Verified neighbors are sometimes mixed in to keep the duo from defaulting to "everything is a weed."
- **Garden weather**: cosmetic-only randomness (sunny / cloudy / sunset palette) for visual freshness.
- **Difficulty scaling**: faster weed cadence and trickier seeds for repeat duos.

---

## Story Frame

Briefer than V2 — the world *is* the story.

> Welcome to the Trust Garden. You're the gardener. Your buddy is in the greenhouse with the Field Guide. There are seeds to plant — they represent things about you. Some belong in your private plot, some in your friends' plot, and some are okay for the whole town to see. And keep an eye on the fence — not every gift from a stranger is a real gift.

A 20-second voiceover-or-card intro. That's it. The metaphor does the rest of the work.

### End-of-round line

A single sentence appears as the duo walks back to the lobby:

- "Your garden looks beautiful. Some things only grow well behind your fence."
- "You spotted three weeds before they rooted. Nice eyes, gardener."
- "Some neighbors brought real gifts today. Tomorrow, more strangers will come too."

No paragraph. No quiz. The lesson lives in the garden's appearance — and walks home with the player.

---

## Items & Content Systems

The same content philosophy as V1/V2: a Lua registry feeds everything.

```lua
-- ReplicatedStorage/Modules/SeedRegistry.lua sketch
return {
    Seeds = {
        {
            id = "name_seed",
            label = "Your Real Name",
            visual = "SeedTemplates/NameSeed",
            correctPlot = "HeartPlot",
            scanReveal = "This is your real name. Most people online don't need to know it.",
            difficulty = 1,
        },
        {
            id = "favorite_color",
            label = "Your Favorite Color",
            visual = "SeedTemplates/PaintSeed",
            correctPlot = "TownSquarePlot",
            scanReveal = "Sharing your favorite color is harmless and fun!",
            difficulty = 1,
        },
        ...
    },
    Weeds = {
        {
            id = "free_robux_box",
            label = "A glowing wrapped present marked 'YOU WON!'",
            visual = "WeedTemplates/FreeRobuxBox",
            sender = "RobuxKing_99",
            scanReveal = "This is a phishing weed. Pull it before it roots.",
            isWeed = true,
        },
        {
            id = "neighbor_pie",
            label = "A pie from Mr. Hibiki next door",
            visual = "GiftTemplates/NeighborPie",
            sender = "Mr. Hibiki (verified neighbor)",
            scanReveal = "A real gift! Plant it in the Friendship Plot.",
            isWeed = false,
        },
        ...
    },
}
```

Same tooling pattern — the Guide UI, the Explorer HUD, the validation server, and the score recap all read from the same registries.

---

## UI / UX

### Explorer HUD

- A small **basket icon** showing the held seed.
- Plot **glow rings** when the Guide highlights one.
- Subtle **weed alert** (bird-chirp + a fence sparkle) when a stranger approaches.
- The garden itself is the score display — no big numbers floating around.
- All text in `Enum.Font.Cartoon`, friendly, large.

### Guide HUD

- Greenhouse window view (live camera feed of the garden).
- Monocle as the central inspect tool.
- Field Guide auto-surfaces relevant pages.
- Plot gate toggles, Compost button.

### Audio

- Soft acoustic guitar loop, very Studio Ghibli adjacent.
- Wind chime for correct planting.
- Crow caw + thorny pluck for weed detected.
- The garden's brightness and instrument layering scales with the Bloom Meter — *the world is the score*.

---

## Technical Implementation

This level reuses the `PlayAreaService` slot system. The level template under `ServerStorage/Levels/TrustGarden` is the garden + greenhouse. The booth template at `ServerStorage/GuideBooths/Greenhouse` is the Guide's room.

### New / extended services

- **`TrustGardenService`** — top-level level orchestrator. Spawns seeds, runs the stranger event scheduler, validates plantings.
- **`SeedSpawner.lua`** — drops seed packets into the Explorer's basket on a tunable cadence.
- **`StrangerScheduler.lua`** — runs the "stranger throws gift over fence" events.
- **`GreenhouseScannerService.lua`** — Monocle, Highlight, Plot Lock, Compost remotes.
- **`SeedRegistry.lua`** / **`WeedRegistry.lua`** — content modules.

### New remotes

- `RequestPlantSeed(seedId, plotId)`
- `RequestPullWeed(weedId)`
- `RequestScanItem(itemId)`
- `RequestHighlightPlot(plotId)`
- `RequestPlotLock(plotId, locked)`
- `RequestCompost()`
- `WeedRooted` / `BloomMeterUpdated`

All server-validated and routed through the existing `RemoteService` pattern.

### File / line budget

```
src/ServerScriptService/Services/Levels/TrustGarden/
    TrustGardenService.lua           (~280 lines)
    SeedSpawner.lua                  (~140)
    StrangerScheduler.lua            (~160)
    GreenhouseScannerService.lua     (~200)

src/ReplicatedStorage/Modules/
    SeedRegistry.lua                 (~250 content)
    WeedRegistry.lua                 (~200 content)
    TrustGardenTypes.lua             (~80)

src/StarterPlayerScripts/UI/TrustGarden/
    GardenerHud.client.lua           (~250)
    GreenhouseHud.client.lua         (~300)
    BloomMeterController.client.lua  (~120)
```

Every file under the 500-line ceiling per `CLAUDE.md`. The Bloom-as-feedback design saves us a separate score-bar UI module.

### Art notes

- All garden assets in one cohesive style (judges' note about visual consistency).
- Plot dressing — picket fence variations, plot signs, soil texture — can be small Roblox primitives. No bespoke meshing required.
- Stranger NPC archetypes can be palette-swapped from a single rig.
- The greenhouse is one glass building. Should ship in a half-day of set dressing.

---

## Success Metrics

### Demo metrics (judges)

- Boss test holds: yes / no.
- A judge plays one round and *describes the garden afterwards* — they remember the place, not the mechanics. That's the cozy-game memory test.
- A judge says "this feels like Grow a Garden but it's about safety" — that's the win sentence.
- A judge asks "did the garden change because of how we played?" — Bloom Meter is doing its job.

### In-game metrics (post-hackathon)

- % of duos that finish a round with full Bloom.
- Replay rate — cozy mechanics retain better than challenge mechanics.
- Fraction of weeds correctly identified vs. real gifts (the *kindness in mostly-safe-internet* lesson).
- Average rounds per parent-child duo per session.

---

## Judging-Rubric Fit

- **Progress & Development:** Engineering load is comparable to V1 — one main level, one booth, no multi-station orchestration. Most of the work is content + a Bloom Meter feedback system. Achievable in 36 hours with art help.
- **Storyboarding & Message Quality:** Highest of the three. The mechanic *is* the story. Planting in the wrong plot literally shows the consequence in the world. No popups, no lectures, the strongest "Education Through Mechanics" demonstration in the rubric.
- **Potential Impact:** The "X-Factor" the rubric explicitly calls out. Cozy + safety is genuinely under-explored in Roblox civility content. This is the version most likely to *change how kids think about sharing online*, because it teaches a positive frame ("I tend my private plot") instead of a defensive frame ("I block strangers").

---

## Risks & Open Questions

1. **Metaphor risk.** If a kid doesn't read "the seed represents your name," the level fails. Mitigation: tutorial seed at level start makes it explicit; Guide's first manual entry says it plainly; visual on the seed packet shows what the seed *is* (a name tag literally on the packet).
2. **Pacing risk.** Cozy + asymmetric is hard to balance. If too cozy, no urgency; if too urgent, not cozy. Test early. Weed timer is the main dial.
3. **"Pull the weed" feels different from sorting.** New verb the Explorer learns. Tutorial weed in the first 30 seconds.
4. **Content authoring is labor.** The Seed and Weed registries together need 30+ entries with kid-readable copy. Don't underestimate. Co-write copy with a parent if possible.
5. **Visual polish carries the level.** A drab garden kills the cozy. Budget actual art time for the garden, the greenhouse, the strangers, and the Bloom Meter feedback.
6. **Compost / veto button is a fun risk.** It might feel weird thematically. If playtest hates it, replace with a "watering can pause" or just remove. The level survives without it.

---

## Scope & Cut Lines

**Must have (demo-blocker):**
- Garden with 3 plots and visible plot-locks.
- Greenhouse booth with Monocle, Highlight, Plot Lock.
- Seed planting + weed pulling, both functional.
- 12 seeds + 6 weeds in registry minimum.
- Bloom Meter visible in the world (light + butterflies).
- Score screen.
- Tutorial 30 seconds at level start.

**Should have:**
- Verified neighbor "real gift" mechanic.
- Compost veto.
- Bloom-driven instrumentation layers.
- 30+ seed and 20+ weed content.

**Nice to have:**
- Stranger NPC rotating archetypes.
- Garden weather variations.
- Treehouse / lobby callback (the seeds you plant here also flower in the lobby garden over time — meta-progression).
- "Verdant Run" badge.

If we're at hour 30 with the verified neighbor mechanic unfinished, **ship without it**. Treat all gifts as weeds for the demo. The lesson is slightly weaker but the level still works.

---

## Why This Version Wins (Or Doesn't)

V3 wins if:
- The team has any 3D / set-dressing capability and wants to bet hard on the cozy parent-child Roblox lane.
- Judges are most moved by the **X-Factor / Potential Impact** column of their rubric.
- The team is comfortable throwing away most of the existing TSA-conveyor mental model.

V3 loses if:
- The team can't dedicate time to making the garden actually look beautiful — without polish, this version is the hardest to demo.
- The cozy pacing isn't tested early and ends up boring.
- The metaphor doesn't land in playtests with real kids — at which point the team has burned hours on a vibe that didn't ship.

V3 is the **boldest creative pitch and the most rewarding if it lands**. If the team wants the demo where a judge says "wait, is this the same hackathon?" — this is the one.

---

## Boss-Test Sanity Check

- Three garden plots → "different garden plots (private vs. shared)" ✅
- Seed packets representing personal info → "things about themselves" ✅
- Strangers tossing weeds → "scam attempts" ✅
- Greenhouse Monocle → "the magic monocle that reveals" ✅
- Verified neighbors mixed in → "which 'gifts from strangers' are actually weeds in disguise" ✅

Pitch holds. This is the cozy-and-cunning version.
