# Human TODO

Tasks split between the **Map User** (User 1, Roblox MCP / Studio) and the **Scripting User** (User 2, Rojo + Claude Code).

Claude should not mark related features complete until the human confirms these are done.

## Tooling Verification

- [ ] `aftman install` succeeds and pulls Rojo `7.7.0-rc4` and Selene `0.27.1`. If `7.7.0-rc4` is not the latest available `rc`, bump `aftman.toml` to the newest `7.7.0-rc*` tag from https://github.com/rojo-rbx/rojo/releases.
- [ ] Rojo Studio plugin installed at the matching version.
- [ ] `rojo serve default.project.json` connects successfully.

## Studio Map (User 1 — see `prompts/user1_map_prompt.md`)

### Lobby

- [ ] Main lobby area built
- [ ] Lobby `SpawnLocation` placed
- [ ] 4 capsule pad pairs (8 pads total) tagged `LobbyCapsule` with `CapsuleId` + `CapsulePairId`
- [ ] Treehouse / garden visual area for progression display

### Play Arena Slots

- [ ] 4 `PlayArenaSlot` models in `Workspace/PlayArenaSlots`, hidden region (e.g. y = -500)
- [ ] Each slot has `SlotIndex` attribute, `ExplorerSpawn` part, `BoothAnchor` part, empty `PlayArea` Folder, empty `Booth` Folder
- [ ] Slots spaced far apart so cloned levels don't overlap

### Level Templates (in `ServerStorage/Levels`)

#### StrangerDangerPark
- [ ] Park / town plaza geometry (fountain, hot dog stand, parked car, alley behind shop, playground)
- [x] `PrimaryPart` set (LevelOrigin)
- [x] `LevelEntry` part where Explorer spawns
- [x] 8 `BuddyNpcSpawn` parts with unique `NpcSpawnId` and matching `Anchor` attributes (HotdogShop, GeneralStore, WhiteVan, AlleyMouth, NorthSidewalk, SouthSidewalk, EastSidewalk, WestSidewalk)
- [x] No puppy/clue exit wiring required; the Guide booth submit pad completes or fails this level (legacy `puppy_spawn_*` parts still present but unused by current scenario)
- [ ] Themed but kid-friendly aesthetic (no horror)

#### BackpackCheckpoint
- [ ] Conveyor belt model with `BeltStart` and `BeltEnd` reference parts
- [ ] 3 bins tagged `BuddyBin` with `LaneId` ∈ `"PackIt"` | `"AskFirst"` | `"LeaveIt"`
- [ ] Standing area for the Explorer
- [ ] `LevelEntry` and `LevelExit` parts
- [ ] TSA-style cartoon checkpoint aesthetic

### NPC Templates (in `ServerStorage/NpcTemplates`)

- [ ] At least 6 visually distinct NPC rigs (different outfits — shop worker apron, police uniform, casual park goer, parent with stroller, etc.)
- [ ] Each NPC rig has `UpperTorso`, `Torso`, `HumanoidRootPart`, or `PrimaryPart` so scripts can attach the runtime badge SurfaceGui
- [ ] Pose/stage NPC templates so cues read clearly: van leaner waving, hot dog vendor behind counter, ranger confident/helpful, parent with kid, hooded/risky NPC alone, knife/tense NPC kid-friendly and non-gory

### Item Templates (in `ServerStorage/ItemTemplates`)

- [ ] Cartoon item models for each entry in the item pool — see `docs/GAME_DESIGN.md` "Backpack Checkpoint" item list
- [ ] Each is an anchored Model with `PrimaryPart`

### Booth Template (in `ServerStorage/GuideBooths`)

- [x] `DefaultBooth` Model with `PrimaryPart` (BoothOrigin), `GuideSpawn`, `ControlPanel` (with SurfaceGui anchor), and a `Window` (transparent part) facing the play area
- [x] Added `GuideCameraAnchor` part in `DefaultBooth`; sits at (0, 5.5, -4.8) looking toward the pedestals
- [x] 3 slot pedestal BaseParts tagged `BB_BoothSlot` (BoothSlot1/2/3), each with numeric attribute `BB_SlotIndex` = `1`, `2`, or `3`
- [x] 1 submit pad BasePart tagged `BB_BoothSubmit` (BoothSubmit)
- [x] Visible world labels: `Slot 1`, `Slot 2`, `Slot 3`, and `Submit Accusation` (BillboardGuis on each part)
- [ ] Make booth larger/cleaner so Guide avatar and walls do not occlude the camera (verify in playtest)
- [ ] No door — Guide cannot leave by walking

### Tags & Attributes Sanity Pass

- [ ] All required CollectionService tags applied — see `docs/TECHNICAL_DESIGN.md` "Map Object Conventions"
- [ ] All `NpcSpawnId`, `LaneId`, `CapsuleId`, `CapsulePairId`, `SlotIndex` attributes set
- [ ] All `LevelType` attributes set on level template root models

### Visual Polish

- [ ] Bright, kid-friendly color palette
- [ ] Cartoon proportions
- [ ] Stranger Danger park polish pass: paths, fountain/plaza, hot dog stand, white van area, alley mouth, benches, playground/family area, trees/lamps/signs
- [ ] Signage at lobby capsules ("Buddy Pair 1", etc.)
- [ ] SFX placeholders in `SoundService`: `ConfirmPair`, `RoundStart`, `LevelComplete`, `WrongSort`, `CorrectSort`, `RiskyTalk`

## MCP Blocker

- [x] Roblox MCP execution restored. `roblox-studio` and `robloxstudio` MCP servers reconnected after the plugin came back online; `execute_luau` confirmed via ping. Booth pedestals/submit pad/camera anchor were applied this session.

## Scripting (User 2 — see `prompts/user2_scripting_prompt.md`)

- [ ] All work tracked in `tasks/todo.md`
- [ ] Studio map edits through MCP remain pending until the MCP execution blocker above is cleared

## Roblox Settings

- [ ] Set max players per server = 8
- [ ] Enable Studio API access if DataStores are used
- [ ] Configure experience name + thumbnail before submitting
- [ ] Test with 2-player Studio local server
- [ ] Publish test place before final Devpost submission

## Demo Prep

- [ ] Practice the demo route under 5 minutes
- [ ] Two team members ready to play (Explorer + Guide)
- [ ] Practice pitch — lead with the Learn-and-Explore framing
- [ ] Take screenshots / GIFs for Devpost
- [ ] Record backup demo video
