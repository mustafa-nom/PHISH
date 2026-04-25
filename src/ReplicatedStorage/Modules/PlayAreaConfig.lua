--!strict
-- Play arena slot layout config.

local PlayAreaConfig = {}

-- Distance between StrangerDangerPark and BackpackCheckpoint inside a slot.
-- Each level template is roughly 80x80 / 40x40 studs, so 140 studs between
-- their PrimaryParts is plenty of headroom.
PlayAreaConfig.LEVEL_SPACING_STUDS = 140

-- Vertical fall-through guard for booth: if Guide somehow exits the booth
-- bounding box, teleport them back. Heartbeat-based check.
PlayAreaConfig.BOOTH_LOCK_PADDING_STUDS = 4

-- After round end, wait a beat before destroying clones so post-round UI
-- effects can finish. Keep this tiny — slots are scarce.
PlayAreaConfig.CLEANUP_DELAY_SECONDS = 0.5

-- Tag names. Keep in sync with the user1_map_prompt.md and
-- docs/TECHNICAL_DESIGN.md "Map Object Conventions" section.
PlayAreaConfig.Tags = {
	LobbyCapsule = "LobbyCapsule",
	PlayArenaSlot = "PlayArenaSlot",
	ExplorerSpawn = "ExplorerSpawn",
	GuideSpawn = "GuideSpawn",
	BoothAnchor = "BoothAnchor",
	LevelEntry = "LevelEntry",
	LevelExit = "LevelExit",
	BuddyNpcSpawn = "BuddyNpcSpawn",
	PuppySpawn = "PuppySpawn",
	BuddyConveyor = "BuddyConveyor",
	BuddyBin = "BuddyBin",
	BuddyPortal = "BuddyPortal",
	RoundFinishZone = "RoundFinishZone",
	BeltStart = "BeltStart",
	BeltEnd = "BeltEnd",
}

PlayAreaConfig.Attributes = {
	LevelType = "LevelType",
	CapsuleId = "CapsuleId",
	CapsulePairId = "CapsulePairId",
	SlotIndex = "SlotIndex",
	NpcSpawnId = "NpcSpawnId",
	LaneId = "LaneId",
	Anchor = "Anchor",
}

return PlayAreaConfig
