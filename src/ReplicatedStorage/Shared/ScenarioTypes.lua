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

export type StrangerDangerNpc = {
	Id: string,
	SpawnPointId: string,
	Anchor: string?,
	Archetype: string,             -- NPC template name (HotDogVendor, etc.)
	Role: string,                  -- Risky | SafeWithClue | SafeNoClue
	Silhouette: StrangerDangerSilhouette,  -- Explorer-visible glance
	Cues: { string },              -- Guide-visible cue tags (full info)
	Verdict: string,               -- canonical Approach/AskFirst/Avoid
	Fragment: StrangerDangerFragment?,  -- truthful or misleading clue
	Bark: string?,                 -- chat-bubble line
	-- Legacy fields for backwards compatibility with existing renderers:
	Traits: { string },            -- mirrors Cues for older callers
	ClueText: string?,             -- mirrors Fragment.Text for older callers
}

export type StrangerDangerScenario = {
	Type: string,
	PuppySpawnId: string,
	PuppyLandmark: string,         -- the truthful landmark fragments point to
	Npcs: { StrangerDangerNpc },
	GuideManual: {
		RiskyTags: { string },
		SafeTags: { string },
	},
	Annotations: { [string]: string },
}

export type BackpackItem = {
	Id: string,
	ItemKey: string,
	DisplayLabel: string,
	CorrectLane: string,
}

export type BackpackCheckpointScenario = {
	Type: string,
	ItemSequence: { BackpackItem },
	GuideManual: {
		Lanes: {
			PackIt: { string },
			AskFirst: { string },
			LeaveIt: { string },
		},
	},
	Annotations: { [string]: string },
	CurrentItemIndex: number,
}

ScenarioTypes.NpcRoles = {
	SafeWithClue = "SafeWithClue",
	SafeNoClue = "SafeNoClue",
	Risky = "Risky",
}

ScenarioTypes.AnnotationMarkers = {
	Safe = "Safe",
	Risky = "Risky",
	AskFirst = "AskFirst",
	Clear = "Clear",
}

function ScenarioTypes.IsValidNpcRole(role: string?): boolean
	return role == ScenarioTypes.NpcRoles.SafeWithClue
		or role == ScenarioTypes.NpcRoles.SafeNoClue
		or role == ScenarioTypes.NpcRoles.Risky
end

function ScenarioTypes.IsValidAnnotationMarker(marker: string?): boolean
	return marker == ScenarioTypes.AnnotationMarkers.Safe
		or marker == ScenarioTypes.AnnotationMarkers.Risky
		or marker == ScenarioTypes.AnnotationMarkers.AskFirst
		or marker == ScenarioTypes.AnnotationMarkers.Clear
end

return ScenarioTypes
