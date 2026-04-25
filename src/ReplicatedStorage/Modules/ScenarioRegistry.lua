--!strict
-- Convenience re-exports for client controllers that need to look up
-- trait/item display info without pulling NpcRegistry / ItemRegistry directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local NpcRegistry = require(Modules:WaitForChild("NpcRegistry"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))

local ScenarioRegistry = {}

function ScenarioRegistry.GetTraitDisplay(tag: string): string
	local info = NpcRegistry.Traits[tag]
	if info then
		return info.DisplayText
	end
	return tag
end

function ScenarioRegistry.GetTraitRisk(tag: string): string?
	local info = NpcRegistry.Traits[tag]
	if info then
		return info.Risk
	end
	return nil
end

function ScenarioRegistry.GetItemDisplay(key: string): string
	local info = ItemRegistry.GetItem(key)
	if info then
		return info.DisplayLabel
	end
	return key
end

function ScenarioRegistry.GetItemCorrectLane(key: string): string?
	local info = ItemRegistry.GetItem(key)
	if info then
		return info.CorrectLane
	end
	return nil
end

return ScenarioRegistry
