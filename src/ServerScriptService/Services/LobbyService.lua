--!strict
-- Lobby pairing flow:
--   * Capsule pads tagged `LobbyCapsule` with attributes `CapsuleId` and
--     `CapsulePairId`. When both pads of a `CapsulePairId` are occupied, both
--     occupants get a `CapsulePairReady` event. They confirm via
--     `RequestPairFromCapsule(capsuleId)`. Two confirms within
--     CAPSULE_CONFIRM_WINDOW_SECONDS forms a pair.
--   * Proximity-prompt invites: `RequestInvitePlayer(targetUserId)` →
--     `InviteReceived` → `RespondToInvite(inviteId, accepted)`.
--
-- All gameplay state lives server-side; clients only render UI.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local MatchService = require(Services:WaitForChild("MatchService"))

local LobbyService = {}

-- Capsule occupancy: capsuleId → Player
local capsuleOccupancy: { [string]: Player } = {}
-- Per-pad confirmation state: capsuleId → os.clock() when player confirmed
local capsuleConfirms: { [string]: number } = {}

-- Invite registry: inviteId → { fromUserId, toUserId, expiresAt }
local invites: { [string]: { FromUserId: number, ToUserId: number, ExpiresAt: number } } = {}
local nextInviteId = 0

local function userIdToPlayer(userId: number): Player?
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function pairIdForCapsule(capsule: BasePart): string?
	local v = capsule:GetAttribute(PlayAreaConfig.Attributes.CapsulePairId)
	if typeof(v) == "string" then
		return v
	end
	return nil
end

local function capsuleIdFor(capsule: BasePart): string?
	local v = capsule:GetAttribute(PlayAreaConfig.Attributes.CapsuleId)
	if typeof(v) == "string" then
		return v
	end
	return nil
end

local function getCapsulesByPairId(pairId: string): { BasePart }
	local result = {}
	for _, instance in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.LobbyCapsule)) do
		if instance:IsA("BasePart") and instance:GetAttribute(PlayAreaConfig.Attributes.CapsulePairId) == pairId then
			table.insert(result, instance)
		end
	end
	return result
end

local function clearCapsuleForPlayer(player: Player)
	for capsuleId, occupant in pairs(capsuleOccupancy) do
		if occupant == player then
			capsuleOccupancy[capsuleId] = nil
			capsuleConfirms[capsuleId] = nil
			RemoteService.FireClient(player, "CapsulePairCleared", { CapsuleId = capsuleId })
		end
	end
end

local function broadcastPairReady(capsulePairId: string)
	local capsules = getCapsulesByPairId(capsulePairId)
	if #capsules < 2 then
		return
	end
	local occupants: { Player } = {}
	local capsuleIds: { string } = {}
	for _, c in ipairs(capsules) do
		local id = capsuleIdFor(c)
		if id then
			local occupant = capsuleOccupancy[id]
			if occupant then
				table.insert(occupants, occupant)
				table.insert(capsuleIds, id)
			end
		end
	end
	if #occupants ~= 2 then
		return
	end
	for i, p in ipairs(occupants) do
		RemoteService.FireClient(p, "CapsulePairReady", {
			CapsulePairId = capsulePairId,
			CapsuleId = capsuleIds[i],
			Partner = occupants[3 - i].Name,
		})
	end
end

local function tryConfirmPair(capsulePairId: string)
	local capsules = getCapsulesByPairId(capsulePairId)
	if #capsules ~= 2 then
		return
	end
	local now = os.clock()
	local players: { Player } = {}
	for _, c in ipairs(capsules) do
		local id = capsuleIdFor(c)
		if not id then
			return
		end
		local confirmAt = capsuleConfirms[id]
		local occupant = capsuleOccupancy[id]
		if not confirmAt or not occupant then
			return
		end
		if (now - confirmAt) > Constants.CAPSULE_CONFIRM_WINDOW_SECONDS then
			capsuleConfirms[id] = nil
			return
		end
		table.insert(players, occupant)
	end
	if #players ~= 2 or players[1] == players[2] then
		return
	end
	if MatchService.GetPair(players[1]) or MatchService.GetPair(players[2]) then
		return
	end
	local pair = MatchService.CreatePair(players[1], players[2])
	if not pair then
		return
	end
	for _, p in ipairs(pair.Members) do
		clearCapsuleForPlayer(p)
		RemoteService.FireClient(p, "PairAssigned", {
			PairId = pair.Id,
			Members = { pair.Members[1].Name, pair.Members[2].Name },
		})
	end
end

local function setupCapsule(capsule: BasePart)
	if not capsule:IsA("BasePart") then
		return
	end
	local capsuleId = capsuleIdFor(capsule)
	local pairId = pairIdForCapsule(capsule)
	if not capsuleId or not pairId then
		warn(("LobbyService: capsule %s missing CapsuleId / CapsulePairId; skipping"):format(capsule:GetFullName()))
		return
	end
	capsule.Touched:Connect(function(other)
		local character = other:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		if MatchService.GetPair(player) then
			return
		end
		if capsuleOccupancy[capsuleId] == player then
			return
		end
		clearCapsuleForPlayer(player)
		capsuleOccupancy[capsuleId] = player
		broadcastPairReady(pairId)
	end)
end

local function setupAllCapsules()
	for _, capsule in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.LobbyCapsule)) do
		setupCapsule(capsule :: BasePart)
	end
	CollectionService:GetInstanceAddedSignal(PlayAreaConfig.Tags.LobbyCapsule):Connect(setupCapsule)
end

local function newInviteId(): string
	nextInviteId += 1
	return string.format("invite_%d_%d", os.time(), nextInviteId)
end

local function expireOldInvites()
	local now = os.clock()
	for id, invite in pairs(invites) do
		if invite.ExpiresAt < now then
			invites[id] = nil
		end
	end
end

local function handleInviteRequest(player: Player, targetUserId: number)
	if typeof(targetUserId) ~= "number" then
		return
	end
	if MatchService.GetPair(player) then
		RemoteService.FireClient(player, "Notify", { Kind = "Error", Text = "You're already paired." })
		return
	end
	local target = userIdToPlayer(targetUserId)
	if not target or target == player then
		return
	end
	if MatchService.GetPair(target) then
		RemoteService.FireClient(player, "Notify", { Kind = "Error", Text = target.Name .. " is already in a pair." })
		return
	end
	expireOldInvites()
	local id = newInviteId()
	invites[id] = {
		FromUserId = player.UserId,
		ToUserId = target.UserId,
		ExpiresAt = os.clock() + Constants.INVITE_TTL_SECONDS,
	}
	RemoteService.FireClient(target, "InviteReceived", {
		InviteId = id,
		FromUserId = player.UserId,
		FromName = player.Name,
		ExpiresIn = Constants.INVITE_TTL_SECONDS,
	})
end

local function handleInviteResponse(player: Player, inviteId: string, accepted: boolean)
	if typeof(inviteId) ~= "string" then
		return
	end
	local invite = invites[inviteId]
	if not invite or invite.ToUserId ~= player.UserId then
		return
	end
	invites[inviteId] = nil
	local from = userIdToPlayer(invite.FromUserId)
	if not from then
		return
	end
	if not accepted then
		RemoteService.FireClient(from, "Notify", { Kind = "Info", Text = player.Name .. " declined." })
		return
	end
	if MatchService.GetPair(from) or MatchService.GetPair(player) then
		return
	end
	local pair = MatchService.CreatePair(from, player)
	if not pair then
		return
	end
	clearCapsuleForPlayer(from)
	clearCapsuleForPlayer(player)
	for _, p in ipairs(pair.Members) do
		RemoteService.FireClient(p, "PairAssigned", {
			PairId = pair.Id,
			Members = { pair.Members[1].Name, pair.Members[2].Name },
		})
	end
end

local function handleCapsuleConfirm(player: Player, capsuleId: string)
	if typeof(capsuleId) ~= "string" then
		return
	end
	if capsuleOccupancy[capsuleId] ~= player then
		return
	end
	capsuleConfirms[capsuleId] = os.clock()
	local capsule = nil
	for _, c in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.LobbyCapsule)) do
		if c:GetAttribute(PlayAreaConfig.Attributes.CapsuleId) == capsuleId then
			capsule = c
			break
		end
	end
	if not capsule then
		return
	end
	local pairId = pairIdForCapsule(capsule)
	if pairId then
		tryConfirmPair(pairId)
	end
end

local function handleLeavePair(player: Player)
	local pair = MatchService.GetPair(player)
	if not pair then
		return
	end
	local members = table.clone(pair.Members)
	MatchService.RemovePairById(pair.Id)
	for _, p in ipairs(members) do
		RemoteService.FireClient(p, "PairCleared", { Reason = "PartnerLeft" })
	end
end

function LobbyService.Init()
	setupAllCapsules()
	RemoteService.OnServerEvent("RequestPairFromCapsule", handleCapsuleConfirm)
	RemoteService.OnServerEvent("RequestInvitePlayer", handleInviteRequest)
	RemoteService.OnServerEvent("RespondToInvite", handleInviteResponse)
	RemoteService.OnServerEvent("LeavePair", handleLeavePair)

	Players.PlayerRemoving:Connect(function(player)
		clearCapsuleForPlayer(player)
		for id, invite in pairs(invites) do
			if invite.FromUserId == player.UserId or invite.ToUserId == player.UserId then
				invites[id] = nil
			end
		end
		local pair = MatchService.GetPair(player)
		if pair then
			local members = table.clone(pair.Members)
			MatchService.RemovePairById(pair.Id)
			for _, p in ipairs(members) do
				if p ~= player and p.Parent then
					RemoteService.FireClient(p, "PairCleared", { Reason = "PartnerLeft" })
				end
			end
		end
	end)

	-- DEBUG_SOLO: in Studio with one player, auto-pair against a sentinel
	-- so a single tester can run the demo. The "guide" partner is the same
	-- player; controllers detect this and route both UIs to one screen.
	if Constants.DEBUG_SOLO and RunService:IsStudio() then
		Players.PlayerAdded:Connect(function(player)
			task.wait(2)
			if #Players:GetPlayers() == 1 and not MatchService.GetPair(player) then
				local pair = MatchService.CreatePair(player, player)
				if pair then
					RemoteService.FireClient(player, "PairAssigned", {
						PairId = pair.Id,
						Members = { player.Name, player.Name },
						Solo = true,
					})
				end
			end
		end)
	end
end

return LobbyService
