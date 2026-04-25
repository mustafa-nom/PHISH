--!strict
-- Backpack Checkpoint wave runner.
--
-- Owns the 3-wave structure described in BACKPACK_CHECKPOINT_PRD_V1_POLISHED.md:
--   * starts wave N (fires WaveStarted, resets per-wave scanner caps)
--   * after each item is resolved, decides whether to spawn the next item or
--     finish the wave
--   * finishes the wave (fires WaveEnded), increments wave index
--   * when the last wave finishes, asks LevelService to complete the level
--
-- Per the addendum's wave-drain rule (edge case 9), a wave only ends when its
-- last item has been resolved (sorted, fallen off, or — in P1 — bounced and
-- re-resolved). The current item count is the schedule, not a wall-clock timer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local BeltController = require(script.Parent:WaitForChild("BeltController"))

local WaveDirector = {}

local function getState(round)
	round.LevelState[LevelTypes.BackpackCheckpoint] = round.LevelState[LevelTypes.BackpackCheckpoint] or {}
	return round.LevelState[LevelTypes.BackpackCheckpoint]
end

local function startWave(round, scenario, waveIndex: number, onLevelComplete: () -> ())
	local wave = scenario.Waves[waveIndex]
	if not wave then
		onLevelComplete()
		return
	end
	scenario.CurrentWaveIndex = waveIndex
	scenario.CurrentItemIndex = 1
	local state = getState(round)
	state.ScansUsedThisWave = 0
	RemoteService.FirePair(round, "WaveStarted", {
		RoundId = round.RoundId,
		WaveIndex = waveIndex,
		ItemCount = #wave.Items,
		BeltSpeed = wave.BeltSpeed,
		ScansAllowed = wave.ScansAllowed,
	})

	local function onResolved(_reason: string)
		WaveDirector.OnItemResolved(round, scenario, onLevelComplete)
	end

	local first = wave.Items[1]
	if first then
		BeltController.SpawnItem(round, scenario, first, waveIndex, 1, #wave.Items, onResolved)
	else
		-- Empty wave (shouldn't happen) → fast-forward.
		WaveDirector.FinishWave(round, scenario, onLevelComplete)
	end
end

function WaveDirector.OnItemResolved(round, scenario, onLevelComplete: () -> ())
	if not round.IsActive then return end
	if scenario ~= round.ActiveScenario then return end
	scenario.CurrentItemIndex += 1
	local wave = scenario.Waves[scenario.CurrentWaveIndex]
	if not wave then
		onLevelComplete()
		return
	end
	if scenario.CurrentItemIndex > #wave.Items then
		WaveDirector.FinishWave(round, scenario, onLevelComplete)
		return
	end
	local nextItem = wave.Items[scenario.CurrentItemIndex]
	local function onResolved(_reason: string)
		WaveDirector.OnItemResolved(round, scenario, onLevelComplete)
	end
	BeltController.SpawnItem(
		round,
		scenario,
		nextItem,
		scenario.CurrentWaveIndex,
		scenario.CurrentItemIndex,
		#wave.Items,
		onResolved
	)
end

function WaveDirector.FinishWave(round, scenario, onLevelComplete: () -> ())
	local waveIndex = scenario.CurrentWaveIndex
	RemoteService.FirePair(round, "WaveEnded", {
		RoundId = round.RoundId,
		WaveIndex = waveIndex,
	})
	local nextWaveIndex = waveIndex + 1
	if nextWaveIndex > #scenario.Waves then
		onLevelComplete()
		return
	end
	-- Brief breather between waves so the HUD can play a transition.
	task.delay(0.5, function()
		if not round.IsActive then return end
		if scenario ~= round.ActiveScenario then return end
		startWave(round, scenario, nextWaveIndex, onLevelComplete)
	end)
end

function WaveDirector.Begin(round, scenario, onLevelComplete: () -> ())
	startWave(round, scenario, 1, onLevelComplete)
end

return WaveDirector
