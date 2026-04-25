--!strict
-- Level type enum and the canonical sequence for the MVP demo.

local LevelTypes = {
	StrangerDangerPark = "StrangerDangerPark",
	BackpackCheckpoint = "BackpackCheckpoint",
}

LevelTypes.DemoSequence = {
	LevelTypes.StrangerDangerPark,
	LevelTypes.BackpackCheckpoint,
}

function LevelTypes.IsValid(levelType: string?): boolean
	return levelType == LevelTypes.StrangerDangerPark or levelType == LevelTypes.BackpackCheckpoint
end

return LevelTypes
