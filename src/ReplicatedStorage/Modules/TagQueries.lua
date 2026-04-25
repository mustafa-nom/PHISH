--!strict
-- Centralized CollectionService queries scoped to a slot or level instance.
-- This avoids hardcoded paths and prevents cross-slot leakage when 4 duos
-- run simultaneously.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))

local TagQueries = {}

local function isDescendantOf(instance: Instance, ancestor: Instance): boolean
	return instance == ancestor or instance:IsDescendantOf(ancestor)
end

-- Find every instance with `tag` whose ancestor is `root`.
function TagQueries.GetTaggedInside(root: Instance, tag: string): { Instance }
	local result = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if isDescendantOf(instance, root) then
			table.insert(result, instance)
		end
	end
	return result
end

-- Find the first instance with `tag` whose ancestor is `root`. Returns nil
-- if not found.
function TagQueries.FirstTaggedInside(root: Instance, tag: string): Instance?
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if isDescendantOf(instance, root) then
			return instance
		end
	end
	return nil
end

-- Get the PlayArenaSlots root (Workspace/PlayArenaSlots).
function TagQueries.GetPlayArenaSlotsRoot(): Folder?
	return Workspace:FindFirstChild("PlayArenaSlots") :: Folder?
end

-- Iterate slot models in deterministic order by SlotIndex attribute.
function TagQueries.GetSortedSlots(): { Model }
	local slots = {}
	for _, instance in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.PlayArenaSlot)) do
		if instance:IsA("Model") then
			table.insert(slots, instance)
		end
	end
	table.sort(slots, function(a, b)
		local aIdx = a:GetAttribute(PlayAreaConfig.Attributes.SlotIndex)
		local bIdx = b:GetAttribute(PlayAreaConfig.Attributes.SlotIndex)
		if typeof(aIdx) == "number" and typeof(bIdx) == "number" then
			return aIdx < bIdx
		end
		return a.Name < b.Name
	end)
	return slots
end

function TagQueries.GetSlotByIndex(index: number): Model?
	for _, slot in ipairs(TagQueries.GetSortedSlots()) do
		if slot:GetAttribute(PlayAreaConfig.Attributes.SlotIndex) == index then
			return slot
		end
	end
	return nil
end

-- Find a level model inside a slot by LevelType attribute.
function TagQueries.GetLevelInSlot(slot: Model, levelType: string): Model?
	local playArea = slot:FindFirstChild(PlayAreaConfig.Tags.PlayArenaSlot == "PlayArenaSlot" and "PlayArea" or "PlayArea")
	if not playArea then
		return nil
	end
	for _, child in ipairs(playArea:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute(PlayAreaConfig.Attributes.LevelType) == levelType then
			return child
		end
	end
	return nil
end

-- Find a bin part inside a level by LaneId attribute.
function TagQueries.GetBinByLane(level: Instance, laneId: string): BasePart?
	for _, part in ipairs(TagQueries.GetTaggedInside(level, PlayAreaConfig.Tags.BuddyBin)) do
		if part:IsA("BasePart") and part:GetAttribute(PlayAreaConfig.Attributes.LaneId) == laneId then
			return part
		end
	end
	return nil
end

-- Find an NPC spawn part inside a level by NpcSpawnId attribute.
function TagQueries.GetNpcSpawnById(level: Instance, npcSpawnId: string): BasePart?
	for _, part in ipairs(TagQueries.GetTaggedInside(level, PlayAreaConfig.Tags.BuddyNpcSpawn)) do
		if part:IsA("BasePart") and part:GetAttribute(PlayAreaConfig.Attributes.NpcSpawnId) == npcSpawnId then
			return part
		end
	end
	return nil
end

-- Find a capsule pad in lobby by CapsuleId attribute.
function TagQueries.GetCapsuleById(capsuleId: string): BasePart?
	for _, part in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.LobbyCapsule)) do
		if part:IsA("BasePart") and part:GetAttribute(PlayAreaConfig.Attributes.CapsuleId) == capsuleId then
			return part
		end
	end
	return nil
end

return TagQueries
