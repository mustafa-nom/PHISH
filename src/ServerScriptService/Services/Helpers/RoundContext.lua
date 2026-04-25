--!strict
-- Looks up a round given a player. RoundService writes the registry; every
-- other service reads from it. Centralizing this avoids each service holding
-- its own player→round map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoundState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoundState"))
local RoleTypes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RoleTypes"))

type Round = RoundState.Round

local RoundContext = {}

local playerToRound: { [Player]: Round } = {}
local pairIdToRound: { [string]: Round } = {}
local roundIdToRound: { [string]: Round } = {}

function RoundContext.Register(round: Round)
	playerToRound[round.Explorer] = round
	playerToRound[round.Guide] = round
	pairIdToRound[round.PairId] = round
	roundIdToRound[round.RoundId] = round
end

function RoundContext.Unregister(round: Round)
	if playerToRound[round.Explorer] == round then
		playerToRound[round.Explorer] = nil
	end
	if playerToRound[round.Guide] == round then
		playerToRound[round.Guide] = nil
	end
	if pairIdToRound[round.PairId] == round then
		pairIdToRound[round.PairId] = nil
	end
	if roundIdToRound[round.RoundId] == round then
		roundIdToRound[round.RoundId] = nil
	end
end

function RoundContext.GetRound(player: Player): Round?
	return playerToRound[player]
end

function RoundContext.GetRoundById(roundId: string): Round?
	return roundIdToRound[roundId]
end

function RoundContext.GetRoundByPairId(pairId: string): Round?
	return pairIdToRound[pairId]
end

function RoundContext.GetRole(player: Player): string
	local round = playerToRound[player]
	if not round then
		return RoleTypes.None
	end
	if round.Explorer == player then
		return RoleTypes.Explorer
	elseif round.Guide == player then
		return RoleTypes.Guide
	end
	return RoleTypes.None
end

function RoundContext.IsExplorer(player: Player): boolean
	return RoundContext.GetRole(player) == RoleTypes.Explorer
end

function RoundContext.IsGuide(player: Player): boolean
	return RoundContext.GetRole(player) == RoleTypes.Guide
end

function RoundContext.GetActiveLevelType(round: Round): string?
	return RoundState.GetCurrentLevel(round)
end

function RoundContext.AllRounds(): { Round }
	local result = {}
	local seen = {}
	for _, round in pairs(playerToRound) do
		if not seen[round] then
			seen[round] = true
			table.insert(result, round)
		end
	end
	return result
end

return RoundContext
