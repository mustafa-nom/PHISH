# Backpack Checkpoint — PRD V2: The Pixel Port Terminal

> **Evolution path:** Take the TSA core and grow it into a small explorable airport hub — multiple stations, traveler NPCs, a story thread, and a Guide tower with a multi-camera scanner. The judge-stated reference is **Ecos La Brea**: educational MMO that doesn't feel like homework.

This is the **highest-ambition, highest-judge-payoff** version of the three. It bets that a small, gorgeously cohesive *place* makes the "Learn and Explore" sort framing inevitable.

---

## One-Line Pitch (Boss Test)

> Pixel Port is a 2-player co-op where the kid is a junior officer running passengers through an internet airport, and the grownup is in the control tower with the safety scanner — together they decide what gets shared, what gets blocked, and what's a scam in disguise.

That sentence has to survive every feature decision. If a feature can't be defended by it, cut it.

---

## Why This Version

**Pros**
- Builds a *world*, not a minigame. Judges felt like the experience could be sorted into "Learn and Explore" — this version most clearly looks like that.
- Narrative gives the lessons stickiness. Kids remember "the kid in the line who tried to give me their address" months later, in a way they don't remember "item #12 went in lane 3."
- Multi-station design naturally handles privacy AND phishing without forcing them into one belt: dedicated stations for each, plus crossover stations for the hard mixed cases.
- The Guide tower is genuinely cinematic — it's a real workstation with cameras, scanners, and a manual. That alone reads as "polished" in a 60-second demo.

**Cons**
- Highest art and engineering surface of the three options.
- Most cuttable parts are also the parts that sell the vision. Trimming hurts more here than in V1.
- Risk of feeling unfocused if any one station is rough.

**Mitigations** are deliberate scoping below: 4 stations target, 2 stations as the demo-blocker minimum. Unbuilt stations are still accessible as "closed for the night" doors that hint at content depth without needing to be built.

---

## Educational Anchor: Privacy AND Phishing, Woven

Same framing as V1, but expressed across the terminal:

- **Privacy stations** handle outgoing flow — what is the passenger willing to declare? What's safe? What's TMI?
- **Phishing stations** handle incoming flow — what mail / packages / boarding passes are showing up that shouldn't be trusted?
- **Customs (the climax station)** mixes both — passengers carry items, the items carry envelopes, the envelopes carry tricks.

The world frames these as **two halves of one job**: keeping the kid traveler safe in both directions of the internet.

---

## The World: Pixel Port

A cozy mini-airport, palette-matched to the lobby. Roblox-cute. Small footprint — one player can walk it end-to-end in 60 seconds. Big enough to feel like a place, small enough to ship.

### Locations (in walking order)

1. **Arrival Lounge** — where new passengers (kid NPCs) drop in. Tutorial-friendly. The Explorer enters here at level start.
2. **ID Counter** — first station: privacy intake.
3. **Baggage Belt** — second station: the original conveyor, recontextualized. Privacy + phishing items.
4. **Customs** — third station: the climax. Mixed cases, hardest items.
5. **Boarding Gate** — fourth station: a phishing-focused departure check.
6. **Lost & Found Cart** (optional / stretch) — between stations: a hint cache where the Guide can drop a flag on past mistakes.
7. **Pixel Port Tower** — the Guide booth. Multi-camera, multi-station view.

The Explorer **walks** between stations. There is no skipping. The walk is short but it gives the level pacing — the moment between stations is where the duo *talks*.

### Visual & sound direction

- One cohesive style across all stations (Andrew's note about consistent styling). Cartoon, friendly, soft pastels, art-deco airport-poster influence.
- Background music is a single low-key bossanova-ish loop with station-specific instrumentation layered in.
- Each station has one signature ambient sound: ID Counter's stamp, Belt's clatter, Customs' hum, Gate's intercom.
- NPCs use simple emote-bobs, no full lip-sync. Friendly, not photorealistic.

This list is non-negotiable: visual incoherence is the fastest way to lose Andrew's vote.

---

## Stations in Detail

### Station 1 — ID Counter

The Explorer stands at a counter. A kid NPC walks up holding a clipboard with **declarations** floating above their head:

- their real name
- their school
- their address
- their favorite color
- their birthday
- their parents' phone

The Explorer's job is to **stamp each declaration** as ✅ Pack It / ⚠️ Ask First / ⛔ Leave It.

**Twist:** the NPC reads each one aloud as a request — "Should I tell people my address?" The Guide consults the manual and tells the Explorer which stamp to use.

The Guide camera is focused on this counter while it's active. Stamp wrong → polite NPC frown, mistake counter +1. Stamp right → trust sparkle, NPC moves on.

Each round: 1 NPC, 4 declarations randomly drawn from a pool.

**Lesson:** privacy. Same content as V1's privacy items, dressed as a real social interaction.

### Station 2 — Baggage Belt

The original V1 mechanic in concentrated form. Conveyor belt, three bins, items rolling past.

**Cuts from V1:** No mini-boss. No combo waves. Just a steady ~8-item belt with a mix of privacy and phishing.

**Adds in V2:** the Guide tower's scanner camera now snaps to this station. The lane buttons here are physical bin doors — the Explorer literally throws (or button-launches) items into bins. Lane Lock from V1 still applies.

This station is the workhorse and the most familiar Roblox sorting moment.

### Station 3 — Customs

The climax. Hardest content. A queue of 3 NPC travelers steps up one at a time.

Each traveler has:
- a small **passport** (visible to both players)
- a piece of **luggage** (Guide can scan it)
- a piece of **incoming mail** they're carrying (Guide can scan it)
- a request — they're asking the Explorer for permission to do something ("Can I share this picture? Can I open this DM? Can I add this stranger as a friend?")

The Explorer must decide: **Approve**, **Hold for Review**, or **Deny**. (The same three lanes, dressed differently.)

This is where mixed items live — the traveler is friendly but their luggage holds an address; the mail looks legit but the return address is "FreeRobux99." The Guide must use the scanner aggressively.

**Why Customs is the climax:** every previous station is a single decision. Customs forces the duo to integrate **identity**, **luggage**, and **incoming mail** into one call. It's the level's "boss room" without inventing a boss.

### Station 4 — Boarding Gate

A short, breezy outro. A few last passengers run up holding **boarding passes** that may or may not be legit:

- Real passes look right.
- Phishing passes have telltales: misspelled "Robloxs," weird sender, "click-to-claim," promised rewards.

Explorer scans by walking the pass under the gate; Guide marks the pass on their tower view as ✅ or 🚩. If real, the passenger boards their plane (a small plane decal swooshes off-screen — payoff visual). If fake, the passenger is gently turned away with a "thanks for checking" line.

This station closes the round on a high note: simple, fast, satisfying. It's also where Wave-3-style speed creeps in.

---

## Asymmetric Mechanic — The Guide Tower

The Guide is in the **Pixel Port Tower**, instanced privately to the duo's slot (per the existing `GuideBoothService` lifecycle in `CLAUDE.md`).

### Tower UI panel

- **Camera Wall (top)** — four small camera feeds, one per station. The active station's feed enlarges automatically. The Guide can also click any camera to focus.
- **Field Manual (left)** — searchable digital citizenship reference, pre-populated with all four stations' content.
- **Scanner Console (right)** — Scan, Highlight, Lane Lock, Veto.
- **Walkie button (bottom)** — pings the Explorer's HUD with a directional indicator. Replaces "shouting in voice chat" if the duo is in text mode.

### Guide tools (per station)

| Station | Scan | Highlight | Lane Lock | Veto |
|---|---|---|---|---|
| ID Counter | reveals what NPC is *not* saying out loud | colors the right stamp on Explorer's HUD | locks/unlocks each stamp | freezes counter, costs combo |
| Baggage Belt | reveals contents of envelopes / hidden tags | rings around items | locks/unlocks lanes | freezes belt |
| Customs | reveals luggage + mail truth | colors the Approve/Hold/Deny button | gates the decision | freezes the queue |
| Gate | reveals pass authenticity | flags the pass | gates the boarding doors | freezes the gate |

The mental model is **the same four tools** at every station. Only what they *reveal* changes. This keeps the Guide's learning curve small and the surprise / variety high.

### Why this is good asymmetry

The Explorer cannot leave a station until the Guide has unlocked the next exit (a small gate at each transition). The Guide cannot affect anything at a station they aren't watching. So the Explorer is always *waiting* on the Guide and *acting* on their direction. That waiting moment — the second between "Guide reads the manual" and "Explorer commits the choice" — **is the practiced behavior**: pause, talk, choose together.

---

## Story Thread

Most levels in this kind of game don't have a story. This one needs one — that's what makes it Ecos La Brea-flavored.

### The pitch the kid hears

> Welcome to Pixel Port. You're the new junior officer. Your supervisor is up in the tower — they've got the rulebook and the cameras. The kids who fly through here are heading to all kinds of internet places, and your job is to help them pack the right stuff and spot what shouldn't be coming through. Ready, officer?

### NPC traveler arcs (small, persistent across the round)

A few of the NPC kids are recurring across stations — the duo sees the same kid at the ID Counter and again at the Boarding Gate. The kid's behavior at the Gate is informed by what got approved at the Counter.

**Why this matters:** an NPC who got their address stamped through earlier in the round shows up at the Gate looking nervous, and a phishing pass arrives addressed to them. The duo realizes their early call had downstream consequences. That's a **systems-level lesson**, not a popup, and it's what wins on "Storyboarding & Message Quality."

If we have time for two or three NPC arcs, the level feels alive.

### End-of-round line

The Field Manual closes the round with a single sentence — never a paragraph. Examples (kept short, kid-readable):

- "Nice work, officer. You only let the safe stuff through tonight."
- "Tomorrow's flights are already on the board. Get some sleep."
- "Some sneaky mail almost got through — good catch."

No lectures. The lesson is the round, not the closing card.

---

## Replayability

- **NPC traveler pool:** 12+ kid NPCs with randomized declarations, requests, and luggage.
- **Item pool:** same `ItemRegistry.lua` from V1, scaled to 40+ items.
- **Phishing template strings:** randomized per-run sender names and offers.
- **Station order:** ID Counter → Belt → Customs → Gate is fixed for narrative coherence, but content within stations is fully randomized.
- **NPC arc selection:** 2–3 of the 12 NPCs are randomly tagged as "recurring" each run. Their downstream consequences differ.
- **Difficulty scaling:** repeat duos see more mixed items, faster belt, sharper phishing tells.

A duo that has played 5 times has not seen the same round twice.

---

## UI / UX

### Explorer HUD

- Minimal: stamp / lane / approve / scan-pass buttons appear contextually at each station.
- Floating Guide highlights are visible.
- A small mini-map of the terminal lives in the corner (helps with the walking).
- All text in `Enum.Font.Cartoon`, large.

### Guide HUD

- Camera wall feels like a real airport tower.
- Manual is **always visible** even when the Guide is mid-scan. They never have to "find the page" — search exists, but the relevant entries auto-surface based on which item / NPC is being scanned.
- Veto button is big, red, and one-per-round so it feels meaningful when used.

### Audio

- Soft chime for correct, gentle bonk for wrong. Never harsh.
- Stations have a "reaching the end" cue — chord builds as the queue empties.
- The closing announcement plays a soft jingle as the duo walks back to the lobby portal.

---

## Technical Implementation

This level reuses the `PlayAreaService` slot system. The level template under `ServerStorage/Levels/PixelPort` is the airport hub. The booth template is a custom tower (different from the default booth) and lives at `ServerStorage/GuideBooths/PixelPortTower`.

### New / extended services

- **`PixelPortService`** — top-level level orchestrator. Owns station lifecycle and NPC spawning. Wraps the four station controllers.
- **`StationController` (one per station)** — `IdCounterStation.lua`, `BaggageBeltStation.lua`, `CustomsStation.lua`, `BoardingGateStation.lua`. Each implements `:Start(slot, explorer, guide)` and `:Stop()`.
- **`TravelerService`** — server-side NPC director. Spawns recurring NPCs, tracks per-round state.
- **`ScannerService`** — same as V1, extended with per-station scan profiles.
- **`ItemRegistry` / `TravelerRegistry`** — content modules in `ReplicatedStorage/Modules`.

### New remotes

- All from V1 (Scan / Highlight / LaneLock / Veto / PlaceItemInLane).
- `RequestStampDeclaration(declarationId, stamp)`
- `RequestApproveTraveler(travelerId, decision)`
- `RequestScanBoardingPass(passId)`
- `StationActiveChanged`
- `TravelerArcUpdated`
- `CameraFocusChanged`

All server-validated, rate-limited, behind the existing `RemoteService` boilerplate.

### File / line budget

```
src/ServerScriptService/Services/Levels/PixelPort/
    PixelPortService.lua           (~250 lines)
    Stations/
        IdCounterStation.lua       (~180)
        BaggageBeltStation.lua     (~250)
        CustomsStation.lua         (~280)
        BoardingGateStation.lua    (~160)
    TravelerService.lua            (~200)
    ScannerService.lua             (~200)

src/ReplicatedStorage/Modules/
    ItemRegistry.lua               (~300, content)
    TravelerRegistry.lua           (~250, content)
    PixelPortTypes.lua             (~80)

src/StarterPlayerScripts/UI/PixelPort/
    ExplorerHud.client.lua         (~250)
    TowerHud.client.lua            (~300)
    StationContextController.client.lua (~150)
```

Total ~3,000 lines of code + content. Aggressive for 36 hours; achievable if station controllers are scoped tight and content tables are populated last.

Every file stays under the 500-line ceiling per `CLAUDE.md`.

---

## Success Metrics

### Demo metrics (judges)

- Boss test holds: yes / no.
- A judge asks "wait, is that NPC the same one from earlier?" — that's a win on Storyboarding & Message Quality.
- A judge can replay and notice randomization between runs.
- Judges describe the experience as "feels like a place" or similar — that's the Ecos La Brea benchmark.

### In-game metrics (post-hackathon)

- % of duos that complete all 4 stations.
- Average time at Customs (proxy for "the hard moment they had to talk through").
- Mistake rate by station — Customs should be highest, Gate lowest after pattern recognition.
- Replay rate — Pixel Port being a *place* makes returning emotionally easier than returning to a belt.

---

## Judging-Rubric Fit

- **Progress & Development:** Multi-station co-op level with traveler arcs, multi-camera Guide tower, scanner tooling — the most engine-impressive of the three options. Big swing on the "how much can you build in 36 hours" axis.
- **Storyboarding & Message Quality:** Highest of the three. Narrative arcs across stations make the lessons stick. The closing line gives the round a meaning without lecturing.
- **Potential Impact:** This is what a "Learn and Explore" sort game looks like at scale. The judges asked for this directly.

---

## Risks & Open Questions

1. **Station count creep.** Four is the target. Two is the floor. Don't add a fifth even if it's tempting.
2. **NPC art is a real cost.** Use a single rig with palette-swap clothing. Avoid bespoke models per traveler.
3. **Customs complexity.** This station integrates the most tools — easy to over-design. Strict rule: every Customs traveler is one passport + one luggage + one mail piece. No more.
4. **Walking time between stations.** Could feel like dead air. Pace it: ~8 second walks max. The "talk-and-walk" is the educational moment, not filler.
5. **Recurring NPC arcs are the most cuttable thing.** If we're at hour 28 and arcs aren't wired up, ship without them. The level still works as 4 strong stations.
6. **Tower UI complexity.** Camera wall + scanner + manual on one screen for the Guide is a lot. Test early with a real second player. Reduce information density if it's overwhelming.

---

## Scope & Cut Lines

**Must have (demo-blocker):**
- Pixel Port hub with **at least 2 stations** (ID Counter + Customs is the strongest pair).
- Guide Tower with camera wall + scanner + manual.
- 1 traveler NPC per station minimum.
- Score screen.
- Cohesive art style applied consistently.

**Should have:**
- All 4 stations.
- Recurring NPC arc (1 NPC repeats).
- Phishing items in Customs.

**Nice to have:**
- 2–3 NPC arcs.
- Lost & Found cart.
- Per-station ambient music layers.
- Cinematic intro fly-in.

If the team is at hour 30 with stations 3 and 4 unfinished, **leave them visible but locked** ("This area opens after rank Gold"). The judge sees content depth without us building it.

---

## Why This Version Wins (Or Doesn't)

V2 wins if:
- The team has any 3D / set-dressing capability and can build 4 small rooms in one art style.
- We're betting on **wow-factor** for the judges (especially on Storyboarding & Message Quality and Potential Impact).
- We want the strongest possible "Learn and Explore" sort eligibility argument.

V2 loses if:
- Art bandwidth is thin and the world ends up looking inconsistent — Andrew explicitly flagged this risk.
- The team can't get all 4 stations to even functional. A half-built airport reads worse than a polished single belt (V1).
- Time pressure forces cuts that gut the narrative arc — the lesson lands in the *arc*, not in any one station.

V2 is the **boldest pitch and the riskiest build**. Make sure the team is honest about whether they can hit 2 stations + tower at minimum before committing.

---

## Boss-Test Sanity Check

- Pixel Port hub → "an internet airport" ✅
- ID Counter / Belt / Customs / Gate → "junior officer running passengers through" ✅
- Tower scanner → "the grownup with the safety scanner" ✅
- Mixed items at Customs → "what's a scam in disguise" ✅
- Stamp / lane / approve / boarding pass mechanics → "what gets shared, what gets blocked" ✅

Pitch holds. If we have the build budget, this is the one.
