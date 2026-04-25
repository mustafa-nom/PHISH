--!strict
-- Shared constants for both server and client.

local Constants = {}

-- Solo testing: when true and IsStudio() and only one player, LobbyService
-- auto-pairs the lone player with a stub second slot, RoleService lets the
-- lone player toggle role with a key. Disable for the real demo.
Constants.DEBUG_SOLO = false

-- Server capacity
Constants.MAX_PLAYERS_PER_SERVER = 8
Constants.MAX_DUOS_PER_SERVER = 4
Constants.SLOT_COUNT = 4

-- Lobby
Constants.INVITE_TTL_SECONDS = 15
Constants.CAPSULE_CONFIRM_WINDOW_SECONDS = 5
Constants.PROXIMITY_INVITE_RANGE = 12

-- Role select
Constants.ROLE_AUTOASSIGN_SECONDS = 12

-- Round timing
Constants.ROUND_DEFAULT_TIME_LIMIT = 300
Constants.LEVEL_TIME_LIMIT_SECONDS = 240

-- Stranger Danger Park
Constants.CLUES_TO_FIND = 3
Constants.INSPECT_RADIUS_STUDS = 14
Constants.TALK_RADIUS_STUDS = 10
Constants.RISKY_TELEPORT_BACK_DISTANCE = 0
Constants.RISKY_SLOWDOWN_SECONDS = 1.5

-- Backpack Checkpoint — wave structure
-- 3 escalating waves per BACKPACK_CHECKPOINT_PRD_V1_POLISHED.md.
Constants.BACKPACK_WAVE_COUNT = 3
Constants.BACKPACK_ITEMS_PER_WAVE = { 6, 8, 10 }
Constants.BACKPACK_BELT_SPEED_PER_WAVE = { 6, 8, 10 }   -- studs/sec; A5 placeholder
Constants.BACKPACK_SCANS_PER_WAVE = { 9, 12, 15 }       -- addendum default: ceil(items*1.5)
Constants.BACKPACK_FALLOFF_SECONDS = 12                 -- on-belt time before fall-off
Constants.BACKPACK_BOUNCE_BACK_FRACTION = 0.25          -- bounce teleports item back by this fraction
Constants.BACKPACK_PIXEL_POST_INTRO_SECONDS = 5         -- P0 non-gating intro slide
-- Legacy: kept so old call-sites don't crash if referenced during refactor.
Constants.BACKPACK_ITEM_COUNT = 6 + 8 + 10
Constants.BIN_RADIUS_STUDS = 10
Constants.ITEM_PICKUP_RADIUS_STUDS = 10
Constants.CONVEYOR_ITEM_TIMEOUT_SECONDS = 45

-- Rate limit windows (seconds)
Constants.RATE_LIMIT_INSPECT = 0.5
Constants.RATE_LIMIT_TALK = 1.5
Constants.RATE_LIMIT_ANNOTATE = 0.25
Constants.RATE_LIMIT_PICKUP = 0.5
Constants.RATE_LIMIT_PLACE = 0.5
Constants.RATE_LIMIT_INVITE = 1.0
Constants.RATE_LIMIT_SCAN = 0.5
Constants.RATE_LIMIT_HIGHLIGHT = 0.25
Constants.RATE_LIMIT_UNLOCK_LANE = 0.25
Constants.RATE_LIMIT_DISMISS_INTRO = 0.5

-- Score
Constants.LEVEL_COMPLETION_BONUS = 500
Constants.MAX_TIME_BONUS = 300
Constants.MISTAKE_PENALTY = 50
Constants.TRUST_POINTS_PER_CLUE = 100
Constants.TRUST_POINTS_PER_CORRECT_SORT = 75
Constants.TRUST_STREAK_BONUS = 25
Constants.PERFECT_LEVEL_BONUS = 250

-- Trust Seeds
Constants.SEEDS_BASE_FINISH = 3
Constants.SEEDS_BONUS_GOLD = 4
Constants.SEEDS_BONUS_PERFECT = 6
Constants.SEEDS_BONUS_PER_PERFECT_LEVEL = 1

-- Map object names (these are the *expected* names; tags do the heavy lifting)
Constants.STRANGER_DANGER_LEVEL_NAME = "StrangerDangerPark"
Constants.BACKPACK_CHECKPOINT_LEVEL_NAME = "BackpackCheckpoint"
Constants.DEFAULT_BOOTH_NAME = "DefaultBooth"

-- Folder names within slots
Constants.SLOT_PLAY_AREA_FOLDER = "PlayArea"
Constants.SLOT_BOOTH_FOLDER = "Booth"

-- Folder names for remote registry
Constants.REMOTE_FOLDER_NAME = "BuddyBridgeRemotes"

return Constants
