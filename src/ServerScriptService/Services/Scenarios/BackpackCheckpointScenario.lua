--!strict
-- Generates a 3-wave randomized item rotation for Backpack Checkpoint.
--
-- Per BACKPACK_CHECKPOINT_PRD_V1_POLISHED.md the wave structure is:
--   Wave 1: warm-up (Tier 1 only)
--   Wave 2: mixed traffic (Tier 1-2)
--   Wave 3: rush hour (all tiers, including Tier 3)
-- Item count and belt speed escalate per wave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))

local ScenarioTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScenarioTypes"))

local BackpackCheckpointScenario = {}

local function shuffle<T>(list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = math.random(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Pick `count` item keys for a wave with the given tier ceiling. Round-robin
-- across lanes so every wave is balanced. `usedKeys` is mutated so each item
-- type only appears once per round.
local function pickWaveItems(count: number, maxTier: number, usedKeys: { [string]: boolean }): { string }
	local lanes = { ItemRegistry.Lanes.PackIt, ItemRegistry.Lanes.AskFirst, ItemRegistry.Lanes.LeaveIt }
	local picked: { string } = {}
	local laneIdx = 1
	local laneOrder = shuffle(lanes)
	while #picked < count do
		local lane = laneOrder[((laneIdx - 1) % #laneOrder) + 1]
		local available: { string } = {}
		for _, key in ipairs(ItemRegistry.GetKeysForLaneUpToTier(lane, maxTier)) do
			if not usedKeys[key] then
				table.insert(available, key)
			end
		end
		if #available > 0 then
			local pick = available[math.random(#available)]
			usedKeys[pick] = true
			table.insert(picked, pick)
		end
		laneIdx += 1
		-- Safety break: if the registry is exhausted, stop.
		if laneIdx > count * 4 then
			break
		end
	end
	return shuffle(picked)
end

local function makeBackpackItem(id: string, key: string): ScenarioTypes.BackpackItem
	local info = ItemRegistry.GetItem(key)
	assert(info, "BackpackCheckpointScenario: unknown item key " .. tostring(key))
	return {
		Id = id,
		ItemKey = key,
		DisplayLabel = info.DisplayLabel,
		CorrectLane = info.CorrectLane,
		Category = info.Category,
		DifficultyTier = info.DifficultyTier,
		ScanTags = info.ScanTags,
	}
end

function BackpackCheckpointScenario.Generate(levelModel: Model?): ScenarioTypes.BackpackCheckpointScenario
	local _ = levelModel

	-- Tier ceilings per wave: Wave 1 = 1, Wave 2 = 2, Wave 3 = 3.
	local waveTierCeilings = { 1, 2, 3 }

	local usedKeys: { [string]: boolean } = {}
	local waves: { ScenarioTypes.BackpackWave } = {}
	local totalItems = 0
	local globalIdCounter = 0

	for waveIndex = 1, Constants.BACKPACK_WAVE_COUNT do
		local count = Constants.BACKPACK_ITEMS_PER_WAVE[waveIndex]
		local maxTier = waveTierCeilings[waveIndex] or 3
		local keys = pickWaveItems(count, maxTier, usedKeys)
		local items: { ScenarioTypes.BackpackItem } = {}
		for _, key in ipairs(keys) do
			globalIdCounter += 1
			table.insert(items, makeBackpackItem(string.format("item_%d", globalIdCounter), key))
		end
		totalItems += #items
		table.insert(waves, {
			WaveIndex = waveIndex,
			Items = items,
			BeltSpeed = Constants.BACKPACK_BELT_SPEED_PER_WAVE[waveIndex] or 6,
			ScansAllowed = Constants.BACKPACK_SCANS_PER_WAVE[waveIndex] or 9,
		})
	end

	local manualLanes = {
		PackIt = ItemRegistry.GetKeysForLane(ItemRegistry.Lanes.PackIt),
		AskFirst = ItemRegistry.GetKeysForLane(ItemRegistry.Lanes.AskFirst),
		LeaveIt = ItemRegistry.GetKeysForLane(ItemRegistry.Lanes.LeaveIt),
	}

	local scenario: ScenarioTypes.BackpackCheckpointScenario = {
		Type = LevelTypes.BackpackCheckpoint,
		Waves = waves,
		GuideManual = { Lanes = manualLanes },
		CurrentWaveIndex = 0,
		CurrentItemIndex = 0,
		TotalItems = totalItems,
	}
	return scenario
end

return BackpackCheckpointScenario
