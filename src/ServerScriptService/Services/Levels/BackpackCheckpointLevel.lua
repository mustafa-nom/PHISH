--!strict
-- Backpack Checkpoint level entry point.
--
-- Thin wrapper around the BackpackCheckpoint/ submodules. Keeps the same
-- Begin / HandleSort / GetActiveItemInfo / GetActiveItemModel / Cleanup
-- surface that LevelService and ExplorerInteractionService already call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local BackpackCheckpoint = script.Parent:WaitForChild("BackpackCheckpoint")
local BeltController = require(BackpackCheckpoint:WaitForChild("BeltController"))
local WaveDirector = require(BackpackCheckpoint:WaitForChild("WaveDirector"))

local BackpackCheckpointLevel = {}

local function getLevelModel(round): Model?
	for _, candidate in ipairs(TagQueries.GetSortedSlots()) do
		if candidate:GetAttribute(PlayAreaConfig.Attributes.SlotIndex) == round.SlotIndex then
			local playArea = candidate:FindFirstChild(Constants.SLOT_PLAY_AREA_FOLDER)
			if not playArea then
				return nil
			end
			for _, child in ipairs(playArea:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute(PlayAreaConfig.Attributes.LevelType) == LevelTypes.BackpackCheckpoint then
					return child
				end
			end
		end
	end
	return nil
end

-- Re-export query helpers so existing callers don't need the submodule path.
BackpackCheckpointLevel.GetActiveItemInfo = BeltController.GetActiveItemInfo
BackpackCheckpointLevel.GetActiveItemModel = BeltController.GetActiveItemModel
BackpackCheckpointLevel.GetLaneLocks = BeltController.GetLaneLocks
BackpackCheckpointLevel.SetLaneLock = BeltController.SetLaneLock
BackpackCheckpointLevel.SetHighlight = BeltController.SetHighlight
BackpackCheckpointLevel.MarkHeld = BeltController.MarkHeld
BackpackCheckpointLevel.GetHeldByPlayer = BeltController.GetHeldByPlayer

function BackpackCheckpointLevel.HandleSort(round, itemId: string, laneId: string): (boolean, boolean, string?)
	-- Returns (acceptedByServer, wasCorrect, reason).
	-- WaveDirector.OnItemResolved is fired by BeltController via the
	-- per-spawn callback whenever the active item leaves the belt
	-- (correct sort or fall-off). Wrong sort bounces back and stays active.
	return BeltController.HandleSort(round, itemId, laneId)
end

function BackpackCheckpointLevel.Begin(round, scenario)
	local levelModel = getLevelModel(round)
	if not levelModel then
		warn("BackpackCheckpointLevel: level model not in slot")
		return false
	end

	-- Wire bin proximity prompts (drop here).
	for _, bin in ipairs(TagQueries.GetTaggedInside(levelModel, PlayAreaConfig.Tags.BuddyBin)) do
		if bin:IsA("BasePart") then
			local existingPrompt = bin:FindFirstChildOfClass("ProximityPrompt")
			if not existingPrompt then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Drop here"
				local laneId = bin:GetAttribute(PlayAreaConfig.Attributes.LaneId)
				local theme = ItemRegistry.LaneTheme[laneId]
				prompt.ObjectText = theme and theme.Label or "Bin"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = Constants.BIN_RADIUS_STUDS
				prompt.RequiresLineOfSight = false
				prompt.Parent = bin
				prompt:SetAttribute("BB_LaneId", laneId)
			end
		end
	end

	-- Pixel Post intro (P0 non-gating: 5s overlay, both clients).
	RemoteService.FirePair(round, "PixelPostIntro", {
		RoundId = round.RoundId,
		Title = "Pixel Post: Outbound Sorting",
		Body = "First shift! Bags coming in. Sort outgoing mail and incoming surprises — talk to your buddy.",
		DurationSeconds = Constants.BACKPACK_PIXEL_POST_INTRO_SECONDS,
	})

	-- Push the manual to the Guide before the first wave so the Field Manual
	-- chart is on screen the moment Wave 1 spawns.
	RemoteService.FireClient(round.Guide, "GuideManualUpdated", {
		RoundId = round.RoundId,
		LevelType = LevelTypes.BackpackCheckpoint,
		Manual = scenario.GuideManual,
	})

	-- LevelService handles the round.ActiveScenario assignment and itemsSorted
	-- reset; we just kick off the wave runner.
	local Services = script.Parent.Parent
	local LevelService
	local function onLevelComplete()
		LevelService = LevelService or require(Services:WaitForChild("LevelService"))
		LevelService.CompleteLevel(round, LevelTypes.BackpackCheckpoint)
	end

	WaveDirector.Begin(round, scenario, onLevelComplete)
	return true
end

function BackpackCheckpointLevel.Cleanup(round)
	BeltController.Cleanup(round)
end

return BackpackCheckpointLevel
