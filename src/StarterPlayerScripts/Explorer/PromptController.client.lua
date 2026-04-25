--!strict
-- Filters ProximityPrompts based on the local player's role:
-- non-Explorers should not see Explorer-only prompts (NPC inspect, bin drop).
-- Server-side rejects them anyway; this is purely visual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))

local currentRole = RoleTypes.None

local function refreshPromptVisibility()
	for _, instance in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.BuddyNpcSpawn)) do
		local parent = instance.Parent
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child:IsA("Model") then
					for _, descendant in ipairs(child:GetDescendants()) do
						if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("BB_NpcId") then
							descendant.Enabled = currentRole == RoleTypes.Explorer
						end
					end
				end
			end
		end
	end
	for _, bin in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.BuddyBin)) do
		for _, descendant in ipairs(bin:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("BB_LaneId") then
				descendant.Enabled = currentRole == RoleTypes.Explorer
			end
		end
	end
end

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	currentRole = payload.Role or RoleTypes.None
	refreshPromptVisibility()
end)

RemoteService.OnClientEvent("LevelStarted", function(_payload)
	-- New prompts may have just been added; re-apply.
	task.wait(0.5)
	refreshPromptVisibility()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	currentRole = RoleTypes.None
	refreshPromptVisibility()
end)

-- Light periodic refresh to catch dynamically-added prompts.
task.spawn(function()
	while true do
		task.wait(2)
		refreshPromptVisibility()
	end
end)
