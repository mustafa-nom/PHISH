--!strict
-- Scoring tracking. Round → score components.
--
-- Per-level perfect tracking lives on round.LevelState[levelType].PerfectSoFar.
-- A "perfect" level has zero mistakes by the time it ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScoringConfig = require(Modules:WaitForChild("ScoringConfig"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local ScoringService = {}

local function pushScoreUpdate(round)
	RemoteService.FirePair(round, "ScoreUpdated", {
		RoundId = round.RoundId,
		TrustPoints = round.TrustPoints,
		Mistakes = round.Mistakes,
		Streak = round.Streak,
	})
end

function ScoringService.AddMistake(round, reason: string?)
	if not round or not round.IsActive then
		return
	end
	round.Mistakes += 1
	round.Streak = 0
	pushScoreUpdate(round)
	RemoteService.FirePair(round, "ExplorerFeedback", {
		Kind = "Mistake",
		Reason = reason,
	})
end

function ScoringService.AddTrustPoints(round, amount: number, reason: string?, multiplier: number?)
	if not round or not round.IsActive then
		return
	end
	local mult = multiplier or 1.0
	local scaled = math.floor(amount * mult)
	round.TrustPoints += scaled
	round.Streak += 1
	if round.Streak > 1 then
		round.TrustPoints += ScoringConfig.TrustStreakBonus
	end
	pushScoreUpdate(round)
	RemoteService.FirePair(round, "ExplorerFeedback", {
		Kind = "Trust",
		Amount = scaled,
		BaseAmount = amount,
		Multiplier = mult,
		Streak = round.Streak,
		Reason = reason,
	})
end

-- Halve (or otherwise reduce) the active combo. Used by Veto so the combo
-- "costs" something without nuking the run. Streak floor is 0; we don't fire
-- a mistake event because the player didn't make a mistake — they spent a
-- tool on purpose.
function ScoringService.ReduceStreak(round, divisor: number?)
	if not round or not round.IsActive then return end
	local d = divisor or 2
	if d < 1 then d = 1 end
	round.Streak = math.floor((round.Streak or 0) / d)
	pushScoreUpdate(round)
end

function ScoringService.NoteLevelStart(round, levelType: string)
	round.LevelState[levelType] = round.LevelState[levelType] or {}
	round.LevelState[levelType].StartedAt = os.clock()
	round.LevelState[levelType].MistakesAtStart = round.Mistakes
end

function ScoringService.NoteLevelComplete(round, levelType: string)
	round.LevelState[levelType] = round.LevelState[levelType] or {}
	local state = round.LevelState[levelType]
	state.CompletedAt = os.clock()
	state.Elapsed = state.CompletedAt - (state.StartedAt or state.CompletedAt)
	state.Mistakes = round.Mistakes - (state.MistakesAtStart or 0)
	state.Perfect = state.Mistakes == 0
	round.TrustPoints += ScoringConfig.LevelCompletionBonus
	round.TrustPoints += ScoringConfig.TimeBonus(state.Elapsed)
	if state.Perfect then
		round.TrustPoints += ScoringConfig.PerfectLevelBonus
	end
	pushScoreUpdate(round)
end

function ScoringService.CalculateFinalScore(round): { [string]: any }
	local total = round.TrustPoints - (round.Mistakes * ScoringConfig.MistakePenalty)
	if total < 0 then
		total = 0
	end
	local rank = ScoringConfig.RankFromScore(total)
	local elapsed = os.clock() - round.StartedAt
	local perfectLevels = 0
	local levelBreakdown = {}
	for _, levelType in ipairs(round.LevelSequence) do
		local state = round.LevelState[levelType] or {}
		if state.Perfect then
			perfectLevels += 1
		end
		table.insert(levelBreakdown, {
			LevelType = levelType,
			Elapsed = state.Elapsed or 0,
			Mistakes = state.Mistakes or 0,
			Perfect = state.Perfect == true,
		})
	end
	return {
		RoundId = round.RoundId,
		TotalScore = total,
		Rank = rank,
		Mistakes = round.Mistakes,
		Elapsed = elapsed,
		TrustPoints = round.TrustPoints,
		PerfectLevels = perfectLevels,
		LevelBreakdown = levelBreakdown,
	}
end

function ScoringService.Init()
	-- No remote handlers — Scoring is fully internal.
end

return ScoringService
