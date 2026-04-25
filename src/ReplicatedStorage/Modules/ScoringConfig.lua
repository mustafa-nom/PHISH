--!strict
-- Scoring config. ScoringService and RewardService consume this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local ScoringConfig = {}

ScoringConfig.LevelCompletionBonus = Constants.LEVEL_COMPLETION_BONUS
ScoringConfig.MaxTimeBonus = Constants.MAX_TIME_BONUS
ScoringConfig.MistakePenalty = Constants.MISTAKE_PENALTY
ScoringConfig.TrustPointsPerClue = Constants.TRUST_POINTS_PER_CLUE
ScoringConfig.TrustPointsPerCorrectSort = Constants.TRUST_POINTS_PER_CORRECT_SORT
ScoringConfig.TrustStreakBonus = Constants.TRUST_STREAK_BONUS
ScoringConfig.PerfectLevelBonus = Constants.PERFECT_LEVEL_BONUS

-- Time bonus: earn full MaxTimeBonus if level done in under FastTime, scale
-- linearly to zero at SlowTime.
ScoringConfig.TimeWindow = {
	FastSeconds = 60,
	SlowSeconds = 240,
}

-- Score thresholds for ranks. Apply at end of full round.
ScoringConfig.RankThresholds = {
	Perfect = 2400,
	Gold = 1800,
	Silver = 1200,
	Bronze = 0,
}

ScoringConfig.RankOrder = { "Perfect", "Gold", "Silver", "Bronze" }

-- Trust Seeds awarded by rank.
ScoringConfig.TrustSeedsByRank = {
	Perfect = Constants.SEEDS_BASE_FINISH + Constants.SEEDS_BONUS_PERFECT,
	Gold = Constants.SEEDS_BASE_FINISH + Constants.SEEDS_BONUS_GOLD,
	Silver = Constants.SEEDS_BASE_FINISH + 2,
	Bronze = Constants.SEEDS_BASE_FINISH,
}

ScoringConfig.SeedsBonusPerPerfectLevel = Constants.SEEDS_BONUS_PER_PERFECT_LEVEL

function ScoringConfig.RankFromScore(score: number): string
	for _, name in ipairs(ScoringConfig.RankOrder) do
		if score >= ScoringConfig.RankThresholds[name] then
			return name
		end
	end
	return "Bronze"
end

function ScoringConfig.TimeBonus(elapsedSeconds: number): number
	local fast = ScoringConfig.TimeWindow.FastSeconds
	local slow = ScoringConfig.TimeWindow.SlowSeconds
	if elapsedSeconds <= fast then
		return ScoringConfig.MaxTimeBonus
	elseif elapsedSeconds >= slow then
		return 0
	end
	local span = slow - fast
	local progress = (elapsedSeconds - fast) / span
	return math.floor(ScoringConfig.MaxTimeBonus * (1 - progress))
end

return ScoringConfig
