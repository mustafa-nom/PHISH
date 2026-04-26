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

-- Backpack Checkpoint combo multipliers per BACKPACK_CHECKPOINT_PRD_V1_POLISHED.md.
-- Streak thresholds (post-increment): 3 → ×1.5, 5 → ×2.0. 10+ marks the run as
-- a Perfect-Trust-Run candidate but the multiplier ceiling stays at ×2.0.
-- Multiplier applies ONLY to per-sort base trust points; level-completion and
-- perfect-level bonuses are not multiplied.
ScoringConfig.ComboMultipliers = {
	{ Streak = 5, Multiplier = 2.0 },
	{ Streak = 3, Multiplier = 1.5 },
}
ScoringConfig.PerfectTrustRunStreak = 10

-- Veto cost: combo divisor (Streak = floor(Streak / divisor)). Per addendum
-- default — change after playtest.
ScoringConfig.VetoComboDivisor = 2

-- Mini-Boss "wrong call ends the round" threshold. Below this, a wrong inner
-- sort is a normal mistake; at or above, the round ends with MiniBossFail.
ScoringConfig.MiniBossFailStreakThreshold = 5
ScoringConfig.MiniBossSuccessBonus = 400

function ScoringConfig.GetComboMultiplier(streak: number): number
	for _, tier in ipairs(ScoringConfig.ComboMultipliers) do
		if streak >= tier.Streak then
			return tier.Multiplier
		end
	end
	return 1.0
end

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
