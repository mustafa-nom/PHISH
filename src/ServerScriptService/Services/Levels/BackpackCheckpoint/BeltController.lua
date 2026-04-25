--!strict
-- Backpack Checkpoint belt + active-item lifecycle.
--
-- Responsibilities:
--   * spawn the next item on the belt
--   * track the active item's model + spawn position + held state
--   * bounce items back on a wrong (but unlocked-lane) sort
--   * fall-off timer for items that aren't sorted in time
--   * release the held flag if the carrier dies / leaves
--   * cleanup all in-flight state on level end / disconnect (edge cases 1, 2)
--
-- This module owns *only* the belt — WaveDirector decides when to call
-- SpawnNextItem and what to do when an item is resolved.

local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent.Parent.Parent
local ScoringService = require(Services:WaitForChild("ScoringService"))

local BeltController = {}

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
	-- Fallback when no template exists: a small block with a BillboardGui.
	-- Keeps the demo running when User 1 hasn't shipped the item models yet.
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

local function ensureLevelState(round)
	round.LevelState[LevelTypes.BackpackCheckpoint] = round.LevelState[LevelTypes.BackpackCheckpoint] or {}
	local state = round.LevelState[LevelTypes.BackpackCheckpoint]
	state.LaneLocks = state.LaneLocks or {
		[ItemRegistry.Lanes.PackIt] = true,
		[ItemRegistry.Lanes.AskFirst] = true,
		[ItemRegistry.Lanes.LeaveIt] = true,
	}
	state.ScannedTags = state.ScannedTags or {}
	state.Highlight = state.Highlight or nil
	return state
end

-- Re-arm all lane locks. Called on item spawn and on bounce-back so the
-- Guide's per-item unlock has to be made fresh (edge case 11).
local function relockAllLanes(round)
	local state = ensureLevelState(round)
	state.LaneLocks[ItemRegistry.Lanes.PackIt] = true
	state.LaneLocks[ItemRegistry.Lanes.AskFirst] = true
	state.LaneLocks[ItemRegistry.Lanes.LeaveIt] = true
	RemoteService.FirePair(round, "LaneLockUpdated", {
		RoundId = round.RoundId,
		LaneLocks = state.LaneLocks,
	})
end

-- Clear the per-active-item highlight so a stale ring doesn't carry over to
-- the next spawn.
local function clearHighlight(round)
	local state = ensureLevelState(round)
	state.Highlight = nil
	RemoteService.FirePair(round, "HighlightUpdated", {
		RoundId = round.RoundId,
		ItemId = nil,
		Color = nil,
	})
end

-- Public: query helpers used by ExplorerInteractionService and ScannerService.
function BeltController.GetActiveItemInfo(round)
	local scenario = round.ActiveScenario
	if not scenario or scenario.Type ~= LevelTypes.BackpackCheckpoint then
		return nil
	end
	local wave = scenario.Waves[scenario.CurrentWaveIndex]
	if not wave then
		return nil
	end
	local idx = scenario.CurrentItemIndex
	if idx < 1 or idx > #wave.Items then
		return nil
	end
	return wave.Items[idx]
end

function BeltController.GetActiveItemModel(round): Model?
	local levelState = round.LevelState[LevelTypes.BackpackCheckpoint]
	if not levelState then
		return nil
	end
	return levelState.ActiveItemModel
end

function BeltController.GetLaneLocks(round): { [string]: boolean }
	return ensureLevelState(round).LaneLocks
end

function BeltController.SetLaneLock(round, lane: string, locked: boolean)
	local state = ensureLevelState(round)
	if state.LaneLocks[lane] == nil then
		return
	end
	state.LaneLocks[lane] = locked
	RemoteService.FirePair(round, "LaneLockUpdated", {
		RoundId = round.RoundId,
		LaneLocks = state.LaneLocks,
	})
end

function BeltController.SetHighlight(round, itemId: string?, color: string?)
	local state = ensureLevelState(round)
	state.Highlight = (itemId and color) and { ItemId = itemId, Color = color } or nil
	RemoteService.FirePair(round, "HighlightUpdated", {
		RoundId = round.RoundId,
		ItemId = itemId,
		Color = color,
	})
end

local function cancelFalloffTimer(state)
	if state.FalloffTimerToken then
		state.FalloffTimerToken.Cancelled = true
		state.FalloffTimerToken = nil
	end
end

local function destroyActiveModel(state)
	if state.ActiveItemModel and state.ActiveItemModel.Parent then
		state.ActiveItemModel:Destroy()
	end
	state.ActiveItemModel = nil
	state.ActiveItemSpawnPos = nil
	state.HeldByPlayer = nil
end

-- Schedule a fall-off timer. If the item is still active when it fires,
-- it counts as a mistake and the wave advances.
local function armFalloffTimer(round, scenario, onResolved: (string) -> ())
	local state = ensureLevelState(round)
	cancelFalloffTimer(state)
	local token = { Cancelled = false }
	state.FalloffTimerToken = token
	local activeId = round.ActiveItemId
	task.delay(Constants.BACKPACK_FALLOFF_SECONDS, function()
		if token.Cancelled then return end
		if not round.IsActive then return end
		if scenario ~= round.ActiveScenario then return end
		if round.ActiveItemId ~= activeId then return end
		-- Still on belt, not held → fall-off.
		if state.HeldByPlayer then
			-- Held by player when timer fires: arm a brief grace, but for P0
			-- we just give up and treat as fall-off too (drop-not-bin
			-- recovery is a P2 polish item).
		end
		RemoteService.FirePair(round, "ItemFalloff", {
			RoundId = round.RoundId,
			ItemId = activeId,
		})
		-- Edge case 25: fall-off counts as a mistake and breaks combo, same
		-- as a wrong sort. ScoringService.AddMistake resets Streak to 0.
		ScoringService.AddMistake(round, "Fallthrough")
		destroyActiveModel(state)
		state.OnResolved = nil
		onResolved("Fallthrough")
	end)
end

function BeltController.SpawnItem(round, scenario, itemInfo, waveIndex: number, itemIndex: number, totalInWave: number, onResolved: (string) -> ())
	local levelModel = getLevelModel(round)
	if not levelModel then
		return nil
	end
	local beltStart = TagQueries.FirstTaggedInside(levelModel, PlayAreaConfig.Tags.BeltStart)
	if not beltStart or not beltStart:IsA("BasePart") then
		warn("BeltController: BeltStart part missing")
		return nil
	end

	local state = ensureLevelState(round)
	-- Always destroy whatever was active before. Cleanup is the BeltController's
	-- responsibility; the WaveDirector should not have to chase models.
	destroyActiveModel(state)
	cancelFalloffTimer(state)

	local template = findItemTemplate(itemInfo.ItemKey)
	local model: Model
	if template then
		model = template:Clone() :: Model
	else
		model = makeItemPlaceholder(itemInfo.ItemKey, levelModel)
	end
	model.Name = itemInfo.Id
	model.Parent = levelModel
	local spawnPos = beltStart.CFrame + Vector3.new(0, 2, 0)
	if model.PrimaryPart then
		model:PivotTo(spawnPos)
	end
	model:SetAttribute("BB_ItemId", itemInfo.Id)
	model:SetAttribute("BB_ItemKey", itemInfo.ItemKey)

	round.ActiveItemId = itemInfo.Id
	state.ActiveItemModel = model
	state.ActiveItemSpawnPos = spawnPos
	state.HeldByPlayer = nil
	state.OnResolved = onResolved
	state.ActiveItemSpawnedAt = os.clock()

	-- Per-item state resets: lanes lock, highlight clears.
	relockAllLanes(round)
	clearHighlight(round)

	RemoteService.FirePair(round, "ConveyorItemSpawned", {
		RoundId = round.RoundId,
		ItemId = itemInfo.Id,
		ItemKey = itemInfo.ItemKey,
		DisplayLabel = itemInfo.DisplayLabel,
		Index = itemIndex,
		Total = totalInWave,
		WaveIndex = waveIndex,
	})

	armFalloffTimer(round, scenario, onResolved)
	return model
end

-- Handle a sort attempt. Returns:
--   resolved = true when the item left the belt (correct sort or wrong sort
--     that we choose to count as resolution; for P0 wrong-sort still bounces
--     back, so resolved is true ONLY for correct sorts).
--   correct = true if the lane matches the item's CorrectLane.
--   reason  = "Locked" if the chosen lane was still locked.
function BeltController.HandleSort(round, itemId: string, laneId: string): (boolean, boolean, string?)
	local scenario = round.ActiveScenario
	if not scenario or scenario.Type ~= LevelTypes.BackpackCheckpoint then
		return false, false, nil
	end
	if itemId ~= round.ActiveItemId then
		return false, false, nil
	end
	local activeItem = BeltController.GetActiveItemInfo(round)
	if not activeItem then
		return false, false, nil
	end
	local state = ensureLevelState(round)
	if state.LaneLocks[laneId] then
		-- Edge case 10: locked lane rejects placement. No mistake.
		RemoteService.FireClient(round.Explorer, "Notify", {
			Kind = "Info",
			Text = "Buddy hasn't unlocked that lane yet.",
		})
		return false, false, "Locked"
	end

	local correct = activeItem.CorrectLane == laneId
	RemoteService.FirePair(round, "ItemSortResult", {
		RoundId = round.RoundId,
		ItemId = itemId,
		LaneId = laneId,
		Correct = correct,
	})

	if correct then
		cancelFalloffTimer(state)
		local resolved = state.OnResolved
		destroyActiveModel(state)
		state.OnResolved = nil
		if resolved then
			-- WaveDirector spawns the next item, finishes the wave, or fires
			-- LevelService.CompleteLevel — depending on where in the wave we
			-- are. ExplorerInteractionService doesn't need to know.
			resolved("Sorted")
		end
		return true, true, nil
	else
		-- Edge case 5: bounce back to last position minus 25% of belt length.
		BeltController.BounceBack(round)
		return false, false, "WrongLane"
	end
end

function BeltController.BounceBack(round)
	local state = ensureLevelState(round)
	local model = state.ActiveItemModel
	if not model or not model.PrimaryPart or not state.ActiveItemSpawnPos then
		return
	end
	local levelModel = getLevelModel(round)
	if not levelModel then
		return
	end
	local beltEnd = TagQueries.FirstTaggedInside(levelModel, PlayAreaConfig.Tags.BeltEnd)
	local beltLen = 20
	if beltEnd and beltEnd:IsA("BasePart") then
		beltLen = (beltEnd.Position - state.ActiveItemSpawnPos.Position).Magnitude
	end
	local backDistance = beltLen * Constants.BACKPACK_BOUNCE_BACK_FRACTION
	-- Move toward belt start (spawn pos) by backDistance, clamped to spawn.
	local current = model.PrimaryPart.Position
	local toStart = (state.ActiveItemSpawnPos.Position - current)
	local distToStart = toStart.Magnitude
	local moveMag = math.min(backDistance, distToStart)
	local newPos = current + (distToStart > 0 and toStart.Unit * moveMag or Vector3.new())
	model:PivotTo(CFrame.new(newPos))
	state.HeldByPlayer = nil
	-- Re-arm lane locks: Guide must reconfirm their unlock.
	relockAllLanes(round)
end

function BeltController.MarkHeld(round, player: Player?)
	local state = ensureLevelState(round)
	state.HeldByPlayer = player
end

function BeltController.GetHeldByPlayer(round): Player?
	local state = round.LevelState[LevelTypes.BackpackCheckpoint]
	return state and state.HeldByPlayer or nil
end

function BeltController.Cleanup(round)
	local levelState = round.LevelState[LevelTypes.BackpackCheckpoint]
	if not levelState then
		round.ActiveItemId = nil
		return
	end
	cancelFalloffTimer(levelState)
	destroyActiveModel(levelState)
	-- Wipe per-item scanner state so a future round on this slot starts clean.
	levelState.LaneLocks = nil
	levelState.Highlight = nil
	levelState.ScannedTags = nil
	levelState.ScansUsedThisWave = nil
	levelState.OnResolved = nil
	levelState.IntroDismissedBy = nil
	round.ActiveItemId = nil
end

return BeltController
