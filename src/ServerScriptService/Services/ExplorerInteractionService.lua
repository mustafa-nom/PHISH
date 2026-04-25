--!strict
-- Explorer-side remote handlers: NPC inspect, item pickup/place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))
local ScoringService = require(Services:WaitForChild("ScoringService"))
local PlayAreaService = require(Services:WaitForChild("PlayAreaService"))
local BackpackCheckpointLevel = require(Services:WaitForChild("Levels"):WaitForChild("BackpackCheckpointLevel"))

local ExplorerInteractionService = {}

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

local function findNpcModel(round, npcId: string): Model?
	local levelState = round.LevelState[LevelTypes.StrangerDangerPark]
	if not levelState or not levelState.NpcModels then
		return nil
	end
	return levelState.NpcModels[npcId]
end

local function getNpcRoot(model: Model?): BasePart?
	if not model then
		return nil
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function handleInspectNpc(player: Player, npcId: string)
	if typeof(npcId) ~= "string" then return end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireExplorer(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.StrangerDangerPark)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestInspectNpc", Constants.RATE_LIMIT_INSPECT)
	if not okRate then return end

	local npcInfo = findNpcInScenario(round.ActiveScenario, npcId)
	if not npcInfo then return end
	local root = getNpcRoot(findNpcModel(round, npcId))
	if not root then return end
	local okProx = RemoteValidation.RequireProximity(player, root, Constants.INSPECT_RADIUS_STUDS)
	if not okProx then return end

	round.LastInspectedNpcId = npcId
	RemoteService.FireClient(round.Explorer, "NpcDescriptionShown", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Audience = "Explorer",
		Archetype = npcInfo.Archetype,
		Silhouette = npcInfo.Silhouette,
		Cue = npcInfo.Cue,
		Badge = npcInfo.Badge,
	})
	RemoteService.FireClient(round.Guide, "NpcDescriptionShown", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Audience = "Guide",
		Archetype = npcInfo.Archetype,
		Cues = npcInfo.Cues,
		Cue = npcInfo.Cue,
		Badge = npcInfo.Badge,
		Silhouette = npcInfo.Silhouette,
	})
end

local function handlePickupItem(player: Player, itemId: string)
	if typeof(itemId) ~= "string" then return end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireExplorer(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.BackpackCheckpoint)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestPickupItem", Constants.RATE_LIMIT_PICKUP)
	if not okRate then return end
	if itemId ~= round.ActiveItemId then return end

	local model = BackpackCheckpointLevel.GetActiveItemModel(round)
	if not model then return end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root or not root:IsA("BasePart") then return end
	local okProx = RemoteValidation.RequireProximity(player, root, Constants.ITEM_PICKUP_RADIUS_STUDS)
	if not okProx then return end
	BackpackCheckpointLevel.MarkHeld(round, player)
end

local function findBackpackLevelModel(round): Model?
	local slot = PlayAreaService.GetSlotForRound(round)
	if not slot then return nil end
	local playArea = slot:FindFirstChild(Constants.SLOT_PLAY_AREA_FOLDER)
	if not playArea then return nil end
	for _, child in ipairs(playArea:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute(PlayAreaConfig.Attributes.LevelType) == LevelTypes.BackpackCheckpoint then
			return child
		end
	end
	return nil
end

local function handlePlaceItemInLane(player: Player, itemId: string, laneId: string)
	if typeof(itemId) ~= "string" or typeof(laneId) ~= "string" then return end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireExplorer(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.BackpackCheckpoint)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestPlaceItemInLane", Constants.RATE_LIMIT_PLACE)
	if not okRate then return end

	local levelModel = findBackpackLevelModel(round)
	if not levelModel then return end
	local bin = TagQueries.GetBinByLane(levelModel, laneId)
	if not bin then return end
	local okBin = RemoteValidation.RequireProximity(player, bin, Constants.BIN_RADIUS_STUDS)
	if not okBin then return end

	local accepted, correct, reason = BackpackCheckpointLevel.HandleSort(round, itemId, laneId)
	if accepted and correct then
		round.ItemsSorted += 1
		ScoringService.AddTrustPoints(round, Constants.TRUST_POINTS_PER_CORRECT_SORT, "Sort")
	elseif reason == "WrongLane" then
		ScoringService.AddMistake(round, "WrongLane")
	end
end

function ExplorerInteractionService.Init()
	RemoteService.OnServerEvent("RequestInspectNpc", handleInspectNpc)
	RemoteService.OnServerEvent("RequestPickupItem", handlePickupItem)
	RemoteService.OnServerEvent("RequestPlaceItemInLane", handlePlaceItemInLane)
end

return ExplorerInteractionService
