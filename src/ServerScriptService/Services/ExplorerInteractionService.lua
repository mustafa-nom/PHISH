--!strict
-- Explorer-side remote handlers: NPC inspect/talk, item pickup/place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local ScenarioTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScenarioTypes"))

local Services = script.Parent
local Helpers = Services:WaitForChild("Helpers")
local RoundContext = require(Helpers:WaitForChild("RoundContext"))
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))
local ScoringService = require(Services:WaitForChild("ScoringService"))
local PlayAreaService = require(Services:WaitForChild("PlayAreaService"))
local Levels = Services:WaitForChild("Levels")
local StrangerDangerLevel = require(Levels:WaitForChild("StrangerDangerLevel"))
local BackpackCheckpointLevel = require(Levels:WaitForChild("BackpackCheckpointLevel"))

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
		return root :: BasePart
	end
	return nil
end

local function teleportExplorerToLevelEntry(round)
	local levelType = round.ActiveScenario and round.ActiveScenario.Type
	if levelType then
		PlayAreaService.TeleportToLevelEntry(round, levelType)
	end
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

	local scenario = round.ActiveScenario
	local npcInfo = findNpcInScenario(scenario, npcId)
	if not npcInfo then return end

	local model = findNpcModel(round, npcId)
	local root = getNpcRoot(model)
	if not root then return end
	local okProx = RemoteValidation.RequireProximity(player, root, Constants.INSPECT_RADIUS_STUDS)
	if not okProx then return end

	round.LastInspectedNpcId = npcId
	-- Reveal traits to both Explorer and Guide. Guide additionally gets the
	-- risk classification so the manual highlight can match.
	RemoteService.FireClient(round.Explorer, "NpcDescriptionShown", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Traits = npcInfo.Traits,
		Audience = "Explorer",
	})
	RemoteService.FireClient(round.Guide, "NpcDescriptionShown", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Traits = npcInfo.Traits,
		Audience = "Guide",
	})
end

local function handleTalkToNpc(player: Player, npcId: string)
	if typeof(npcId) ~= "string" then return end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireExplorer(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.StrangerDangerPark)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestTalkToNpc", Constants.RATE_LIMIT_TALK)
	if not okRate then return end

	local scenario = round.ActiveScenario
	local npcInfo = findNpcInScenario(scenario, npcId)
	if not npcInfo then return end

	local model = findNpcModel(round, npcId)
	local root = getNpcRoot(model)
	if not root then return end
	local okProx = RemoteValidation.RequireProximity(player, root, Constants.TALK_RADIUS_STUDS)
	if not okProx then return end

	if npcInfo.Role == ScenarioTypes.NpcRoles.SafeWithClue then
		round.CluesCollected += 1
		ScoringService.AddTrustPoints(round, Constants.TRUST_POINTS_PER_CLUE, "Clue")
		RemoteService.FirePair(round, "ClueCollected", {
			RoundId = round.RoundId,
			NpcId = npcId,
			ClueText = npcInfo.ClueText,
			Total = round.CluesCollected,
			NeededTotal = Constants.CLUES_TO_FIND,
		})
		StrangerDangerLevel.OnClueCollected(round, scenario)
	elseif npcInfo.Role == ScenarioTypes.NpcRoles.SafeNoClue then
		RemoteService.FireClient(player, "Notify", {
			Kind = "Info",
			Text = "Friendly chat — they don't know about the puppy.",
		})
	elseif npcInfo.Role == ScenarioTypes.NpcRoles.Risky then
		ScoringService.AddMistake(round, "Risky")
		RemoteService.FirePair(round, "ExplorerFeedback", {
			Kind = "RiskyConsequence",
			NpcId = npcId,
		})
		teleportExplorerToLevelEntry(round)
	end
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

	if itemId ~= round.ActiveItemId then
		return
	end
	local model = BackpackCheckpointLevel.GetActiveItemModel(round)
	if not model then return end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root or not root:IsA("BasePart") then return end
	local okProx = RemoteValidation.RequireProximity(player, root, Constants.ITEM_PICKUP_RADIUS_STUDS)
	if not okProx then return end

	-- Mark held; the actual physical pickup happens client-side.
	round.LevelState[LevelTypes.BackpackCheckpoint].HeldByPlayer = player
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

	-- Validate proximity to the matching bin
	local slot = PlayAreaService.GetSlotForRound(round)
	if not slot then return end
	local playArea = slot:FindFirstChild("PlayArea")
	if not playArea then return end
	local levelModel: Model? = nil
	for _, child in ipairs(playArea:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute(PlayAreaConfig.Attributes.LevelType) == LevelTypes.BackpackCheckpoint then
			levelModel = child
			break
		end
	end
	if not levelModel then return end
	local bin = TagQueries.GetBinByLane(levelModel, laneId)
	if not bin then return end
	local okBin = RemoteValidation.RequireProximity(player, bin, Constants.BIN_RADIUS_STUDS)
	if not okBin then return end

	local accepted, correct = BackpackCheckpointLevel.HandleSort(round, itemId, laneId)
	if not accepted then return end
	if correct then
		round.ItemsSorted += 1
		ScoringService.AddTrustPoints(round, Constants.TRUST_POINTS_PER_CORRECT_SORT, "Sort")
		local hasNext = BackpackCheckpointLevel.AdvanceToNextItem(round)
		if not hasNext then
			-- Level complete
			local LevelService = require(Services:WaitForChild("LevelService"))
			LevelService.CompleteLevel(round, LevelTypes.BackpackCheckpoint)
		end
	else
		ScoringService.AddMistake(round, "WrongLane")
		-- Bounce-back is a client-visual; server-side we leave activeItem unchanged.
	end
end

function ExplorerInteractionService.Init()
	RemoteService.OnServerEvent("RequestInspectNpc", handleInspectNpc)
	RemoteService.OnServerEvent("RequestTalkToNpc", handleTalkToNpc)
	RemoteService.OnServerEvent("RequestPickupItem", handlePickupItem)
	RemoteService.OnServerEvent("RequestPlaceItemInLane", handlePlaceItemInLane)
end

return ExplorerInteractionService
