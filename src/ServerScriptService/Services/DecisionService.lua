--!strict
-- Validates a KEEP / CUT_BAIT decision against the active card. Grants
-- rewards, updates the dex, fires DecisionResult.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local PhishDex = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishDex"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local FishingService = require(Services:WaitForChild("FishingService"))
local ScoringService = require(Services:WaitForChild("ScoringService"))
local PhishDexService = require(Services:WaitForChild("PhishDexService"))
local FishModelService = require(Services:WaitForChild("FishModelService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local DecisionService = {}

local DECISIONS = { KEEP = true, CUT_BAIT = true }
local BASE_FLAG_ELEMENTS = {
	["sender.address"] = true,
	subject = true,
	body = true,
}

local function isAllowedFlagElement(element: string): boolean
	if BASE_FLAG_ELEMENTS[element] then return true end
	local linkIndex = string.match(element, "^links%[(%d+)%]$")
	local parsedIndex = linkIndex and tonumber(linkIndex)
	return parsedIndex ~= nil and parsedIndex <= 5
end

local function speciesDisplayName(id: string): string
	local s = PhishDex.Get(id)
	return s and s.displayName or id
end

-- Score the player's flag placements vs the card's authoritative redFlags.
-- Returns: { correct = {...}, falsePositive = {...}, coinsDelta = number, xpDelta = number }
local function scoreFlags(card: any, placed: { string }): { [string]: any }
	local truthSet: { [string]: boolean } = {}
	if card.redFlags then
		for _, f in ipairs(card.redFlags) do
			if type(f) == "table" and type(f.element) == "string" then
				truthSet[f.element] = true
			end
		end
	end

	local correct, falsePositive = {}, {}
	local seen: { [string]: boolean } = {}
	for _, element in ipairs(placed or {}) do
		if type(element) == "string" and not seen[element] then
			seen[element] = true
			if not card.isLegit and truthSet[element] then
				table.insert(correct, element)
			else
				-- ANY flag on a legit email is a false alarm.
				table.insert(falsePositive, element)
			end
		end
	end

	local coinsDelta = 0
	local xpDelta = 0
	for _ in ipairs(correct) do
		coinsDelta += PhishConstants.FLAG_CORRECT_COINS
		xpDelta += PhishConstants.FLAG_CORRECT_XP
	end
	for _ in ipairs(falsePositive) do
		local penalty = card.isLegit and PhishConstants.FLAG_FALSE_ALARM_COINS or PhishConstants.FLAG_FALSE_POSITIVE_COINS
		coinsDelta -= penalty
	end

	return {
		correct = correct,
		falsePositive = falsePositive,
		coinsDelta = coinsDelta,
		xpDelta = xpDelta,
	}
end

local function onSubmitDecision(player: Player, payload: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "Decision", PhishConstants.RATE_LIMIT_DECISION) end,
	})
	if not ok then return end
	if FishingService.GetState(player) ~= "Inspecting" then return end
	if type(payload) ~= "table" or not DECISIONS[payload.decision] then return end

	local card = CardService.GetActive(player)
	if not card then
		FishingService.SetIdle(player)
		return
	end

	local playerSaidLegit = (payload.decision == "KEEP")
	local actuallyLegit = card.isLegit == true
	local wasCorrect = (playerSaidLegit == actuallyLegit)

	PhishDexService.RecordFound(player, card.species)
	local rewardDelta = ScoringService.GrantCatchReward(player, wasCorrect, card)
	local fishAdded = false
	if wasCorrect then
		PhishDexService.RecordCatch(player, card.species)
		fishAdded = FishModelService.GiveCaughtFish(player, card.species, rewardDelta.fishSellValue or 0)
	end

	-- Apply flag scoring on top of the base reward. Mutates profile.coins/xp
	-- directly via DataService so the totals stay authoritative.
	local placedFlags: { string } = {}
	if type(payload.flags) == "table" then
		local seenSubmitted: { [string]: boolean } = {}
		for _, f in ipairs(payload.flags) do
			if
				type(f) == "string"
				and isAllowedFlagElement(f)
				and not seenSubmitted[f]
				and #placedFlags < PhishConstants.FLAG_MAX_PER_DECISION
			then
				seenSubmitted[f] = true
				table.insert(placedFlags, f)
			end
		end
	end
	local flagScore = scoreFlags(card, placedFlags)
	local profile = DataService.Get(player)
	profile.coins = math.max(0, profile.coins + flagScore.coinsDelta)
	profile.xp = math.max(0, profile.xp + flagScore.xpDelta)
	-- Refresh HUD with the flag-adjusted totals.
	ScoringService.PushHud(player)

	RemoteService.FireClient(player, "DecisionResult", {
		cardId = card.id,
		wasCorrect = wasCorrect,
		decision = payload.decision,
		isLegit = actuallyLegit,
		species = card.species,
		speciesDisplayName = speciesDisplayName(card.species),
		redFlags = card.redFlags or {},
		coinsDelta = rewardDelta.coinsDelta + flagScore.coinsDelta,
		xpDelta = rewardDelta.xpDelta + flagScore.xpDelta,
		fishSellValue = rewardDelta.fishSellValue or 0,
		fishAddedToInventory = fishAdded,
		flagsCorrect = flagScore.correct,
		flagsFalse = flagScore.falsePositive,
		flagBonusCoins = flagScore.coinsDelta,
		flagBonusXp = flagScore.xpDelta,
	})

	CardService.Clear(player)
	FishingService.SetIdle(player)
end

function DecisionService.Init()
	RemoteService.OnServerEvent("SubmitDecision", onSubmitDecision)
end

return DecisionService
