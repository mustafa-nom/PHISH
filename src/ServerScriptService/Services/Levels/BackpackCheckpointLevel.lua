--!strict
-- Backpack Checkpoint: conveyor item lifecycle + sort validation.

local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

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

local function findItemTemplate(itemKey: string): Model?
	local templates = ServerStorage:FindFirstChild("ItemTemplates")
	if not templates then
		return nil
	end
	local template = templates:FindFirstChild(itemKey)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function makeItemPlaceholder(itemKey: string, parent: Instance): Model
	-- Fallback when no template exists: a small block with a BillboardGui
	-- showing the item label. Keeps the demo running even if User 1 hasn't
	-- shipped the item models yet.
	local model = Instance.new("Model")
	model.Name = itemKey
	local part = Instance.new("Part")
	part.Name = "Body"
	part.Size = Vector3.new(2, 2, 2)
	part.Color = Color3.fromRGB(245, 200, 90)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.Parent = model
	model.PrimaryPart = part
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 40)
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(255, 248, 232)
	label.TextColor3 = Color3.fromRGB(60, 40, 20)
	label.Font = Enum.Font.Cartoon
	label.TextSize = 18
	label.Text = itemKey
	label.Parent = billboard
	model.Parent = parent
	return model
end

local function spawnItem(round, scenario, itemInfo)
	local levelModel = getLevelModel(round)
	if not levelModel then
		return nil
	end
	local beltStart = TagQueries.FirstTaggedInside(levelModel, PlayAreaConfig.Tags.BeltStart)
	if not beltStart or not beltStart:IsA("BasePart") then
		warn("BackpackCheckpointLevel: BeltStart part missing")
		return nil
	end
	local template = findItemTemplate(itemInfo.ItemKey)
	local model: Model
	if template then
		model = template:Clone() :: Model
	else
		model = makeItemPlaceholder(itemInfo.ItemKey, levelModel)
	end
	model.Name = itemInfo.Id
	model.Parent = levelModel
	if model.PrimaryPart then
		model:PivotTo(beltStart.CFrame + Vector3.new(0, 2, 0))
	end
	model:SetAttribute("BB_ItemId", itemInfo.Id)
	model:SetAttribute("BB_ItemKey", itemInfo.ItemKey)

	round.ActiveItemId = itemInfo.Id
	round.LevelState[LevelTypes.BackpackCheckpoint] = round.LevelState[LevelTypes.BackpackCheckpoint] or {}
	round.LevelState[LevelTypes.BackpackCheckpoint].ActiveItemModel = model

	RemoteService.FirePair(round, "ConveyorItemSpawned", {
		RoundId = round.RoundId,
		ItemId = itemInfo.Id,
		ItemKey = itemInfo.ItemKey,
		DisplayLabel = itemInfo.DisplayLabel,
		Index = scenario.CurrentItemIndex,
		Total = #scenario.ItemSequence,
	})
	return model
end

function BackpackCheckpointLevel.GetActiveItemInfo(round)
	local scenario = round.ActiveScenario
	if not scenario or scenario.Type ~= LevelTypes.BackpackCheckpoint then
		return nil
	end
	local idx = scenario.CurrentItemIndex
	if idx < 1 or idx > #scenario.ItemSequence then
		return nil
	end
	return scenario.ItemSequence[idx]
end

function BackpackCheckpointLevel.GetActiveItemModel(round): Model?
	local levelState = round.LevelState[LevelTypes.BackpackCheckpoint]
	if not levelState then
		return nil
	end
	return levelState.ActiveItemModel
end

function BackpackCheckpointLevel.AdvanceToNextItem(round)
	local scenario = round.ActiveScenario
	if not scenario or scenario.Type ~= LevelTypes.BackpackCheckpoint then
		return false
	end
	scenario.CurrentItemIndex += 1
	if scenario.CurrentItemIndex > #scenario.ItemSequence then
		round.ActiveItemId = nil
		return false  -- level complete
	end
	local nextItem = scenario.ItemSequence[scenario.CurrentItemIndex]
	-- Destroy old model
	local levelState = round.LevelState[LevelTypes.BackpackCheckpoint]
	if levelState and levelState.ActiveItemModel and levelState.ActiveItemModel.Parent then
		levelState.ActiveItemModel:Destroy()
	end
	spawnItem(round, scenario, nextItem)
	return true
end

function BackpackCheckpointLevel.Begin(round, scenario)
	local levelModel = getLevelModel(round)
	if not levelModel then
		warn("BackpackCheckpointLevel: level model not in slot")
		return false
	end
	round.LevelState[LevelTypes.BackpackCheckpoint] = round.LevelState[LevelTypes.BackpackCheckpoint] or {}
	scenario.CurrentItemIndex = 1

	-- Wire bin proximity prompts (drop here)
	for _, bin in ipairs(TagQueries.GetTaggedInside(levelModel, PlayAreaConfig.Tags.BuddyBin)) do
		if bin:IsA("BasePart") then
			local existingPrompt = bin:FindFirstChildOfClass("ProximityPrompt")
			if not existingPrompt then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Drop here"
				prompt.ObjectText = ItemRegistry.LaneTheme[bin:GetAttribute(PlayAreaConfig.Attributes.LaneId)] and ItemRegistry.LaneTheme[bin:GetAttribute(PlayAreaConfig.Attributes.LaneId)].Label or "Bin"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = Constants.BIN_RADIUS_STUDS
				prompt.RequiresLineOfSight = false
				prompt.Parent = bin
				prompt:SetAttribute("BB_LaneId", bin:GetAttribute(PlayAreaConfig.Attributes.LaneId))
			end
		end
	end

	spawnItem(round, scenario, scenario.ItemSequence[1])

	RemoteService.FireClient(round.Guide, "GuideManualUpdated", {
		RoundId = round.RoundId,
		LevelType = LevelTypes.BackpackCheckpoint,
		Manual = scenario.GuideManual,
	})

	return true
end

function BackpackCheckpointLevel.HandleSort(round, itemId: string, laneId: string): (boolean, boolean)
	-- Returns (acceptedByServer, wasCorrect). Only valid on the active item.
	local scenario = round.ActiveScenario
	if not scenario or scenario.Type ~= LevelTypes.BackpackCheckpoint then
		return false, false
	end
	if itemId ~= round.ActiveItemId then
		return false, false
	end
	local activeItem = BackpackCheckpointLevel.GetActiveItemInfo(round)
	if not activeItem then
		return false, false
	end
	local correct = activeItem.CorrectLane == laneId
	RemoteService.FirePair(round, "ItemSortResult", {
		RoundId = round.RoundId,
		ItemId = itemId,
		LaneId = laneId,
		Correct = correct,
	})
	return true, correct
end

function BackpackCheckpointLevel.Cleanup(round)
	local levelState = round.LevelState[LevelTypes.BackpackCheckpoint]
	if levelState then
		if levelState.ActiveItemModel and levelState.ActiveItemModel.Parent then
			levelState.ActiveItemModel:Destroy()
		end
		levelState.ActiveItemModel = nil
	end
	round.ActiveItemId = nil
end

return BackpackCheckpointLevel
