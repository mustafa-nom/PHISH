--!strict
-- Computes Trust Seeds for a finished round and writes to DataService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScoringConfig = require(Modules:WaitForChild("ScoringConfig"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local RewardService = {}

function RewardService.GrantRunRewards(round, finalScore): { [string]: any }
	local rank = finalScore.Rank or "Bronze"
	local baseSeeds = ScoringConfig.TrustSeedsByRank[rank] or ScoringConfig.TrustSeedsByRank.Bronze
	local bonusSeeds = (finalScore.PerfectLevels or 0) * ScoringConfig.SeedsBonusPerPerfectLevel
	local total = baseSeeds + bonusSeeds

	local rewards = {
		Rank = rank,
		BaseSeeds = baseSeeds,
		BonusSeeds = bonusSeeds,
		TotalSeeds = total,
	}

	for _, player in ipairs({ round.Explorer, round.Guide }) do
		if player and player.Parent then
			-- In solo (player == player), only grant once
			if player == round.Explorer or round.Explorer ~= round.Guide then
				DataService.GrantSeeds(player, total)
				DataService.NoteRunCompleted(player, finalScore)
				RemoteService.FireClient(player, "RewardGranted", rewards)
			end
		end
	end

	return rewards
end

function RewardService.GetProgression(player: Player)
	return DataService.GetData(player)
end

function RewardService.Init()
	-- Wired in via RoundService.SetRewardHandler in ServerBootstrap order.
end

return RewardService
