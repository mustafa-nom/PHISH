# Human TODO — PHISH!

Things only a human (or the Roblox MCP map-builder agent) can do in Roblox Studio or Creator Dashboard. Claude can't touch Studio directly.

The prior Buddy Bridge `human_todo.md` lived here; check git history if you need it (or `docs/archive/` for the BB MVP scope).

## Tooling (do once)

- [ ] `aftman install` — installs Rojo 7.7.0-rc.1 and Selene 0.27.1 from `aftman.toml`
- [ ] Verify `rojo --version` and `selene --version` work in this repo's terminal
- [ ] Install Rojo Studio plugin (if not already), connect to `rojo serve`
- [ ] **Install + activate the Roblox MCP Studio plugin.** The map agent (User 1 / Claude) cannot build the map without it. Symptom when down: every `mcp__robloxstudio__*` call returns `Studio plugin connection timeout`.

## Build the PHISH! map (one-shot, Studio Command Bar)

The User 1 / Claude agent has staged the entire map build into two Luau scripts under `studio_scripts/`. If the Roblox MCP plugin isn't connected, run them by hand:

1. Open Studio. `View` → `Command Bar` (toggles a Lua input at the bottom).
2. Open `studio_scripts/build_phish_world.luau` in any editor. Copy the entire file. Paste into the Command Bar. Press Enter.
   - Expect: `[PHISH! WORLD] Done. WaterTiles=~119. Run build_phish_templates.luau next.`
   - Result: `Workspace.PhishMap` populated with island, lodge, dock, water grid, boat, two shops.
3. Repeat with `studio_scripts/build_phish_templates.luau`.
   - Expect: `[PHISH! TEMPLATES] Done. Fish=12 Bobbers=4 Lures=1`
   - Result: `ServerStorage.PhishFishTemplates`, `.PhishBobbers`, `.PhishLures` populated.
4. Save the place file (`File` → `Save to File As…` if not already saved).

Both scripts are idempotent — re-run any time after edits. They wipe and rebuild their own scope.

## Lodge (lobby) — Studio-built

- [ ] Build the **Lodge**: a cozy fishing-cabin lobby that replaces the prior Buddy Bridge lobby
  - Wood-cabin aesthetic, warm lighting, soft ambient SFX
  - **Aquarium display zone** — large glass tank or pond inset where caught fish swim
  - Spawn point for new players
  - Door / dock-portal that teleports to Starter Cove (or just a seamless walkway)
  - NPC or sign explaining "Grab a rod and head to the dock" (1-line tutorial nudge)

## Starter Cove (pond) — Studio-built

- [ ] Build **Starter Cove**: the MVP pond
  - Water plane (translucent, with ripple VFX or shader if time)
  - Wooden dock the player stands on while fishing
  - Surrounding terrain — gentle hills, trees, lily pads, fireflies
  - **Golden-hour lighting** — pick this and lock it for MVP (no day/night cycle)
  - Ambient SFX: water lapping, distant birds, occasional splash
  - Cast zone marker (optional visible aim-cone or just a dock edge)

## Tools + Models — Studio-built

- [ ] **Fishing rod** tool model — placed in `StarterPack` or given on dock entry
- [ ] **Bobber** + **lure** visual assets (cast-time visuals)
- [ ] **12 fish models** per `docs/PHISH_CONTENT.md` — placed in `ServerStorage/FishTemplates/`
  - MVP-acceptable: simple primitive shapes (sphere body + colored fins) with category-coded colors. Ugly-but-shipping > pretty-but-incomplete.
  - Each fish model needs a clear silhouette so it reads in the aquarium
- [ ] Bobber visual variants for the 4 category cues (glitter / shimmer / fake-badge / soft-glow)

## Tags + Attributes (Roblox MCP)

These get set in Studio so the Lua services can `CollectionService:GetTagged(...)` them.

- [ ] Tag the dock cast zones with `PhishCastZone`
- [ ] Tag the aquarium display volume with `PhishAquariumDisplay`
- [ ] Tag fish templates with `PhishFishTemplate` and set attribute `FishId` matching `FishRegistry`
- [ ] Tag the Lodge spawn with `PhishLodgeSpawn`

(Final tag list will be confirmed in P2 when services are written. Update this file then.)

## Studio Settings

- [ ] Server limits: solo-friendly. Up to 8 players per server is fine; MVP can also run 1-per-server if instancing is simpler
- [ ] Audio: ambient cap audible but not loud
- [ ] Lighting: ShadowMap or Future, golden-hour ClockTime
- [ ] Avatar settings: any (PHISH! doesn't constrain avatars)

## Rojo / Build Sanity

- [ ] After Studio sync, run `rojo build default.project.json -o build.rbxl` from CLI and confirm it succeeds
- [ ] After major Studio map edits, save the place file and confirm `init.meta.json` files in `src/` were not deleted (Rojo's `ignoreUnknownInstances` rule depends on them)

## Demo Prep

- [ ] Pre-populate a demo player profile so the aquarium has 1 fish on first load (Compliment Carp recommended)
- [ ] 2-laptop dry run: judge plays solo, teammate watches for hangs
- [ ] Print or memorize the 90-second demo script from `docs/PHISH_MVP_PLAN.md`

## Creator Dashboard

- [ ] Place name set to `PHISH!` (or whatever the team picks)
- [ ] Game thumbnail / icon (golden-hour pond + glittery bobber works)
- [ ] Game description mentions "fishing" + "online safety" framing
- [ ] Submit to the LAHacks Roblox Civility Challenge per their submission instructions

## Fish art uploads (Fish Index + NEW! popup)

The `[src/ReplicatedStorage/Modules/FishArt.lua](src/ReplicatedStorage/Modules/FishArt.lua)` table maps every PhishDex species to a Roblox decal asset id. While each id is `0`, the Fish Index falls back to the 3D viewport preview and the popup falls back to a small placeholder — both work, but the art won't show. To wire up the 2D Gemini stickers:

1. In `~/.cursor/projects/Users-mustafanomair-buddy-bridge/assets/`, rename each species PNG to `<speciesId>.png` exactly matching `id` in `[src/ReplicatedStorage/Modules/PhishDex.lua](src/ReplicatedStorage/Modules/PhishDex.lua)`. The 12 ids are:
   - `UrgencyEel.png`
   - `AuthorityAnglerfish.png`
   - `RewardTuna.png`
   - `CuriosityCatfish.png`
   - `FearBass.png`
   - `FamiliarityFlounder.png`
   - `RumorRay.png`
   - `ModImposter.png`
   - `HallucinationJelly.png`
   - `PlainCarp.png`
   - `HonestHerring.png`
   - `KindnessKoi.png`
   - The reference image (`image-ce55d390...png`, the Yello Damselfish) is **not** used.
2. Upload each PNG via either path:
   - **Creator Dashboard**: `https://create.roblox.com/dashboard/creations` → Decals → Upload. Copy the numeric id from the resulting URL.
   - **Studio Asset Manager**: View → Asset Manager → Images → Add. Right-click the imported image → "Copy ID to Clipboard".
3. Paste each numeric id into the matching slot in `[src/ReplicatedStorage/Modules/FishArt.lua](src/ReplicatedStorage/Modules/FishArt.lua)`. Plain integer; the module wraps it as `rbxassetid://<id>` automatically.
4. Save, sync via Rojo, test by catching a fish — the top-right `NEW!` popup should display the sticker, and the Fish Index tile should switch from the 3D viewport to the 2D image.

## Email avatar uploads (Inspection Card sender icons)

The 34 generated PNGs in [assets/email_avatars/](assets/email_avatars/) (one per ScamCard sender) get uploaded to Roblox in one shot via [tools/upload_email_avatars.py](tools/upload_email_avatars.py). The script handles the Open Cloud API call, polls moderation, caches asset ids in `assets/email_avatars/upload_results.json`, and regenerates [src/ReplicatedStorage/Modules/SenderArt.lua](src/ReplicatedStorage/Modules/SenderArt.lua). `ScamCards.lua` reads from that module at load and populates `sender.avatarImage` for the inspection card.

One-time setup:

1. Create an Open Cloud API key at [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) with permissions **Asset → Read** and **Asset → Write**. Add the issuing IP (or `0.0.0.0/0` for hackathon ease) to the allowlist.
2. Add the key to `.env`:
   ```
   ROBLOX_API_KEY=<paste here>
   ```
3. Find your numeric Roblox user id (or the group id, if uploads should be group-owned). Profile URL → the number after `/users/`.

Run:

```bash
# user-owned uploads
python3 tools/upload_email_avatars.py --user-id <userId>
# or group-owned
python3 tools/upload_email_avatars.py --group-id <groupId>
```

The script is idempotent — already-uploaded entries (matched by source PNG sha256) are skipped on re-runs. Pass `--force` to re-upload everything, `--dry-run` to preview, or `--regen-lua-only` to rewrite `SenderArt.lua` from the cache without hitting the API.

After it finishes, sync via Rojo and catch a fish: the Inspection Card header should now show the per-sender avatar instead of the colored disc.

## Out of Scope (do not build in Studio)

- Multiple ponds beyond Starter Cove
- Boss fish models
- Cosmetics shop UI
- Buddy Mode booth (Buddy Bridge had one — don't rebuild for MVP)
