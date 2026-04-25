# Backpack Checkpoint — PRD V1: The Polished Conveyor

> **Evolution path:** Keep the original TSA conveyor + 3 bins. Add the gamification depth that turns a sorting minigame into a real co-op crucible.

This is the **lowest-risk, highest-shippability** version of the three PRDs. The mechanic the team already knows still ships. What changes is the texture around it: a story wrapper, a combo / streak system, escalating waves, and a redesigned Guide role with real tools.

---

## One-Line Pitch (Boss Test)

> Backpack Checkpoint is a 2-player TSA-for-the-internet co-op where the kid sorts items at the conveyor and the grownup runs the X-ray scanner — they have to talk to figure out what's safe to share and what's a scam.

That sentence has to survive every feature decision. If a feature can't be defended by it, cut it.

---

## Why This Version

**Pros**
- Reuses the conveyor + bin metaphor everyone on the team already understands.
- 36-hour-friendly: smallest art and engineering surface of the three options.
- The "Active Scanner Guide" upgrade alone takes asymmetry from passive ("read me a chart") to active ("scan this bag, mark the suspicious item, unlock my lane").
- Phishing fits naturally: items can arrive **inside** other items, hidden in envelopes, or as last-second swaps on the belt.

**Cons**
- It's still fundamentally one room. World-building is limited.
- Risk of feeling like a minigame rather than a level if we don't add narrative texture.

**Mitigations** are baked into the sections below: a story frame ("You work at Pixel Post, sorting outgoing mail and incoming surprises"), escalating waves, and Guide tooling that makes the booth feel like a real workstation.

---

## Educational Anchor: Privacy AND Phishing, Woven

The lesson the kid is practicing is the **two-way trust filter** every kid needs online:

1. **Outgoing:** What about me is safe to share, and with whom?
2. **Incoming:** What is being sent to me — and should I trust it?

Privacy and phishing are the same skill from opposite directions. We teach both, in one mechanic.

### Mapping bins to lessons

The three lanes serve double duty:

| Lane | Outgoing meaning (privacy) | Incoming meaning (phishing) |
|---|---|---|
| ✅ **Pack It** | Safe to share publicly | Looks legit — accept |
| ⚠️ **Ask First** | Gray area — check with a grownup | Looks weird — verify before opening |
| ⛔ **Leave It** | Keep private | Probably a scam — discard |

The bins **never change**. Items do. This means the Guide's mental model and the manual stay simple, but content can scale infinitely.

### Item categories

Items rotate from pools that are tagged in `ItemRegistry.lua`:

- **Privacy items (outgoing):** glowing house model = home address, school crest = school name, padlock card = password, name tag = real name, birthday balloon, photo polaroid, controller (favorite game), paint palette (favorite color), meme card (joke/meme).
- **Phishing items (incoming):** glowing envelope marked "YOU WON!" with a fake crown, a "Free Robux" voucher, a chat bubble that says "click here," a wrapped present from "a stranger," a fake delivery slip with a missing return address, a chat from "your friend" with weird typos, a screenshot of a too-good-to-be-true offer.
- **Mixed items (combine both):** a friend request from a face you don't recognize (carries personal info AND a phishing risk), a screenshot that contains your school in the background, a video gift card that wants your password.

Mixed items are where the level gets hard and where communication actually matters.

---

## Core Loop

A round is **3 escalating waves** of belt traffic, each lasting roughly 60–90 seconds. Total play time per round: ~4–5 minutes.

### Per-item loop

1. Item appears at the start of the belt.
2. Belt carries it forward at base speed. Item has an item ID and a hidden true bin.
3. **Guide** sees the item enter the X-ray view, can scan it for hidden details (see Guide Tools).
4. **Explorer** can pick the item up and walk it to a bin, or hit one of three lane buttons.
5. **Server validates** the choice.
   - Correct → +points, +combo, item explodes into trust sparkles.
   - Wrong → item bounces back onto the belt, mistake counter, comedic buzzer.
6. Items not handled before the belt edge fall off the end → **mistake** (treated like a wrong call). This forces decision-making, prevents stalling.

### Wave structure

- **Wave 1 — Warm-up:** 6 items, slow belt, only privacy items, no hidden envelopes. Teaches the bins. Short Guide tutorial fires automatically on the first item.
- **Wave 2 — Mixed traffic:** 8 items, normal belt speed, mix of privacy + phishing, first hidden envelope appears. Guide must use Scan to reveal contents.
- **Wave 3 — Rush hour:** 10 items, faster belt, two items can be on the belt at once (forces division of attention), introduces a **Mini-Boss Bag** at the end (see below).

### Mini-Boss Bag

Once per round, a "VIP bag" arrives — an oversized backpack with **three** items zipped inside. The belt halts. The Guide must scan it open, see all three items, and direct three sequential choices. Mini-Boss completion gives a big trust burst. A wrong call ends the round if combo was high — it's a real risk/reward moment, the climax of the round.

---

## Asymmetric Mechanic — The Active Scanner Guide

The Guide is no longer a manual reader. The Guide runs the X-ray station, and the level cannot be cleared without their tools.

### Guide UI panel

A workstation UI fills the booth screen. Top half is the **X-ray feed** of the conveyor belt, bottom half is the **Field Manual**.

### Guide tools

1. **Scan beam** — Hover over an item on the belt to reveal hidden tags (e.g., "address inside," "from unknown sender," "password requested"). Reveals truth that the Explorer can't see from outside the bag. Cooldown: 0.5s. Limited to N scans per wave to prevent spam.
2. **Highlight** — Tap an item to draw a colored circle that the Explorer **can see** floating above the item on the belt: green ring = Pack It, yellow = Ask First, red = Leave It. This is the primary call-out.
3. **Lane lock / unlock** — All three bins start **locked**. Guide unlocks the correct lane by pressing a button on their console. Wrong lane unlocked → the Explorer can still mis-sort. This makes the Guide's call genuinely gating without feeling punitive — the Explorer still has agency to disagree.
4. **Field Manual** — Searchable / scrollable digital citizenship reference. Built from real content tagged `Privacy/`, `Phishing/`, `Mixed/`. Updates with every new item type the duo encounters across runs (so it acts as a meta-progression too).
5. **Override / Veto button** — Last-resort one-per-round veto. Locks all three lanes for 3 seconds, freezing the belt. Used when the Explorer is about to commit a bad call. Costs combo. A "pause and talk" moment built into the controls.

### Why this is good asymmetry

The Explorer can't beat the level alone — the lanes are physically locked until the Guide unlocks one. The Guide can't beat the level alone — they can't pick anything up, can't move the belt, and can't sort. Communication is literally the input.

This is the mechanic Andrew validated as the pitch hook: **asymmetric-info-relayed-for-life-skills**.

---

## Gamification Layer

What turns a minigame into something kids actually want to replay.

### Trust Combo Meter

- Every correct call grows a combo bar.
- 3 in a row = ×1.5 multiplier
- 5 in a row = ×2.0
- 10 in a row = "Perfect Trust Run" badge candidate
- One wrong call resets the combo.
- The combo meter shows a subtle visual — leaves growing on the manual, sparkles on the bins, the booth lights brightening. **Show, don't tell.**

### Trust Streak voice cues

When the combo passes thresholds, the Guide's manual whispers a short callout into both players' UI: *"Nice — you two are dialed in."* / *"Wait — they're testing you."* These are short, kid-readable, never preachy.

### Trust Seeds (existing system)

Score → Trust Seeds → grow lobby treehouse. This already exists in the game's PRD; this level just feeds it.

### Per-run rank

- Bronze: finished round
- Silver: ≤ 2 mistakes
- Gold: ≤ 1 mistake
- Perfect Trust Run: 0 mistakes, full combo through Mini-Boss

### Replayability hooks

- Item pool size: **40 items minimum**. Each round pulls a randomized 24.
- ~30% of items have **variant traits** (e.g., the "school crest" can show as a hat, a banner, or a pencil case — same lesson, different surface).
- Phishing items have **dynamic flavor text** generated from a small template pool ("from FreeRobux_OFFICIAL_99_real," "from <YOUR FRIEND>," etc.). The Guide reads the manual differently each run.
- Mini-Boss bag composition is randomized.
- Belt speed and wave length scale with rank (optional difficulty mode for repeat duos).

The Guide can never just memorize "third item goes left." They have to read.

---

## Story / World Wrapper

The Backpack Checkpoint is now framed as **Pixel Post: Outbound Sorting**.

> The Explorer just got hired at Pixel Post, the magical mailroom that handles everything kids send to and receive from the internet. Today is their first shift. The Guide is the supervisor in the X-ray booth, training them on the rulebook. Bags are coming in. Get sorting.

This 30-second framing slide plays at level start. It costs almost nothing to build and gives the level a "place" — a thin but real world. The lobby treehouse has a tiny Pixel Post booth as a callback.

The conveyor visuals adopt this theme: little envelopes rolling alongside backpacks, "OUTGOING" and "INCOMING" stamps on the bins, a postage-stamp aesthetic. Friendly, cozy, kid-Roblox.

---

## Items & Content Systems

Stored as Lua data in `ReplicatedStorage/Modules/ItemRegistry.lua`.

```lua
-- Sketch
return {
    Items = {
        {
            id = "address_house",
            label = "A glowing model of your house",
            category = "Privacy",
            trueBin = "LeaveIt",
            visualTemplate = "ItemTemplates/AddressHouse",
            scanTags = { "address", "private" },
            difficultyTier = 1,
        },
        {
            id = "free_robux_envelope",
            label = "An envelope marked 'YOU WON!'",
            category = "Phishing",
            trueBin = "LeaveIt",
            visualTemplate = "ItemTemplates/FreeRobuxEnvelope",
            scanTags = { "scam", "too good to be true" },
            difficultyTier = 2,
            innerItem = nil, -- can wrap a privacy item to escalate
        },
        ...
    },
    -- 40+ entries
}
```

The same data drives:
- belt spawning
- the Guide's X-ray reveal
- the field manual entries
- the score screen recap

Content scales by adding rows. Engineers don't have to touch new code per item.

---

## UI / UX

### Explorer HUD

- Three large lane buttons across the bottom: **Pack It / Ask First / Leave It**, color-coded.
- Currently-held item name floats next to the cursor.
- Combo meter top-right (subtle).
- Guide highlights appear as floating rings over items on the belt.
- All text in `Enum.Font.Cartoon`, large, kid-readable.

### Guide HUD

- Top: X-ray feed of belt with item silhouettes.
- Mid: Scan tool, Highlight tool, Lane Lock toggles, Veto button.
- Bottom: Field Manual (searchable).
- Item summary card on hover.

### Audio

- Calm bossanova-ish loop during waves.
- Belt clatter SFX for groundedness.
- "Soft chime" for correct, "boing" for wrong (never harsh).
- Combo escalation: chord stack adds an instrument every combo tier.

---

## Technical Implementation

This level lives inside the existing `PlayAreaService` slot system. Reuses the level template / booth template lifecycle defined in `CLAUDE.md`.

### New / extended services

- **`LevelService.BackpackCheckpoint`** — wave runner, belt spawner, validation. Single entry: `:StartLevel(slot, explorer, guide)`.
- **`ScannerService`** (new, server-side) — handles Guide scan / highlight / lane-lock / veto remotes. All authoritative.
- **`ItemRegistry`** (existing module) — fed with the 40+ item content described above.
- **`ScoringService`** — extended with combo / mini-boss / perfect-run rules. Centralized in `ScoringConfig.lua` per the architecture rules.

### New remotes (in `RemoteService`)

- `RequestScanItem(itemId)`
- `RequestHighlightItem(itemId, color)`
- `RequestUnlockLane(lane)`
- `RequestVeto()`
- `RequestPlaceItemInLane(itemId, lane)`
- `BeltStateUpdated`
- `WaveStarted` / `WaveEnded`
- `ScannerOverlayUpdated`

All remotes server-validated, rate-limited, and routed through the existing `RemoteService` pattern. No client-trusted score, lane, or scan results.

### Files (rough)

```
src/ServerScriptService/Services/Levels/
    BackpackCheckpointService.lua      (~300 lines, splittable)
    BackpackCheckpoint/
        BeltController.lua             (~150 lines)
        WaveDirector.lua               (~120 lines)
        ScannerLogic.lua               (~120 lines)

src/ReplicatedStorage/Modules/
    ItemRegistry.lua                   (data, ~300 lines for 40 items)
    BackpackCheckpointTypes.lua        (~80 lines)

src/StarterPlayerScripts/UI/
    BeltExplorerHud.client.lua         (~200 lines)
    ScannerGuideHud.client.lua         (~250 lines)
```

Each file stays well under the 500-line ceiling. If `BackpackCheckpointService.lua` starts to bloat, split out the Mini-Boss into `MiniBossDirector.lua`.

---

## Success Metrics

### Demo metrics (judges)

- Boss-test sentence holds: yes / no.
- A judge plays one round and the second they're ready to play another: lo-fi but the strongest signal we can get on a 36-hour bench.
- Visible **two-player communication** during the demo. If a judge plays Guide and a teammate plays Explorer and they actually talk, we win.

### In-game metrics (post-hackathon, if we ship)

- % of rounds where Guide used Scan at least once.
- % of rounds where Explorer waited for a Highlight before sorting (proxy for "they actually communicated").
- Average mistakes per round, trending down across replays.
- Round 2 retention.

---

## Judging-Rubric Fit

- **Progress & Development:** Tight, polished single level. Belt + Active Scanner is real engine work — random spawning, server validation, animated UI, server-authoritative streak system.
- **Storyboarding & Message Quality:** Pixel Post wrapper gives the level a place. Mixed items teach by *experience* — the kid sees an "address" hidden inside a "Free Robux envelope" and has to coordinate to spot it. Lesson is in the mechanic.
- **Potential Impact:** Privacy + phishing are the two highest-leverage online-safety lessons for kids 7–12. The combo system rewards the *habit* (talk to your grownup), not just the right answer.

---

## Risks & Open Questions

1. **Belt as a single room may feel small.** Mitigation: Pixel Post wrapper + audio + Mini-Boss escalation. If still flat, V2 (Airport World) is the upgrade path.
2. **Lane Lock could frustrate.** If the Guide is slow, the Explorer twiddles thumbs. Mitigation: belt items have ~5 second on-belt time before they fall, so the Guide has ramp; pre-scan happens before the item reaches the action zone. Run a 2-player Studio test early to dial this.
3. **Phishing literacy varies wildly by age.** Tier-1 phishing items (free Robux) are obvious; Tier-3 (a friend request from a stranger with a real-looking name) is hard. Make sure tier-3 items only appear in Wave 3, not Wave 1.
4. **Mixed items risk being unfair.** Always make sure the Guide's scan can reveal the hidden truth. The Explorer should never be expected to guess what they can't see.
5. **40-item content target is aggressive for 36 hours.** Cut line: ship 20 items in three tiers and design the registry so more can be added by content drops. The mechanic doesn't break with fewer items.

---

## Scope & Cut Lines

**Must have (demo-blocker):**
- Belt + 3 bins + correct/incorrect feedback.
- Active Scanner Guide with at least: Scan, Highlight, Lane Lock.
- 1 wave at minimum (target 3).
- 12 items minimum (target 40).
- Combo meter visible.
- Score screen.
- Pixel Post intro slide.

**Should have:**
- Mini-Boss bag.
- Field Manual cross-reference.
- Veto button.
- Mixed items.

**Nice to have (post-hackathon):**
- Item visual variants.
- Adaptive difficulty.
- Daily content rotation.
- Voice-line callouts.

If the team is at hour 30 and any "Should have" is unfinished, cut it without guilt. The mechanic is the demo. The polish is the texture.

---

## Why This Version Wins (Or Doesn't)

V1 wins if:
- The team has limited art bandwidth and needs the smallest world to build.
- Andrew's "asymmetric-info-relayed" pitch hook needs to be **immediately** visible to a judge in a 60-second demo.
- We're betting on tight execution beating bigger vision.

V1 loses against V2 (Airport World) on the "Learn and Explore feels like a real place" axis, and against V3 (Reinvented) on novelty / X-factor. But it's the safest "we will demo something polished" option.

---

## Boss-Test Sanity Check

Re-read the one-line pitch. Does each major system here defend it?

- Belt + bins → "TSA-for-the-internet" ✅
- Active Scanner Guide → "the grownup runs the X-ray scanner" ✅
- Privacy + phishing items → "what's safe to share and what's a scam" ✅
- Combo + Mini-Boss + waves → keeps the round fun, not preachy ✅
- Pixel Post wrapper → gives the level a place without overstaying ✅

Pitch holds. Build it.
