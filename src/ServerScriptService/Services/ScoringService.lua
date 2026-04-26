--!strict
-- Scoring + reward logic. Mutates Profile. Triggers HudUpdated remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local ScoringService = {}
local debugCoinCooldownByPlayer: { [Player]: number } = {}

local function pushHud(player: Player)
	RemoteService.FireClient(player, "HudUpdated", DataService.Snapshot(player))
end

function ScoringService.Init()
	RemoteService.OnServerEvent("RequestDebugCoins", function(player)
		local now = os.clock()
		if (debugCoinCooldownByPlayer[player] or 0) > now then return end
		debugCoinCooldownByPlayer[player] = now + 0.25

		local profile = DataService.Get(player)
		profile.coins += 500
		pushHud(player)
		RemoteService.FireClient(player, "Notify", {
			kind = "Success",
			message = "+500 test coins",
			duration = 1.5,
		})
	end)
end

-- Called by DecisionService after every catch resolution.
-- Correct catches grant XP immediately, but pearls are now the fish's sell
-- value. The player only receives those pearls when they sell the fish tool.
function ScoringService.GrantCatchReward(player: Player, wasCorrect: boolean, card: any): { coinsDelta: number, xpDelta: number, fishSellValue: number }
	local profile = DataService.Get(player)
	profile.totalCatches += 1

	local coinsDelta = 0
	local xpDelta = 0
	local fishSellValue = 0
	if wasCorrect then
		profile.correctCatches += 1
		local baseCoins = (card.reward and card.reward.coins) or PhishConstants.REWARD_CORRECT_COINS
		local baseXp = (card.reward and card.reward.xp) or PhishConstants.REWARD_CORRECT_XP
		local diffBonus = math.max(0, (card.difficulty or 1) - 1) * PhishConstants.REWARD_DIFFICULTY_BONUS
		fishSellValue = baseCoins + diffBonus
		xpDelta = baseXp + diffBonus
		profile.xp += xpDelta
	else
		-- Soft penalty: tiny coin loss only if they have coins; never negative.
		coinsDelta = -math.min(profile.coins, 1)
		profile.coins += coinsDelta
	end

	pushHud(player)
	return { coinsDelta = coinsDelta, xpDelta = xpDelta, fishSellValue = fishSellValue }
end

function ScoringService.PushHud(player: Player)
	pushHud(player)
end

return ScoringService
