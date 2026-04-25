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
local StrangerDangerLogic = require(Modules:WaitForChild("StrangerDangerLogic"))

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
	-- ASYMMETRIC VISION: Explorer only gets the silhouette (a glance) plus
	-- the npc's archetype name so the action card can theme itself. Guide
	-- gets the full Cues + Verdict so the book can teach the right call.
	-- The Explorer learns nothing about Risky/Safe role from this remote —
	-- only the silhouette text and outline. Cues are only revealed to the
	-- Explorer one-at-a-time when they choose AskFirst.
	round.LevelState[LevelTypes.StrangerDangerPark] = round.LevelState[LevelTypes.StrangerDangerPark] or {}
	local levelState = round.LevelState[LevelTypes.StrangerDangerPark]
	levelState.RevealedCues = levelState.RevealedCues or {}
	levelState.RevealedCues[npcId] = levelState.RevealedCues[npcId] or {}

	RemoteService.FireClient(round.Explorer, "NpcDescriptionShown", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Audience = "Explorer",
		Archetype = npcInfo.Archetype,
		Silhouette = npcInfo.Silhouette,
		RevealedCues = levelState.RevealedCues[npcId],
	})
	RemoteService.FireClient(round.Guide, "NpcDescriptionShown", {
		RoundId = round.RoundId,
		NpcId = npcId,
		Audience = "Guide",
		Archetype = npcInfo.Archetype,
		Cues = npcInfo.Cues,
		Verdict = npcInfo.Verdict,
		Silhouette = npcInfo.Silhouette,
	})
end

-- ===========================================================================
-- 3-way action handler. Action is "Approach" | "AskFirst" | "Avoid".
-- - Approach safe-with-clue NPC -> clue fragment + trust points
-- - Approach risky NPC -> consequence (teleport + mistake)
-- - Approach safe-no-clue -> friendly chat, no progress
-- - AskFirst -> server reveals one more cue to Explorer (and Guide if not
--   already known) up to a cap, no commit
-- - Avoid risky -> safe, no penalty (correct call)
-- - Avoid safe-with-clue -> missed clue (no penalty, but no progress)
-- ===========================================================================

local MAX_ASKS_PER_NPC = 3
local TRUST_POINTS_AVOID_RISKY = 5
local TRUST_POINTS_ASKFIRST = 1
local TRUST_POINTS_MISSED_CLUE = 0

local function notify(player: Player, kind: string, text: string)
	RemoteService.FireClient(player, "Notify", { Kind = kind, Text = text })
end

local function handleExplorerAction(player: Player, npcId: string, action: string)
	if typeof(npcId) ~= "string" or typeof(action) ~= "string" then return end
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return end
	local okRole = RemoteValidation.RequireExplorer(player)
	if not okRole then return end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.StrangerDangerPark)
	if not okLevel then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestExplorerAction", Constants.RATE_LIMIT_TALK)
	if not okRate then return end

	local scenario = round.ActiveScenario
	local npcInfo = findNpcInScenario(scenario, npcId)
	if not npcInfo then return end
	local model = findNpcModel(round, npcId)
	local root = getNpcRoot(model)
	if not root then return end
	local okProx = RemoteValidation.RequireProximity(player, root, Constants.TALK_RADIUS_STUDS)
	if not okProx then return end

	round.LevelState[LevelTypes.StrangerDangerPark] = round.LevelState[LevelTypes.StrangerDangerPark] or {}
	local levelState = round.LevelState[LevelTypes.StrangerDangerPark]
	levelState.RevealedCues = levelState.RevealedCues or {}
	levelState.RevealedCues[npcId] = levelState.RevealedCues[npcId] or {}
	levelState.AsksUsed = levelState.AsksUsed or {}
	levelState.AsksUsed[npcId] = levelState.AsksUsed[npcId] or 0
	levelState.ResolvedNpcs = levelState.ResolvedNpcs or {}

	-- once an NPC is resolved (Approach or Avoid was chosen), they don't
	-- accept more actions — the proximity prompt is also disabled below so
	-- the explorer can't loop on the same NPC.
	if levelState.ResolvedNpcs[npcId] then
		notify(player, "Info", "You've already decided about this person.")
		return
	end

	local function disablePromptOnNpc()
		if model then
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("ProximityPrompt") and desc:GetAttribute("BB_NpcId") then
					desc.Enabled = false
				end
			end
		end
	end

	if action == StrangerDangerLogic.Action.AskFirst then
		local asks = levelState.AsksUsed[npcId]
		local available = {}
		for _, tag in ipairs(npcInfo.Cues) do
			if not table.find(levelState.RevealedCues[npcId], tag) then
				table.insert(available, tag)
			end
		end
		if asks >= MAX_ASKS_PER_NPC or #available == 0 then
			notify(player, "Info", "Buddy can't see any more details from there.")
			RemoteService.FireClient(round.Explorer, "NpcActionResolved", {
				RoundId = round.RoundId, NpcId = npcId, Action = action, Result = "NoMoreCues",
			})
			return
		end
		local revealedTag = available[math.random(#available)]
		table.insert(levelState.RevealedCues[npcId], revealedTag)
		levelState.AsksUsed[npcId] = asks + 1

		ScoringService.AddTrustPoints(round, TRUST_POINTS_ASKFIRST, "AskFirst")
		RemoteService.FireClient(round.Explorer, "NpcCueRevealed", {
			RoundId = round.RoundId, NpcId = npcId, CueTag = revealedTag,
			AsksUsed = levelState.AsksUsed[npcId], MaxAsks = MAX_ASKS_PER_NPC,
		})
		RemoteService.FireClient(round.Guide, "NpcCueRevealed", {
			RoundId = round.RoundId, NpcId = npcId, CueTag = revealedTag,
			AsksUsed = levelState.AsksUsed[npcId], MaxAsks = MAX_ASKS_PER_NPC,
		})
		return
	end

	if action == StrangerDangerLogic.Action.Avoid then
		levelState.ResolvedNpcs[npcId] = "Avoid"
		disablePromptOnNpc()
		local result: string
		if npcInfo.Role == ScenarioTypes.NpcRoles.Risky then
			ScoringService.AddTrustPoints(round, TRUST_POINTS_AVOID_RISKY, "AvoidRisky")
			result = "AvoidedSafely"
			notify(player, "Success", "Smart call — that one was risky.")
		elseif npcInfo.Role == ScenarioTypes.NpcRoles.SafeWithClue then
			ScoringService.AddTrustPoints(round, TRUST_POINTS_MISSED_CLUE, "MissedClue")
			result = "MissedClue"
			notify(player, "Info", "They might've had a clue — moving on.")
		else
			result = "AvoidedSafely"
		end
		RemoteService.FirePair(round, "NpcActionResolved", {
			RoundId = round.RoundId, NpcId = npcId, Action = action, Result = result,
			Role = npcInfo.Role,
		})
		return
	end

	-- Approach
	levelState.ResolvedNpcs[npcId] = "Approach"
	disablePromptOnNpc()
	if npcInfo.Role == ScenarioTypes.NpcRoles.SafeWithClue then
		round.CluesCollected += 1
		ScoringService.AddTrustPoints(round, Constants.TRUST_POINTS_PER_CLUE, "Clue")
		RemoteService.FirePair(round, "NpcActionResolved", {
			RoundId = round.RoundId, NpcId = npcId, Action = action, Result = "ClueGranted",
			Role = npcInfo.Role,
		})
		RemoteService.FirePair(round, "ClueCollected", {
			RoundId = round.RoundId,
			NpcId = npcId,
			ClueText = npcInfo.Fragment and npcInfo.Fragment.Text or npcInfo.ClueText,
			Truthful = npcInfo.Fragment and npcInfo.Fragment.Truthful,
			Landmark = npcInfo.Fragment and npcInfo.Fragment.Landmark,
			Total = round.CluesCollected,
			NeededTotal = Constants.CLUES_TO_FIND,
		})
		StrangerDangerLevel.OnClueCollected(round, scenario)
	elseif npcInfo.Role == ScenarioTypes.NpcRoles.SafeNoClue then
		RemoteService.FirePair(round, "NpcActionResolved", {
			RoundId = round.RoundId, NpcId = npcId, Action = action, Result = "NoClueChat",
			Role = npcInfo.Role,
		})
		notify(player, "Info", "Friendly chat — they don't know about the puppy.")
	elseif npcInfo.Role == ScenarioTypes.NpcRoles.Risky then
		ScoringService.AddMistake(round, "Risky")
		-- Risky NPCs may still hand out a misleading fragment that taints
		-- the Guide's clue map.
		if npcInfo.Fragment then
			RemoteService.FirePair(round, "ClueCollected", {
				RoundId = round.RoundId, NpcId = npcId,
				ClueText = npcInfo.Fragment.Text,
				Truthful = false,
				Landmark = npcInfo.Fragment.Landmark,
				Total = round.CluesCollected,
				NeededTotal = Constants.CLUES_TO_FIND,
			})
		end
		RemoteService.FirePair(round, "NpcActionResolved", {
			RoundId = round.RoundId, NpcId = npcId, Action = action, Result = "RiskyConsequence",
			Role = npcInfo.Role,
		})
		RemoteService.FirePair(round, "ExplorerFeedback", { Kind = "RiskyConsequence", NpcId = npcId })
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
	RemoteService.OnServerEvent("RequestTalkToNpc", function(player, npcId)
		-- legacy proximity prompt path: treat plain "Talk" as Approach
		handleExplorerAction(player, npcId, StrangerDangerLogic.Action.Approach)
	end)
	RemoteService.OnServerEvent("RequestExplorerAction", handleExplorerAction)
	RemoteService.OnServerEvent("RequestPickupItem", handlePickupItem)
	RemoteService.OnServerEvent("RequestPlaceItemInLane", handlePlaceItemInLane)
end

return ExplorerInteractionService
