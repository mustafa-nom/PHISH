--!strict
-- Gameplay tunings for PHISH. Centralized so writers can rebalance without
-- chasing magic numbers through services.

local PhishConstants = {}

-- Casting / biting
PhishConstants.CAST_RANGE_STUDS = 80         -- max distance from CastAnchor
PhishConstants.BITE_MIN_WAIT_SECONDS = 2.0
PhishConstants.BITE_MAX_WAIT_SECONDS = 5.0
PhishConstants.BITE_TIMEOUT_SECONDS = 8.0    -- player has this long to start reeling

-- Reel: one deliberate "reel in" after a bite (was 3 generic taps; see ReelController UI)
PhishConstants.REEL_TAPS_REQUIRED = 1
PhishConstants.REEL_WINDOW_SECONDS = 6.0

-- Decision window
PhishConstants.DECISION_TIMER_SECONDS = 0    -- 0 = unlimited (Easy mode)
PhishConstants.DECISION_HARD_TIMER_SECONDS = 5

-- Rewards
PhishConstants.REWARD_CORRECT_XP = 15
PhishConstants.REWARD_CORRECT_COINS = 5
PhishConstants.REWARD_LEGIT_KEEP_COINS = 3
PhishConstants.REWARD_WRONG_PENALTY_COINS = 0  -- never go negative for kids
PhishConstants.REWARD_DIFFICULTY_BONUS = 5     -- +5 per difficulty tier above 1

-- Roles
PhishConstants.COAST_GUARD_MIN_CATCHES = 50
PhishConstants.COAST_GUARD_MIN_ACCURACY = 0.80
PhishConstants.HARBOR_MASTER_ROTATION_SECONDS = 300

-- Boss
PhishConstants.PHISHERMAN_INTERVAL_SECONDS = 420   -- 7 minutes
PhishConstants.PHISHERMAN_DEFEAT_REQUIREMENTS = 3  -- correct catches to defeat

-- Phish-Dex
PhishConstants.DEFAULT_CATCHES_TO_UNLOCK = 3

-- Rate limits (seconds per call per player)
PhishConstants.RATE_LIMIT_CAST = 0.8
PhishConstants.RATE_LIMIT_REEL_TAP = 0.05
PhishConstants.RATE_LIMIT_DECISION = 0.4
PhishConstants.RATE_LIMIT_ROD = 1.0
PhishConstants.RATE_LIMIT_DEX = 0.5

-- Tags from User 1's map (single source: prompts/user1_map_prompt.md)
PhishConstants.Tags = {
	LodgeSpawn = "PhishLodgeSpawn",
	CastZone = "PhishCastZone",
	WaterZone = "PhishWaterZone",
	FishTemplate = "PhishFishTemplate",
	AquariumDisplay = "PhishAquariumDisplay",
	ShopTrigger = "PhishShopTrigger",
	BoatHull = "PhishBoatHull",
	BoatSeat = "PhishBoatSeat",
	NpcAngler = "PhishNpcAngler",
	BoardOfFame = "PhishBoardOfFame",
	PhishermanSpawn = "PhishermanSpawn",
}

return PhishConstants
