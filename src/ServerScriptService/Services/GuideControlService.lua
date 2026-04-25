--!strict
-- Guide-side remote handlers for Stranger Danger booth slots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local BadgeConfig = require(Modules:WaitForChild("BadgeConfig"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))
local ScoringService = require(Services:WaitForChild("ScoringService"))

local GuideControlService = {}

local function pushBoothState(round)
	local StrangerDangerLevel = require(Services:WaitForChild("Levels"):WaitForChild("StrangerDangerLevel"))
	StrangerDangerLevel.RefreshBoothDisplays(round)
end

local function validateGuideInStrangerDanger(player: Player)
	local okPlayer = RemoteValidation.RequirePlayer(player)
	if not okPlayer then return nil end
	local okRound, _, round = RemoteValidation.RequireRound(player)
	if not okRound or not round then return nil end
	local okRole = RemoteValidation.RequireGuide(player)
	if not okRole then return nil end
	local okLevel = RemoteValidation.RequireLevelType(round, LevelTypes.StrangerDangerPark)
	if not okLevel then return nil end
	return round
end

local function handleSetSlotBadge(player: Player, payload)
	if typeof(payload) ~= "table" then return end
	local slotIndex = payload.SlotIndex
	local color = payload.Color
	local shape = payload.Shape
	if typeof(slotIndex) ~= "number" or not BadgeConfig.IsValidColor(color) or not BadgeConfig.IsValidShape(shape) then
		return
	end
	local round = validateGuideInStrangerDanger(player)
	if not round then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestSetSlotBadge", Constants.RATE_LIMIT_BOOTH_SLOT)
	if not okRate then return end

	local slot = round.BoothState.Slots[slotIndex]
	if not slot or slot.Locked then
		return
	end
	slot.Color = color
	slot.Shape = shape
	slot.Status = "Pending"
	pushBoothState(round)
end

local function allSlotsFilled(round): boolean
	for i = 1, 3 do
		local slot = round.BoothState.Slots[i]
		if not slot or not BadgeConfig.IsValidColor(slot.Color) or not BadgeConfig.IsValidShape(slot.Shape) then
			return false
		end
	end
	return true
end

local function consumeAnswer(answerCounts: { [string]: number }, color: string, shape: string): boolean
	local key = BadgeConfig.Key(color, shape)
	local remaining = answerCounts[key] or 0
	if remaining <= 0 then
		return false
	end
	answerCounts[key] = remaining - 1
	return true
end

local function buildAnswerCounts(scenario): { [string]: number }
	local counts = {}
	for _, badge in ipairs(scenario.AnswerBadges or {}) do
		local key = BadgeConfig.BadgeKey(badge)
		counts[key] = (counts[key] or 0) + 1
	end
	return counts
end

local function validateSlots(round): boolean
	local answerCounts = buildAnswerCounts(round.ActiveScenario)
	for _, slot in ipairs(round.BoothState.Slots) do
		if slot.Locked and slot.Color and slot.Shape then
			consumeAnswer(answerCounts, slot.Color, slot.Shape)
		end
	end

	local allCorrect = true
	for _, slot in ipairs(round.BoothState.Slots) do
		if not slot.Locked then
			local correct = slot.Color and slot.Shape and consumeAnswer(answerCounts, slot.Color, slot.Shape)
			if correct then
				slot.Locked = true
				slot.Status = "Correct"
			else
				slot.Locked = false
				slot.Status = "Wrong"
				allCorrect = false
			end
		end
	end
	return allCorrect
end

local function snapshotSlots(round)
	local slots = {}
	for i, slot in ipairs(round.BoothState.Slots) do
		slots[i] = {
			Color = slot.Color,
			Shape = slot.Shape,
			Locked = slot.Locked,
			Status = slot.Status,
		}
	end
	return slots
end

function GuideControlService.SubmitForPlayer(player: Player)
	local round = validateGuideInStrangerDanger(player)
	if not round then return end
	local okRate = RemoteValidation.RequireRateLimit(player, "RequestSubmitAccusation", Constants.RATE_LIMIT_BOOTH_SUBMIT)
	if not okRate then return end
	if not allSlotsFilled(round) then
		RemoteService.FireClient(player, "Notify", {
			Kind = "Error",
			Text = "Fill all 3 slots before submitting.",
		})
		return
	end

	local allCorrect = validateSlots(round)
	table.insert(round.BoothState.History, {
		At = os.clock(),
		Slots = snapshotSlots(round),
		Correct = allCorrect,
	})

	if allCorrect then
		pushBoothState(round)
		task.spawn(function()
			local LevelService = require(Services:WaitForChild("LevelService"))
			LevelService.CompleteLevel(round, LevelTypes.StrangerDangerPark)
		end)
		return
	end

	round.AttemptsLeft -= 1
	ScoringService.AddMistake(round, "WrongAccusation")
	pushBoothState(round)
	if round.AttemptsLeft <= 0 then
		RemoteService.FirePair(round, "Notify", {
			Kind = "Info",
			Text = "Looks like a few got past us, but everyone got home okay. Wanna try again?",
		})
		task.spawn(function()
			local RoundService = require(Services:WaitForChild("RoundService"))
			RoundService.EndRound(round, "FailedStrangerDanger")
		end)
	end
end

local function handleSubmitAccusation(player: Player)
	GuideControlService.SubmitForPlayer(player)
end

function GuideControlService.Init()
	RemoteService.OnServerEvent("RequestSetSlotBadge", handleSetSlotBadge)
	RemoteService.OnServerEvent("RequestSubmitAccusation", handleSubmitAccusation)
end

return GuideControlService
