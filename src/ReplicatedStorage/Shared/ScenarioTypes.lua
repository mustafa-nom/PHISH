--!strict
-- Scenario shape definitions. Matches docs/TECHNICAL_DESIGN.md "Scenario Shapes".

local ScenarioTypes = {}

export type StrangerDangerNpc = {
	Id: string,
	SpawnPointId: string,
	Anchor: string?,
	Role: string,
	Traits: { string },
	ClueText: string?,
}

export type StrangerDangerScenario = {
	Type: string,
	PuppySpawnId: string,
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
