--!strict
-- Scenario shape definitions. Matches docs/TECHNICAL_DESIGN.md "Scenario Shapes".

local ScenarioTypes = {}

export type StrangerDangerSilhouette = {
	Headline: string,
	Outline: string,
	AccentColor: { number },
	Stance: string,
}

export type StrangerDangerFragment = {
	Truthful: boolean,
	Landmark: string,
	Text: string,
}

export type StrangerDangerBadge = {
	Color: string,
	Shape: string,
}

export type StrangerDangerNpc = {
	Id: string,
	SpawnPointId: string,
	Anchor: string?,
	Archetype: string,             -- NPC template name (HotDogVendor, etc.)
	Role: string,                  -- Risky | Safe
	Silhouette: StrangerDangerSilhouette,  -- Explorer-visible glance
	Cue: string,                   -- behavior cue revealed on inspect
	Badge: StrangerDangerBadge,
	Cues: { string },              -- legacy mirror for manual highlighting
	Verdict: string,               -- canonical Approach/AskFirst/Avoid
	Bark: string?,                 -- chat-bubble line
	Traits: { string },            -- mirrors Cues for older callers
}

export type StrangerDangerScenario = {
	Type: string,
	Npcs: { StrangerDangerNpc },
	AnswerBadges: { StrangerDangerBadge },
	GuideManual: {
		RiskyTags: { string },
		SafeTags: { string },
	},
}

export type BackpackItem = {
	Id: string,
	ItemKey: string,
	DisplayLabel: string,
	CorrectLane: string,
	Category: string?,
	DifficultyTier: number?,
	ScanTags: { string }?,
}

export type BackpackWave = {
	WaveIndex: number,
	Items: { BackpackItem },
	BeltSpeed: number,
	ScansAllowed: number,
}

export type BackpackCheckpointScenario = {
	Type: string,
	Waves: { BackpackWave },
	GuideManual: {
		Lanes: {
			PackIt: { string },
			AskFirst: { string },
			LeaveIt: { string },
		},
	},
	CurrentWaveIndex: number,
	CurrentItemIndex: number,
	TotalItems: number,
}

ScenarioTypes.NpcRoles = {
	Safe = "Safe",
	Risky = "Risky",
}

ScenarioTypes.AnnotationMarkers = {
	Safe = "Safe",
	Risky = "Risky",
	AskFirst = "AskFirst",
	Clear = "Clear",
}

function ScenarioTypes.IsValidNpcRole(role: string?): boolean
	return role == ScenarioTypes.NpcRoles.Safe or role == ScenarioTypes.NpcRoles.Risky
end

function ScenarioTypes.IsValidAnnotationMarker(marker: string?): boolean
	return marker == ScenarioTypes.AnnotationMarkers.Safe
		or marker == ScenarioTypes.AnnotationMarkers.Risky
		or marker == ScenarioTypes.AnnotationMarkers.AskFirst
		or marker == ScenarioTypes.AnnotationMarkers.Clear
end

return ScenarioTypes
