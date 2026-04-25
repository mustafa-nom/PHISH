--!strict
-- Level orchestrator. Dispatches to per-level submodules and owns the
-- start/complete/cleanup lifecycle for the active level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local PlayAreaService = require(Services:WaitForChild("PlayAreaService"))
local ScenarioService = require(Services:WaitForChild("ScenarioService"))
local ScoringService = require(Services:WaitForChild("ScoringService"))

local Levels = Services:WaitForChild("Levels")
local StrangerDangerLevel = require(Levels:WaitForChild("StrangerDangerLevel"))
local BackpackCheckpointLevel = require(Levels:WaitForChild("BackpackCheckpointLevel"))

local LevelService = {}

local roundEnder: ((any, string?) -> ())? = nil

function LevelService.SetRoundEnder(fn)
	roundEnder = fn
end

local function fetchLevelModel(round, levelType: string): Model?
	local slot = PlayAreaService.GetSlotForRound(round)
	if not slot then
		return nil
	end
	local playArea = slot:FindFirstChild("PlayArea")
	if not playArea then
		return nil
	end
	for _, child in ipairs(playArea:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("LevelType") == levelType then
			return child
		end
	end
	return nil
end

function LevelService.StartLevel(round, levelType: string): boolean
	if not round or not round.IsActive then
		return false
	end
	local levelModel = fetchLevelModel(round, levelType)
	if not levelModel then
		warn(("LevelService: level model %s missing"):format(levelType))
		return false
	end

	local scenario
	if levelType == LevelTypes.StrangerDangerPark then
		scenario = ScenarioService.GenerateStrangerDangerScenario(levelModel)
	elseif levelType == LevelTypes.BackpackCheckpoint then
		scenario = ScenarioService.GenerateBackpackCheckpointScenario(levelModel)
	else
		warn("LevelService: unknown level type " .. tostring(levelType))
		return false
	end

	if not scenario then
		warn(("LevelService: scenario generation failed for %s"):format(levelType))
		return false
	end

	round.ActiveScenario = scenario
	round.LevelStartedAt = os.clock()
	round.ItemsSorted = 0
	round.LastInspectedNpcId = nil
	round.ActiveItemId = nil
	ScoringService.NoteLevelStart(round, levelType)

	-- Teleport Explorer to the new level entry
	PlayAreaService.TeleportToLevelEntry(round, levelType)

	local started = false
	if levelType == LevelTypes.StrangerDangerPark then
		started = StrangerDangerLevel.Begin(round, scenario)
	elseif levelType == LevelTypes.BackpackCheckpoint then
		started = BackpackCheckpointLevel.Begin(round, scenario)
	end

	if not started then
		return false
	end

	RemoteService.FirePair(round, "LevelStarted", {
		RoundId = round.RoundId,
		LevelType = levelType,
		Index = round.CurrentLevelIndex,
		TotalLevels = #round.LevelSequence,
		Scenario = LevelService.PublicScenarioPayload(scenario),
	})

	return true
end

function LevelService.PublicScenarioPayload(scenario)
	-- Don't ship NPC roles or correct lanes to the Explorer client.
	-- The client only needs ids + display info; the manual is delivered
	-- separately to the Guide.
	if not scenario then
		return nil
	end
	if scenario.Type == LevelTypes.StrangerDangerPark then
		local npcs = {}
		for _, npc in ipairs(scenario.Npcs) do
			table.insert(npcs, {
				Id = npc.Id,
				SpawnPointId = npc.SpawnPointId,
				Anchor = npc.Anchor,
			})
		end
		return {
			Type = scenario.Type,
			Npcs = npcs,
			TotalAccusationSlots = 3,
		}
	elseif scenario.Type == LevelTypes.BackpackCheckpoint then
		return {
			Type = scenario.Type,
			Total = scenario.TotalItems,
			WaveCount = scenario.Waves and #scenario.Waves or 0,
		}
	end
	return nil
end

function LevelService.CompleteLevel(round, levelType: string)
	if not round or not round.IsActive then
		return
	end
	if round.ActiveScenario and round.ActiveScenario.Type ~= levelType then
		return
	end
	ScoringService.NoteLevelComplete(round, levelType)
	table.insert(round.CompletedLevels, levelType)

	local summary = {
		RoundId = round.RoundId,
		LevelType = levelType,
		AttemptsLeft = round.AttemptsLeft,
		ItemsSorted = round.ItemsSorted,
		Mistakes = (round.LevelState[levelType] and round.LevelState[levelType].Mistakes) or 0,
		Elapsed = (round.LevelState[levelType] and round.LevelState[levelType].Elapsed) or 0,
	}
	RemoteService.FirePair(round, "LevelEnded", summary)

	-- Cleanup level-specific state
	if levelType == LevelTypes.StrangerDangerPark then
		StrangerDangerLevel.Cleanup(round)
	elseif levelType == LevelTypes.BackpackCheckpoint then
		BackpackCheckpointLevel.Cleanup(round)
	end

	round.ActiveScenario = nil
	round.CurrentLevelIndex += 1

	if round.CurrentLevelIndex > #round.LevelSequence then
		-- All levels complete; let RoundService finalize.
		if roundEnder then
			roundEnder(round, "Completed")
		end
		return
	end

	local nextLevel = round.LevelSequence[round.CurrentLevelIndex]
	task.wait(0.5)
	LevelService.StartLevel(round, nextLevel)
end

function LevelService.CleanupForRound(round)
	StrangerDangerLevel.Cleanup(round)
	BackpackCheckpointLevel.Cleanup(round)
end

function LevelService.Init()
	-- No remote handlers — driven by the interaction services and round
	-- service. Cross-module coordination via SetRoundEnder.
end

return LevelService
