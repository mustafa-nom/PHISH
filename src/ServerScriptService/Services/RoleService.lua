--!strict
-- Role assignment for a pair. Pair → { Explorer, Guide }.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))
local Constants = require(Modules:WaitForChild("Constants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local MatchService = require(Services:WaitForChild("MatchService"))

local RoleService = {}

-- pairId → { Explorer = Player, Guide = Player, Locked = boolean, Selections = { [Player] = role } }
local pairRoles: { [string]: { Explorer: Player?, Guide: Player?, Locked: boolean, Selections: { [Player]: string } } } = {}

local function initPairEntry(pairId: string)
	if not pairRoles[pairId] then
		pairRoles[pairId] = {
			Explorer = nil,
			Guide = nil,
			Locked = false,
			Selections = {},
		}
	end
	return pairRoles[pairId]
end

function RoleService.GetRole(player: Player): string
	local pair = MatchService.GetPair(player)
	if not pair then
		return RoleTypes.None
	end
	local entry = pairRoles[pair.Id]
	if not entry then
		return RoleTypes.None
	end
	if entry.Explorer == player then
		return RoleTypes.Explorer
	elseif entry.Guide == player then
		return RoleTypes.Guide
	end
	return RoleTypes.None
end

function RoleService.GetExplorer(pairId: string): Player?
	local entry = pairRoles[pairId]
	return entry and entry.Explorer
end

function RoleService.GetGuide(pairId: string): Player?
	local entry = pairRoles[pairId]
	return entry and entry.Guide
end

function RoleService.IsLocked(pairId: string): boolean
	local entry = pairRoles[pairId]
	return entry ~= nil and entry.Locked
end

function RoleService.AssignRoles(pairId: string, explorer: Player, guide: Player)
	local entry = initPairEntry(pairId)
	entry.Explorer = explorer
	entry.Guide = guide
	entry.Locked = true
	RemoteService.FireClient(explorer, "RoleAssigned", { Role = RoleTypes.Explorer, PairId = pairId })
	RemoteService.FireClient(guide, "RoleAssigned", { Role = RoleTypes.Guide, PairId = pairId })
end

local function broadcastSelections(pairId: string)
	local entry = pairRoles[pairId]
	if not entry then
		return
	end
	local pair = MatchService.GetPairById(pairId)
	if not pair then
		return
	end
	local payload = {}
	for player, role in pairs(entry.Selections) do
		payload[tostring(player.UserId)] = role
	end
	for _, p in ipairs(pair.Members) do
		RemoteService.FireClient(p, "Notify", {
			Kind = "RoleSelections",
			Selections = payload,
		})
	end
end

local function tryAutoAssign(pairId: string)
	local entry = pairRoles[pairId]
	if not entry or entry.Locked then
		return
	end
	local pair = MatchService.GetPairById(pairId)
	if not pair or #pair.Members ~= 2 then
		return
	end
	local a = pair.Members[1]
	local b = pair.Members[2]

	-- Solo case: assign Explorer to the lone player. Guide UI surfaces on
	-- the same client too.
	if a == b then
		RoleService.AssignRoles(pairId, a, a)
		return
	end

	local roleA = entry.Selections[a]
	local roleB = entry.Selections[b]

	if roleA == RoleTypes.Explorer and roleB == RoleTypes.Guide then
		RoleService.AssignRoles(pairId, a, b)
	elseif roleA == RoleTypes.Guide and roleB == RoleTypes.Explorer then
		RoleService.AssignRoles(pairId, b, a)
	elseif roleA and not roleB then
		if roleA == RoleTypes.Explorer then
			RoleService.AssignRoles(pairId, a, b)
		else
			RoleService.AssignRoles(pairId, b, a)
		end
	elseif roleB and not roleA then
		if roleB == RoleTypes.Explorer then
			RoleService.AssignRoles(pairId, b, a)
		else
			RoleService.AssignRoles(pairId, a, b)
		end
	else
		-- Random fallback (timeout)
		if math.random() < 0.5 then
			RoleService.AssignRoles(pairId, a, b)
		else
			RoleService.AssignRoles(pairId, b, a)
		end
	end
end

local function handleSelectRole(player: Player, roleName: string)
	if not RoleTypes.IsValid(roleName) then
		return
	end
	local pair = MatchService.GetPair(player)
	if not pair then
		return
	end
	local entry = initPairEntry(pair.Id)
	if entry.Locked then
		return
	end
	entry.Selections[player] = roleName
	broadcastSelections(pair.Id)
	-- If both members have selected and chosen different roles, lock now.
	tryAutoAssign(pair.Id)
end

function RoleService.ResetPair(pairId: string)
	pairRoles[pairId] = nil
end

function RoleService.HandlePairAssigned(pair: MatchService.Pair)
	initPairEntry(pair.Id)
	-- Schedule auto-assign timeout
	task.delay(Constants.ROLE_AUTOASSIGN_SECONDS, function()
		local entry = pairRoles[pair.Id]
		if entry and not entry.Locked then
			tryAutoAssign(pair.Id)
		end
	end)
end

function RoleService.Init()
	RemoteService.OnServerEvent("SelectRole", handleSelectRole)

	Players.PlayerRemoving:Connect(function(player)
		local pair = MatchService.GetPair(player)
		if pair then
			RoleService.ResetPair(pair.Id)
		end
	end)
end

return RoleService
