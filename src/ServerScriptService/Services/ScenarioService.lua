--!strict
-- Orchestrator that dispatches scenario generation to per-level submodules.

local Scenarios = script.Parent:WaitForChild("Scenarios")
local StrangerDangerScenario = require(Scenarios:WaitForChild("StrangerDangerScenario"))
local BackpackCheckpointScenario = require(Scenarios:WaitForChild("BackpackCheckpointScenario"))

local ScenarioService = {}

function ScenarioService.GenerateStrangerDangerScenario(levelModel: Model)
	return StrangerDangerScenario.Generate(levelModel)
end

function ScenarioService.GenerateBackpackCheckpointScenario(levelModel: Model?)
	return BackpackCheckpointScenario.Generate(levelModel)
end

function ScenarioService.Init()
	-- Stateless module.
end

return ScenarioService
