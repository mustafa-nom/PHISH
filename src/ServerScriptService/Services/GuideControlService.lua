--!strict
-- Guide-side remote handlers: NPC and item annotations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local ScenarioTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScenarioTypes"))

local Services = script.Parent
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local GuideControlService = {}

local function findNpcInScenario(scenario, npcId: string)
	if not scenario or not scenario.Npcs then
		return nil
	end
	for _, npc in ipairs(scenario.Npcs) do
		if npc.Id == npcId then
			return npc
		end
	end
	return nil
end

local function findItemInScenario(scenario, itemId: string)
	if not scenario or not scenario.ItemSequence then
		return nil
	end
	for _, item in ipairs(scenario.ItemSequence) do
		if item.Id == itemId then
			return item
		end
	end
	return nil
end

local function handleAnnotateNpc(player: Player, npcId: string, marker: string)
	if typeof(npcId) ~= "string" or typeof(marker) ~= "string" then return end
	if not ScenarioTypes.IsValidAnnotationMarker(marker) then return end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireGuide(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.StrangerDangerPark)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestAnnotateNpc:" .. npcId, Constants.RATE_LIMIT_ANNOTATE)
	if not okRate then return end

	local scenario = round.ActiveScenario
	if not findNpcInScenario(scenario, npcId) then return end

	scenario.Annotations[npcId] = marker
	RemoteService.FirePair(round, "NpcAnnotationUpdated", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Marker = marker,
	})
end

local function handleAnnotateItem(player: Player, itemId: string, lane: string)
	if typeof(itemId) ~= "string" or typeof(lane) ~= "string" then return end
	if not ItemRegistry.IsValidLane(lane) and lane ~= ScenarioTypes.AnnotationMarkers.Clear then
		return
	end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireGuide(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.BackpackCheckpoint)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestAnnotateItem:" .. itemId, Constants.RATE_LIMIT_ANNOTATE)
	if not okRate then return end

	local scenario = round.ActiveScenario
	if not findItemInScenario(scenario, itemId) then return end

	scenario.Annotations[itemId] = lane
	RemoteService.FirePair(round, "ItemAnnotationUpdated", {
		RoundId = round.RoundId,
		ItemId = itemId,
		Lane = lane,
	})
end

function GuideControlService.Init()
	RemoteService.OnServerEvent("RequestAnnotateNpc", handleAnnotateNpc)
	RemoteService.OnServerEvent("RequestAnnotateItem", handleAnnotateItem)
end

return GuideControlService
