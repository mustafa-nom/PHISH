--!strict
-- Pair management. Lobby/Round services consult this before granting actions.

local Players = game:GetService("Players")

local MatchService = {}

export type Pair = {
	Id: string,
	Members: { Player },
	CreatedAt: number,
}

local pairs_: { [string]: Pair } = {}
local playerToPair: { [Player]: Pair } = {}
local createListeners: { (Pair) -> () } = {}

local nextPairId = 0

local function newPairId(): string
	nextPairId += 1
	return string.format("pair_%d", nextPairId)
end

function MatchService.OnPairCreated(callback: (Pair) -> ())
	table.insert(createListeners, callback)
end

function MatchService.CreatePair(playerA: Player, playerB: Player): Pair?
	if not playerA or not playerB then
		return nil
	end
	if playerToPair[playerA] or playerToPair[playerB] then
		return nil
	end
	local p: Pair = {
		Id = newPairId(),
		Members = { playerA, playerB },
		CreatedAt = os.clock(),
	}
	pairs_[p.Id] = p
	playerToPair[playerA] = p
	if playerB ~= playerA then
		playerToPair[playerB] = p
	end
	for _, listener in ipairs(createListeners) do
		task.spawn(listener, p)
	end
	return p
end

function MatchService.GetPair(player: Player): Pair?
	return playerToPair[player]
end

function MatchService.GetPairById(pairId: string): Pair?
	return pairs_[pairId]
end

function MatchService.RemovePair(player: Player)
	local p = playerToPair[player]
	if not p then
		return
	end
	for _, member in ipairs(p.Members) do
		playerToPair[member] = nil
	end
	pairs_[p.Id] = nil
end

function MatchService.RemovePairById(pairId: string)
	local p = pairs_[pairId]
	if not p then
		return
	end
	for _, member in ipairs(p.Members) do
		playerToPair[member] = nil
	end
	pairs_[pairId] = nil
end

function MatchService.ArePaired(playerA: Player, playerB: Player): boolean
	local pa = playerToPair[playerA]
	if not pa then
		return false
	end
	for _, member in ipairs(pa.Members) do
		if member == playerB then
			return true
		end
	end
	return false
end

function MatchService.GetPartner(player: Player): Player?
	local p = playerToPair[player]
	if not p then
		return nil
	end
	for _, member in ipairs(p.Members) do
		if member ~= player then
			return member
		end
	end
	return nil
end

function MatchService.Init()
	Players.PlayerRemoving:Connect(function(player)
		MatchService.RemovePair(player)
	end)
end

return MatchService
