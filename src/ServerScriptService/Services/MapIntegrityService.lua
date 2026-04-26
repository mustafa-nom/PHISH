--!strict
-- Map integrity & soft-lock prevention.
--   1. Every part tagged PhishWaterZone stays non-collide so players can swim
--      through the surface instead of walking on it.
--   2. Snapshots the boat (and dock parts) at boot. On every player respawn
--      / leave, restores them to the snapshot. Prevents the softlock where
--      a drifted boat is unreachable from the lodge spawn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))

local MapIntegrityService = {}

local WATER_TAG = PhishConstants.Tags.WaterZone
local BOAT_HULL_TAG = PhishConstants.Tags.BoatHull
local BOAT_SEAT_TAG = PhishConstants.Tags.BoatSeat
local ESCAPE_FOLDER_NAME = "PhishWaterEscapeRamps"

-- ---------------------------------------------------------------------------
-- 1. Keep water tiles non-collide.
-- ---------------------------------------------------------------------------

local function makeWaterNonCollide(instance: Instance)
	if not instance:IsA("BasePart") then return end
	-- The client swim controller supplies buoyancy; collision here would make
	-- the water behave like a floor.
	instance.CanCollide = false
end

local function makeAllWaterNonCollide()
	local count = 0
	for _, part in ipairs(CollectionService:GetTagged(WATER_TAG)) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
			count += 1
		end
	end
	if count > 0 then
		print(("[PHISH] MapIntegrity: made %d water tile(s) non-collide."):format(count))
	end
end

local function hideVehicleSeatHud(instance: Instance)
	if not instance:IsA("VehicleSeat") then return end
	pcall(function()
		(instance :: any).HeadsUpDisplay = false
	end)
end

local function hideAllVehicleSeatHuds()
	for _, seat in ipairs(CollectionService:GetTagged(BOAT_SEAT_TAG)) do
		hideVehicleSeatHud(seat)
	end
end

-- ---------------------------------------------------------------------------
-- 1b. Escape ramps so swimmers can climb back onto dock/land.
-- ---------------------------------------------------------------------------

local function makeRamp(parent: Instance, name: string, size: Vector3, cframe: CFrame)
	local ramp = Instance.new("Part")
	ramp.Name = name
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp.Material = Enum.Material.WoodPlanks
	ramp.Color = Color3.fromRGB(132, 88, 54)
	ramp.Size = size
	ramp.CFrame = cframe
	ramp.Parent = parent
	return ramp
end

local function ensureEscapeRamps()
	local map = workspace:FindFirstChild("PhishMap")
	if not map then return end

	local existing = map:FindFirstChild(ESCAPE_FOLDER_NAME)
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = ESCAPE_FOLDER_NAME
	folder.Parent = map

	-- Dock ladders/ramps on both sides near the fishing area. They start just
	-- below the swim surface and end at dock height, so players can walk up
	-- instead of jumping against a vertical dock edge.
	makeRamp(folder, "DockRampNorth", Vector3.new(6, 0.35, 4),
		CFrame.new(27, 0.75, -4.4) * CFrame.Angles(math.rad(-18), 0, 0))
	makeRamp(folder, "DockRampSouth", Vector3.new(6, 0.35, 4),
		CFrame.new(27, 0.75, 4.4) * CFrame.Angles(math.rad(18), 0, 0))
	makeRamp(folder, "DockTipRamp", Vector3.new(5, 0.35, 4),
		CFrame.new(35.2, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-18)))

	-- Wider beach ramp back to the island path.
	-- makeRamp(folder, "BeachRamp", Vector3.new(10, 0.35, 7),
	-- 	CFrame.new(7.4, 0.65, 0) * CFrame.Angles(0, 0, math.rad(-16)))
end

-- ---------------------------------------------------------------------------
-- 2. Boat / dock snapshot + reset.
-- ---------------------------------------------------------------------------

type PartSnapshot = { part: BasePart, cframe: CFrame, anchored: boolean }
type ModelSnapshot = { model: Model, pivot: CFrame, parts: { PartSnapshot } }

local boatSnapshot: ModelSnapshot? = nil
local dockSnapshots: { PartSnapshot } = {}

local function snapshotModel(model: Model): ModelSnapshot?
	if not model.PrimaryPart then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and CollectionService:HasTag(p, BOAT_HULL_TAG) then
				model.PrimaryPart = p
				break
			end
		end
	end
	if not model.PrimaryPart then
		warn("[PHISH] MapIntegrity: " .. model:GetFullName() .. " has no PrimaryPart; cannot snapshot.")
		return nil
	end
	local parts: { PartSnapshot } = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, { part = p, cframe = p.CFrame, anchored = p.Anchored })
		end
	end
	return { model = model, pivot = model:GetPivot(), parts = parts }
end

local function takeSnapshots()
	-- Boat: find the model containing the tagged hull part.
	local boatModel: Model? = nil
	for _, p in ipairs(CollectionService:GetTagged(BOAT_HULL_TAG)) do
		local m = p:FindFirstAncestorOfClass("Model")
		if m then boatModel = m; break end
	end
	if boatModel then
		boatSnapshot = snapshotModel(boatModel)
	end

	-- Dock: anchored already, but snapshot CFrame in case anything nudges it.
	local map = workspace:FindFirstChild("PhishMap")
	local dock = map and map:FindFirstChild("PhishDock")
	if dock then
		for _, p in ipairs(dock:GetChildren()) do
			if p:IsA("BasePart") and p.Anchored then
				table.insert(dockSnapshots, { part = p, cframe = p.CFrame, anchored = true })
			end
		end
	end
end

local function resetBoat()
	local snap = boatSnapshot
	if not snap or not snap.model.Parent then return end
	-- The boat is kinematic (anchored hull, parts welded). PivotTo is the
	-- correct primitive — it preserves the welded rig's relative geometry
	-- and we don't need to mess with per-part CFrames or velocities.
	snap.model:PivotTo(snap.pivot)
	-- Tell RowboatService to re-record the locked Y in case spawn pose
	-- differs from the snapshot moment for any reason.
	local hull = snap.model.PrimaryPart
	if hull then
		local ok, RowboatService = pcall(function()
			return require(script.Parent:WaitForChild("RowboatService"))
		end)
		if ok and RowboatService and RowboatService.RelockY then
			RowboatService.RelockY(hull)
		end
	end
end

local function resetDock()
	for _, ps in ipairs(dockSnapshots) do
		if ps.part.Parent and ps.part.CFrame ~= ps.cframe then
			ps.part.CFrame = ps.cframe
		end
	end
end

local function resetMap()
	resetBoat()
	resetDock()
end

-- ---------------------------------------------------------------------------
-- Shop NPC consolidation. The standalone PhishFishermanShop building was
-- replaced: the shop UI now opens from the TutorialNPC's ProximityPrompt
-- inside PhishSellShop. Run-time fix-up so we don't have to ship a
-- regenerated map file just to apply this design change.
-- ---------------------------------------------------------------------------

local function consolidateShopNpcs()
	local map = workspace:FindFirstChild("PhishMap")
	if not map then return end

	-- 1. Delete the legacy fisherman shop building entirely.
	local legacy = map:FindFirstChild("PhishFishermanShop")
	if legacy then
		legacy:Destroy()
		print("[PHISH] MapIntegrity: removed legacy PhishFishermanShop building.")
	end

	-- 2. Hook the shop UI to the TutorialNPC's trigger inside PhishSellShop.
	local sellShop = map:FindFirstChild("PhishSellShop")
	local tutorialNpc = sellShop and sellShop:FindFirstChild("TutorialNPC")
	local trigger = tutorialNpc and tutorialNpc:FindFirstChild("Trigger")
	if not trigger or not trigger:IsA("BasePart") then return end

	-- The ShopController identifies shop triggers by tag + ShopType attribute.
	if not CollectionService:HasTag(trigger, "PhishShopTrigger") then
		CollectionService:AddTag(trigger, "PhishShopTrigger")
	end
	if trigger:GetAttribute("ShopType") ~= "Powerup" then
		trigger:SetAttribute("ShopType", "Powerup")
	end

	-- Idempotent ProximityPrompt with the requested copy.
	local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = trigger
	end
	prompt.ActionText = "E to interact"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = true
end

function MapIntegrityService.Init()
	makeAllWaterNonCollide()
	-- Catch any tile added later (e.g. live editing, deferred map gen).
	CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(makeWaterNonCollide)
	ensureEscapeRamps()
	hideAllVehicleSeatHuds()
	CollectionService:GetInstanceAddedSignal(BOAT_SEAT_TAG):Connect(hideVehicleSeatHud)
	consolidateShopNpcs()

	takeSnapshots()

	-- Reset on every spawn (initial join + post-death respawn). Reset on
	-- player leaving so the next joiner finds a clean boat.
	local function hookRespawn(player: Player)
		player.CharacterAdded:Connect(function()
			-- Small delay so any teleport-on-spawn logic settles first.
			task.delay(0.5, resetMap)
		end)
		if player.Character then resetMap() end
	end
	for _, p in ipairs(Players:GetPlayers()) do hookRespawn(p) end
	Players.PlayerAdded:Connect(hookRespawn)
	Players.PlayerRemoving:Connect(function() resetMap() end)
end

-- Public API for other services (e.g. RowboatService when it lands).
function MapIntegrityService.ResetMap() resetMap() end
function MapIntegrityService.ResetBoat() resetBoat() end

return MapIntegrityService
