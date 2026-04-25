--!strict
-- Routes Explorer ProximityPrompts:
--  * NPC inspect prompt → RequestInspectNpc
--  * NPC follow-up "Talk to them" prompt → RequestTalkToNpc (after inspect)
--  * Bin drop prompt → RequestPlaceItemInLane (after pickup)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local Constants = require(Modules:WaitForChild("Constants"))
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))

local localPlayer = Players.LocalPlayer
local currentRole = RoleTypes.None
local activeRoundId: string? = nil
local activeLevelType: string? = nil
local activeItemId: string? = nil
local heldItemId: string? = nil

local talkPrompts: { [string]: ProximityPrompt } = {}

local function isExplorer(): boolean
	return currentRole == RoleTypes.Explorer
end

local function getNpcModelById(npcId: string): Model?
	for _, instance in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.BuddyNpcSpawn)) do
		-- The NPC clone replaces the spawn point's contents; iterate the
		-- spawn part's parent (the level) for a model named npcId.
		local parent = instance.Parent
		if parent then
			local model = parent:FindFirstChild(npcId)
			if model and model:IsA("Model") then
				return model
			end
		end
	end
	-- Fallback: scan all level models for a Model with that name
	for _, slot in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.PlayArenaSlot)) do
		local playArea = slot:FindFirstChild("PlayArea")
		if playArea then
			for _, level in ipairs(playArea:GetChildren()) do
				local model = level:FindFirstChild(npcId)
				if model and model:IsA("Model") then
					return model
				end
			end
		end
	end
	return nil
end

local function clearTalkPrompts()
	for _, prompt in pairs(talkPrompts) do
		if prompt and prompt.Parent then
			prompt:Destroy()
		end
	end
	talkPrompts = {}
end

local function attachTalkPrompt(npcId: string)
	if talkPrompts[npcId] then return end
	local model = getNpcModelById(npcId)
	if not model then return end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk to them"
	prompt.ObjectText = "Tap E to chat"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Constants.TALK_RADIUS_STUDS
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Parent = root
	prompt:SetAttribute("BB_TalkNpcId", npcId)
	talkPrompts[npcId] = prompt
	prompt.Triggered:Connect(function(triggerer)
		if triggerer ~= localPlayer then return end
		RemoteService.FireServer("RequestTalkToNpc", npcId)
		if prompt.Parent then prompt:Destroy() end
		talkPrompts[npcId] = nil
	end)
	-- Auto-clean after a few seconds if Explorer wanders away
	task.delay(15, function()
		if talkPrompts[npcId] == prompt then
			if prompt.Parent then prompt:Destroy() end
			talkPrompts[npcId] = nil
		end
	end)
end

-- Listen for ProximityPrompt triggers globally; route NPC inspect prompts
-- to the inspect remote.
local promptService = game:GetService("ProximityPromptService")
promptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= localPlayer then return end
	if not isExplorer() then return end
	if not activeRoundId then return end

	local npcId = prompt:GetAttribute("BB_NpcId")
	if typeof(npcId) == "string" then
		RemoteService.FireServer("RequestInspectNpc", npcId)
		return
	end

	local laneId = prompt:GetAttribute("BB_LaneId")
	if typeof(laneId) == "string" and activeLevelType == LevelTypes.BackpackCheckpoint then
		if heldItemId then
			RemoteService.FireServer("RequestPlaceItemInLane", heldItemId, laneId)
			heldItemId = nil
		else
			-- Stand-in: also let the Explorer drop the active belt item
			-- without explicit pickup for MVP simplicity.
			if activeItemId then
				RemoteService.FireServer("RequestPlaceItemInLane", activeItemId, laneId)
			end
		end
		return
	end
end)

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	currentRole = payload.Role or RoleTypes.None
end)

RemoteService.OnClientEvent("RoundStarted", function(payload)
	activeRoundId = payload.RoundId
	clearTalkPrompts()
end)

RemoteService.OnClientEvent("LevelStarted", function(payload)
	if payload.RoundId ~= activeRoundId then return end
	activeLevelType = payload.LevelType
	clearTalkPrompts()
end)

RemoteService.OnClientEvent("LevelEnded", function(_payload)
	clearTalkPrompts()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	activeRoundId = nil
	activeLevelType = nil
	activeItemId = nil
	heldItemId = nil
	clearTalkPrompts()
end)

RemoteService.OnClientEvent("NpcDescriptionShown", function(payload)
	if not isExplorer() then return end
	if payload.RoundId ~= activeRoundId then return end
	if payload.Audience ~= "Explorer" then return end
	-- new flow: the NpcDescriptionCardController shows a 3-button action
	-- card directly; no follow-up "Talk to them" prompt is needed.
	-- Keep `attachTalkPrompt` available for legacy testing if explicitly wanted.
	if false then attachTalkPrompt(payload.NpcId) end
end)

RemoteService.OnClientEvent("ConveyorItemSpawned", function(payload)
	if payload.RoundId ~= activeRoundId then return end
	activeItemId = payload.ItemId
	heldItemId = nil
end)

RemoteService.OnClientEvent("ItemSortResult", function(payload)
	if payload.RoundId ~= activeRoundId then return end
	if payload.Correct then
		heldItemId = nil
	end
end)
