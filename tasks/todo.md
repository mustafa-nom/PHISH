# TODO

## Current Priority

Build a polished MVP of Buddy Bridge with **2 levels**: Stranger Danger Park and Backpack Checkpoint.

## Setup

- [ ] `aftman install` — verify Rojo 7.7.0-rc4 + Selene 0.27.1 (HUMAN — not yet installed locally)
- [ ] `rojo serve` connects to Studio (HUMAN)
- [x] Confirm `init.meta.json` exists in every `src/` subfolder
- [x] Create base service skeletons

## Core Modules

- [x] `RemoteService.lua`
- [x] `Modules/Constants.lua`
- [x] `Modules/RoleTypes.lua`
- [x] `Modules/LevelTypes.lua`
- [x] `Modules/PlayAreaConfig.lua`
- [x] `Modules/ScenarioRegistry.lua`
- [x] `Modules/NpcRegistry.lua` — NPC trait pool for Stranger Danger
- [x] `Modules/ItemRegistry.lua` — item pool + lane mapping for Backpack Checkpoint
- [x] `Modules/ScoringConfig.lua`
- [x] `Modules/UIStyle.lua`
- [x] `Modules/RateLimiter.lua` (helper)
- [x] `Modules/TagQueries.lua` (helper)
- [x] `Modules/NumberFormatter.lua` (helper)
- [x] `Shared/RoundState.lua`
- [x] `Shared/ScenarioTypes.lua`

## Bootstrap

- [x] `ServerBootstrap.server.lua` requires all server services
- [x] `ClientBootstrap.client.lua` initializes ScreenGui and pulls progression

## Lobby + Pairing

- [x] `LobbyService.lua` — capsule pad detection, invite flow, PlayerRemoving cleanup
- [x] `MatchService.lua` — pair create/get/remove with OnPairCreated callback
- [x] `RoleService.lua` — role assignment with auto-assign timeout
- [x] `LobbyPairController.client.lua` — confirm pair UI + invite UI + Invite-to-Play prompt
- [x] `RoleSelectController.client.lua` — pick Explorer / Guide
- [ ] Test: 2 players can pair via capsule and via proximity prompt (HUMAN — needs Studio)

## Round + Slot Management

- [x] `PlayAreaService.lua` — slot pool, clone level templates, clone booth, teleport players, lock booth (invisible wall + heartbeat-based bounding box check), respawn re-teleport
- [x] `RoundService.lua` — start/end round, level sequence, timer, PlayerRemoving handling
- [x] `LevelService.lua` — start/complete/cleanup the active level
- [x] `Helpers/RoundContext.lua` — player→round registry
- [x] `Helpers/RemoteValidation.lua` — canonical validation chain
- [x] `Helpers/SignalTracker.lua` — connection tracking against round lifetime
- [ ] Test: paired duo gets teleported to a slot; Explorer in level, Guide in booth (HUMAN — needs Studio)

## Stranger Danger Park

- [x] `Scenarios/StrangerDangerScenario.lua` — generate randomized NPC scenario with anchor bias
- [x] `Levels/StrangerDangerLevel.lua` — clone NPCs, attach traits, attach knife accessory
- [x] `ExplorerInteractionService.lua` — `RequestInspectNpc`, `RequestTalkToNpc`
- [x] `GuideControlService.lua` — `RequestAnnotateNpc`
- [x] `ExplorerController.client.lua` — handle proximity-based NPC inspect, talk follow-up
- [x] `NpcDescriptionCardController.client.lua` — show trait card to Explorer + colored ring on annotation
- [x] `GuideManualController.client.lua` — render trait/risk manual on booth SurfaceGui (with screen-space fallback)
- [x] `GuideAnnotationController.client.lua` — annotation buttons
- [x] Visual: colored ring around NPC when Guide annotates
- [x] Quest: 3 clues → puppy spawn → level exit
- [ ] Test: full level playthrough with 2 players (HUMAN — needs Studio)

## Backpack Checkpoint

- [x] Generate randomized item rotation server-side (`Scenarios/BackpackCheckpointScenario.lua`)
- [x] Conveyor logic in `Levels/BackpackCheckpointLevel.lua` — spawn item, advance after sort
- [x] `ExplorerInteractionService` — `RequestPickupItem`, `RequestPlaceItemInLane`
- [x] `GuideControlService` — `RequestAnnotateItem`
- [x] Bin SFX / VFX hookups (placeholder; SFX files come from User 1 + M8 polish pass)
- [x] Manual UI shows the chart (Pack It / Ask First / Leave It rules)
- [x] N items per round → level complete
- [ ] Test: full level playthrough with 2 players (HUMAN — needs Studio)

## Round Transition + Scoring

- [x] BuddyPortal between levels (handled implicitly: completion of Stranger Danger triggers Backpack Checkpoint via LevelService)
- [x] `ScoringService.lua` — track time, mistakes, trust points
- [x] `RewardService.lua` — grant Trust Seeds (session-only via DataService)
- [x] `ScoreScreenController.client.lua` — final score UI + replay
- [x] `RoundHudController.client.lua` — timer + objective + mistakes
- [x] Return-to-lobby flow

## Lobby Progression

- [x] `DataService.lua` — session-only data
- [x] `LobbyProgressionController.client.lua` — visualize Trust Seeds / treehouse level

## Polish

- [ ] SFX hookups (button press, wrong sort, level complete, round complete) — wired via `ExplorerFeedback` + `ItemSortResult` events; needs SFX files in SoundService (User 1)
- [x] Cartoon font + friendly UI styling (UIStyle module + UIBuilder)
- [ ] Short tutorial prompts on first run (gated by DataService.HasSeenTutorial — DEFERRED)
- [ ] Replay flow tested end-to-end (HUMAN — needs Studio)
- [ ] Demo route timed under 5 minutes (HUMAN)

## Verification

- [ ] `selene src/` passes (HUMAN — selene not installed locally)
- [x] All files in `src/` under 500 lines (max: 384)
- [x] All remotes validate input + role (canonical chain in Helpers/RemoteValidation)
- [x] No client-side authoritative gameplay state
- [ ] Tested with 2 players in Studio local server (HUMAN)
- [ ] Tested 4 simultaneous duos do not cross-talk (HUMAN — annotation state lives on round.ActiveScenario, all FireClient is scoped via FirePair)
- [x] `tasks/todo.md` updated
- [x] `tasks/lessons.md` updated
