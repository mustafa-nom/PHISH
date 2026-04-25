--!strict
-- Round state shape factory. Matches docs/TECHNICAL_DESIGN.md "Round State Shape".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))

local RoundState = {}

export type Round = {
	RoundId: string,
	PairId: string,
	Explorer: Player,
	Guide: Player,
	SlotIndex: number,
	LevelSequence: { string },
	CurrentLevelIndex: number,
	StartedAt: number,
	Mistakes: number,
	TrustPoints: number,
	CluesCollected: number,
	ItemsSorted: number,
	CompletedLevels: { string },
	ActiveScenario: any?,
	IsActive: boolean,
	Connections: { RBXScriptConnection },
	-- Mutable fields the level submodules attach. Treated as bag-of-state.
	LevelState: { [string]: any },
	Streak: number,
	LevelStartedAt: number?,
	LastInspectedNpcId: string?,
	ActiveItemId: string?,
}

local nextRoundId = 0

function RoundState.NewId(): string
	nextRoundId += 1
	return string.format("round_%d_%d", os.time(), nextRoundId)
end

function RoundState.New(explorer: Player, guide: Player, pairId: string, slotIndex: number): Round
	local round: Round = {
		RoundId = RoundState.NewId(),
		PairId = pairId,
		Explorer = explorer,
		Guide = guide,
		SlotIndex = slotIndex,
		LevelSequence = table.clone(LevelTypes.DemoSequence),
		CurrentLevelIndex = 1,
		StartedAt = os.clock(),
		Mistakes = 0,
		TrustPoints = 0,
		CluesCollected = 0,
		ItemsSorted = 0,
		CompletedLevels = {},
		ActiveScenario = nil,
		IsActive = true,
		Connections = {},
		LevelState = {},
		Streak = 0,
		LevelStartedAt = nil,
		LastInspectedNpcId = nil,
		ActiveItemId = nil,
	}
	return round
end

function RoundState.GetCurrentLevel(round: Round): string?
	return round.LevelSequence[round.CurrentLevelIndex]
end

function RoundState.HasMember(round: Round, player: Player): boolean
	return round.Explorer == player or round.Guide == player
end

function RoundState.Members(round: Round): { Player }
	return { round.Explorer, round.Guide }
end

function RoundState.OtherMember(round: Round, player: Player): Player?
	if round.Explorer == player then
		return round.Guide
	elseif round.Guide == player then
		return round.Explorer
	end
	return nil
end

function RoundState.AddConnection(round: Round, connection: RBXScriptConnection)
	table.insert(round.Connections, connection)
end

function RoundState.DisconnectAll(round: Round)
	for _, c in ipairs(round.Connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	round.Connections = {}
end

function RoundState.SnapshotForClient(round: Round): { [string]: any }
	return {
		RoundId = round.RoundId,
		PairId = round.PairId,
		ExplorerUserId = round.Explorer.UserId,
		GuideUserId = round.Guide.UserId,
		SlotIndex = round.SlotIndex,
		LevelSequence = round.LevelSequence,
		CurrentLevelIndex = round.CurrentLevelIndex,
		Mistakes = round.Mistakes,
		TrustPoints = round.TrustPoints,
		CluesCollected = round.CluesCollected,
		ItemsSorted = round.ItemsSorted,
		CompletedLevels = round.CompletedLevels,
		StartedAt = round.StartedAt,
	}
end

return RoundState
