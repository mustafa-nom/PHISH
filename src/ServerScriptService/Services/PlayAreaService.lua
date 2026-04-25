--!strict
-- Slot pool, level/booth cloning, teleporting, booth lock (defense in depth).
-- Slots are pre-built by User 1 in Workspace/PlayArenaSlots and tagged
-- `PlayArenaSlot` with `SlotIndex` attribute.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))

local PlayAreaService = {}

local slots: { Model } = {}
local reservations: { [number]: boolean } = {}
local roundFootprints: { [string]: { Slot: Model, BoothModel: Model?, BoothSeal: BasePart?, RespawnConnections: { RBXScriptConnection }, HeartbeatConnection: RBXScriptConnection? } } = {}

local function findChildByTagInside(root: Instance, tag: string): Instance?
	return TagQueries.FirstTaggedInside(root, tag)
end

local function findLevelByType(slot: Model, levelType: string): Model?
	local playArea = slot:FindFirstChild(Constants.SLOT_PLAY_AREA_FOLDER)
	if not playArea then
		return nil
	end
	for _, child in ipairs(playArea:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute(PlayAreaConfig.Attributes.LevelType) == levelType then
			return child
		end
	end
	return nil
end

local function getLevelEntry(slot: Model, levelType: string): BasePart?
	local level = findLevelByType(slot, levelType)
	if not level then
		return nil
	end
	local entry = TagQueries.FirstTaggedInside(level, PlayAreaConfig.Tags.LevelEntry)
	if entry and entry:IsA("BasePart") then
		return entry
	end
	return nil
end

local function teleportPlayerTo(player: Player, target: BasePart)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	root.CFrame = target.CFrame + Vector3.new(0, 4, 0)
end

local function buildBoothSeal(boothModel: Model): BasePart?
	-- Build an invisible cylinder/wall covering the booth's doorway. We
	-- approximate by putting a thin slab next to the GuideSpawn pointing
	-- inward. If the booth has no obvious doorway, we just rely on the
	-- heartbeat fallback.
	local guideSpawn = TagQueries.FirstTaggedInside(boothModel, PlayAreaConfig.Tags.GuideSpawn)
	if not guideSpawn or not guideSpawn:IsA("BasePart") then
		return nil
	end
	local seal = Instance.new("Part")
	seal.Name = "BoothSeal"
	seal.Anchored = true
	seal.CanCollide = true
	seal.Transparency = 1
	seal.Size = Vector3.new(20, 20, 1)
	seal.CFrame = guideSpawn.CFrame * CFrame.new(0, 0, 8)
	seal.Parent = boothModel
	return seal
end

local function startBoothHeartbeatGuard(round, boothModel: Model)
	local guideSpawn = TagQueries.FirstTaggedInside(boothModel, PlayAreaConfig.Tags.GuideSpawn)
	if not guideSpawn or not guideSpawn:IsA("BasePart") then
		return nil
	end
	local guard
	guard = RunService.Heartbeat:Connect(function()
		if not round.IsActive then
			guard:Disconnect()
			return
		end
		local guide = round.Guide
		if not guide or not guide.Parent then
			return
		end
		local character = guide.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		-- Booth bounding box (approximate via boothModel:GetBoundingBox)
		local cframe, size = boothModel:GetBoundingBox()
		local localPos = cframe:PointToObjectSpace(root.Position)
		local padding = PlayAreaConfig.BOOTH_LOCK_PADDING_STUDS
		if math.abs(localPos.X) > size.X / 2 + padding
			or math.abs(localPos.Y) > size.Y / 2 + padding
			or math.abs(localPos.Z) > size.Z / 2 + padding then
			-- Outside the booth — yank back.
			root.CFrame = guideSpawn.CFrame + Vector3.new(0, 4, 0)
		end
	end)
	return guard
end

local function alignBooth(boothClone: Model, anchor: BasePart)
	if not boothClone.PrimaryPart then
		warn("PlayAreaService: booth template has no PrimaryPart; cannot align")
		return
	end
	boothClone:PivotTo(anchor.CFrame)
end

local function alignLevel(levelClone: Model, slot: Model, offsetStuds: number)
	local explorerSpawn = TagQueries.FirstTaggedInside(slot, PlayAreaConfig.Tags.ExplorerSpawn)
	local origin: CFrame
	if explorerSpawn and explorerSpawn:IsA("BasePart") then
		origin = explorerSpawn.CFrame
	else
		origin = slot:GetPivot()
	end
	if not levelClone.PrimaryPart then
		-- best effort: just translate the model
		levelClone:PivotTo(origin * CFrame.new(offsetStuds, 0, 0))
		return
	end
	levelClone:PivotTo(origin * CFrame.new(offsetStuds, 0, 0))
end

function PlayAreaService.Init()
	local slotsRoot = Workspace:FindFirstChild("PlayArenaSlots")
	if not slotsRoot then
		warn("PlayAreaService: Workspace/PlayArenaSlots is missing — User 1's map may not be present")
	end
	slots = TagQueries.GetSortedSlots()
	for _, slot in ipairs(slots) do
		local idx = slot:GetAttribute(PlayAreaConfig.Attributes.SlotIndex)
		if typeof(idx) == "number" then
			reservations[idx] = false
		end
	end

	-- Re-teleport on respawn for any active round member. We use player
	-- attributes (BB_Role, BB_RoundId) to find the right round without
	-- pulling RoundContext (which would create a circular dependency).
	local function onCharacterAdded(player: Player, character: Model)
		task.wait(0.2)
		local roleAttr = player:GetAttribute("BB_Role")
		local roundIdAttr = player:GetAttribute("BB_RoundId")
		if not roleAttr or not roundIdAttr then return end
		local footprint = roundFootprints[roundIdAttr]
		if not footprint then return end
		local slot = footprint.Slot
		local target: BasePart? = nil
		if roleAttr == "Guide" and footprint.BoothModel then
			target = TagQueries.FirstTaggedInside(footprint.BoothModel, PlayAreaConfig.Tags.GuideSpawn) :: BasePart?
		elseif roleAttr == "Explorer" then
			local levelType = slot:GetAttribute("BB_CurrentLevel")
			if typeof(levelType) == "string" then
				target = getLevelEntry(slot, levelType)
			end
		end
		if target then
			local _ = character
			teleportPlayerTo(player, target)
		end
	end

	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

function PlayAreaService.ReserveSlot(): Model?
	for _, slot in ipairs(slots) do
		local idx = slot:GetAttribute(PlayAreaConfig.Attributes.SlotIndex)
		if typeof(idx) == "number" and not reservations[idx] then
			reservations[idx] = true
			return slot
		end
	end
	return nil
end

function PlayAreaService.ReleaseSlot(slot: Model)
	local idx = slot:GetAttribute(PlayAreaConfig.Attributes.SlotIndex)
	if typeof(idx) == "number" then
		reservations[idx] = false
	end
end

function PlayAreaService.BuildArenaForRound(round)
	local slotIdx = round.SlotIndex
	local slot
	for _, candidate in ipairs(slots) do
		if candidate:GetAttribute(PlayAreaConfig.Attributes.SlotIndex) == slotIdx then
			slot = candidate
			break
		end
	end
	if not slot then
		warn(("PlayAreaService: no slot for index %s"):format(tostring(slotIdx)))
		return false
	end
	slot:SetAttribute("BB_RoundId", round.RoundId)

	-- Clone level templates side-by-side
	local levelsFolder = ServerStorage:FindFirstChild("Levels")
	local boothFolder = ServerStorage:FindFirstChild("GuideBooths")
	if not levelsFolder or not boothFolder then
		warn("PlayAreaService: ServerStorage.Levels or ServerStorage.GuideBooths missing")
		return false
	end

	local playArea = slot:FindFirstChild(Constants.SLOT_PLAY_AREA_FOLDER)
	if not playArea then
		playArea = Instance.new("Folder")
		playArea.Name = Constants.SLOT_PLAY_AREA_FOLDER
		playArea.Parent = slot
	end
	local boothFolderInSlot = slot:FindFirstChild(Constants.SLOT_BOOTH_FOLDER)
	if not boothFolderInSlot then
		boothFolderInSlot = Instance.new("Folder")
		boothFolderInSlot.Name = Constants.SLOT_BOOTH_FOLDER
		boothFolderInSlot.Parent = slot
	end

	local strangerTemplate = levelsFolder:FindFirstChild(Constants.STRANGER_DANGER_LEVEL_NAME)
	local checkpointTemplate = levelsFolder:FindFirstChild(Constants.BACKPACK_CHECKPOINT_LEVEL_NAME)
	if not strangerTemplate or not checkpointTemplate then
		warn("PlayAreaService: missing level templates in ServerStorage/Levels")
		return false
	end

	local strangerClone = strangerTemplate:Clone()
	strangerClone.Parent = playArea
	alignLevel(strangerClone, slot, 0)
	strangerClone:SetAttribute(PlayAreaConfig.Attributes.LevelType, LevelTypes.StrangerDangerPark)

	local checkpointClone = checkpointTemplate:Clone()
	checkpointClone.Parent = playArea
	alignLevel(checkpointClone, slot, PlayAreaConfig.LEVEL_SPACING_STUDS)
	checkpointClone:SetAttribute(PlayAreaConfig.Attributes.LevelType, LevelTypes.BackpackCheckpoint)

	-- Booth
	local boothTemplate = boothFolder:FindFirstChild(Constants.DEFAULT_BOOTH_NAME)
	if not boothTemplate then
		warn("PlayAreaService: missing booth template ServerStorage/GuideBooths/" .. Constants.DEFAULT_BOOTH_NAME)
		return false
	end
	local anchor = TagQueries.FirstTaggedInside(slot, PlayAreaConfig.Tags.BoothAnchor)
	if not anchor or not anchor:IsA("BasePart") then
		warn("PlayAreaService: slot is missing a BoothAnchor part")
		return false
	end
	local boothClone = boothTemplate:Clone()
	boothClone.Parent = boothFolderInSlot
	alignBooth(boothClone, anchor)

	local seal = buildBoothSeal(boothClone)
	local heartbeatGuard = startBoothHeartbeatGuard(round, boothClone)

	roundFootprints[round.RoundId] = {
		Slot = slot,
		BoothModel = boothClone,
		BoothSeal = seal,
		RespawnConnections = {},
		HeartbeatConnection = heartbeatGuard,
	}

	-- Tag round members so the respawn handler can find them.
	round.Explorer:SetAttribute("BB_Role", "Explorer")
	round.Explorer:SetAttribute("BB_RoundId", round.RoundId)
	round.Guide:SetAttribute("BB_Role", "Guide")
	round.Guide:SetAttribute("BB_RoundId", round.RoundId)

	return true
end

function PlayAreaService.GetSlotForRound(round): Model?
	local fp = roundFootprints[round.RoundId]
	if fp then
		return fp.Slot
	end
	return nil
end

function PlayAreaService.GetBoothForRound(round): Model?
	local fp = roundFootprints[round.RoundId]
	if fp then
		return fp.BoothModel
	end
	return nil
end

function PlayAreaService.TeleportToLevelEntry(round, levelType: string)
	local slot = PlayAreaService.GetSlotForRound(round)
	if not slot then
		return
	end
	slot:SetAttribute("BB_CurrentLevel", levelType)
	local entry = getLevelEntry(slot, levelType)
	if not entry then
		warn(("PlayAreaService: no LevelEntry found for level %s in slot %d"):format(levelType, slot:GetAttribute(PlayAreaConfig.Attributes.SlotIndex) or -1))
		return
	end
	teleportPlayerTo(round.Explorer, entry)
end

function PlayAreaService.TeleportGuideToBooth(round)
	local boothModel = PlayAreaService.GetBoothForRound(round)
	if not boothModel then
		return
	end
	local guideSpawn = TagQueries.FirstTaggedInside(boothModel, PlayAreaConfig.Tags.GuideSpawn)
	if guideSpawn and guideSpawn:IsA("BasePart") then
		teleportPlayerTo(round.Guide, guideSpawn)
	end
end

function PlayAreaService.TeardownArenaForRound(round)
	local fp = roundFootprints[round.RoundId]
	if not fp then
		return
	end
	if fp.HeartbeatConnection then
		fp.HeartbeatConnection:Disconnect()
	end
	for _, c in ipairs(fp.RespawnConnections) do
		c:Disconnect()
	end
	if fp.Slot then
		fp.Slot:SetAttribute("BB_RoundId", nil)
		fp.Slot:SetAttribute("BB_CurrentLevel", nil)
		local playArea = fp.Slot:FindFirstChild(Constants.SLOT_PLAY_AREA_FOLDER)
		if playArea then
			playArea:ClearAllChildren()
		end
		local booth = fp.Slot:FindFirstChild(Constants.SLOT_BOOTH_FOLDER)
		if booth then
			booth:ClearAllChildren()
		end
		PlayAreaService.ReleaseSlot(fp.Slot)
	end
	if round.Explorer and round.Explorer.Parent then
		round.Explorer:SetAttribute("BB_Role", nil)
		round.Explorer:SetAttribute("BB_RoundId", nil)
	end
	if round.Guide and round.Guide.Parent then
		round.Guide:SetAttribute("BB_Role", nil)
		round.Guide:SetAttribute("BB_RoundId", nil)
	end
	roundFootprints[round.RoundId] = nil
end

return PlayAreaService
