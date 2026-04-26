--!strict
-- Level-up notifications and cosmetic boat color application.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local Progression = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Progression"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local LevelService = {}

local function bestActiveLevel(): number
	local best = 1
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(player)
		best = math.max(best, Progression.GetLevelForXp(profile.xp))
	end
	return best
end

local function applySkinToHull(hull: Instance, skin: Progression.BoatSkin)
	if not hull:IsA("BasePart") then return end
	hull.Color = skin.color
	hull:SetAttribute("BoatSkinId", skin.id)
	hull:SetAttribute("BoatSkinName", skin.name)
end

function LevelService.ApplyBoatColors()
	local skin = Progression.GetBoatSkinForLevel(bestActiveLevel())
	for _, hull in ipairs(CollectionService:GetTagged(PhishConstants.Tags.BoatHull)) do
		applySkinToHull(hull, skin)
	end
end

function LevelService.HandleXpChanged(player: Player, oldXp: number, newXp: number): { [string]: any }
	local oldInfo = Progression.GetLevelInfo(oldXp)
	local newInfo = Progression.GetLevelInfo(newXp)
	local leveledUp = newInfo.level > oldInfo.level

	if leveledUp then
		LevelService.ApplyBoatColors()
		RemoteService.FireClient(player, "Notify", {
			kind = "Success",
			message = string.format("Level %d! Boat color unlocked: %s.", newInfo.level, newInfo.boatSkin.name),
			duration = 4,
		})
	end

	return {
		leveledUp = leveledUp,
		level = newInfo.level,
		boatSkinName = newInfo.boatSkin.name,
	}
end

function LevelService.Init()
	LevelService.ApplyBoatColors()
	CollectionService:GetInstanceAddedSignal(PhishConstants.Tags.BoatHull):Connect(function(hull)
		applySkinToHull(hull, Progression.GetBoatSkinForLevel(bestActiveLevel()))
	end)
	Players.PlayerAdded:Connect(function()
		task.defer(LevelService.ApplyBoatColors)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(LevelService.ApplyBoatColors)
	end)
end

return LevelService
