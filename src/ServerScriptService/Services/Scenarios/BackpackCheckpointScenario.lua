--!strict
-- Generates a randomized item rotation for Backpack Checkpoint.

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

local function pickItemsAcrossLanes(count: number): { string }
	local lanes = { ItemRegistry.Lanes.PackIt, ItemRegistry.Lanes.AskFirst, ItemRegistry.Lanes.LeaveIt }
	local picked: { string } = {}
	local usedKeys: { [string]: boolean } = {}
	-- Round-robin lanes to guarantee balance, then shuffle the order.
	local laneIdx = 1
	local laneOrder = shuffle(lanes)
	while #picked < count do
		local lane = laneOrder[((laneIdx - 1) % #laneOrder) + 1]
		local available: { string } = {}
		for _, key in ipairs(ItemRegistry.GetKeysForLane(lane)) do
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
		-- Safety break in the unlikely case all items are exhausted.
		if laneIdx > count * 4 then
			break
		end
	end
	return shuffle(picked)
end

function BackpackCheckpointScenario.Generate(levelModel: Model?): ScenarioTypes.BackpackCheckpointScenario
	local _ = levelModel
	local count = Constants.BACKPACK_ITEM_COUNT
	local keys = pickItemsAcrossLanes(count)
	local sequence: { ScenarioTypes.BackpackItem } = {}
	for i, key in ipairs(keys) do
		local info = ItemRegistry.GetItem(key)
		if info then
			table.insert(sequence, {
				Id = string.format("item_%d", i),
				ItemKey = key,
				DisplayLabel = info.DisplayLabel,
				CorrectLane = info.CorrectLane,
			})
		end
	end

	local manualLanes = {
		PackIt = ItemRegistry.GetKeysForLane(ItemRegistry.Lanes.PackIt),
		AskFirst = ItemRegistry.GetKeysForLane(ItemRegistry.Lanes.AskFirst),
		LeaveIt = ItemRegistry.GetKeysForLane(ItemRegistry.Lanes.LeaveIt),
	}

	local scenario: ScenarioTypes.BackpackCheckpointScenario = {
		Type = LevelTypes.BackpackCheckpoint,
		ItemSequence = sequence,
		GuideManual = { Lanes = manualLanes },
		Annotations = {},
		CurrentItemIndex = 0,
	}
	return scenario
end

return BackpackCheckpointScenario
