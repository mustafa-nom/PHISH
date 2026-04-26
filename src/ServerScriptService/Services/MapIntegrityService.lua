--!strict
-- Map integrity & soft-lock prevention.
--   1. Every part tagged PhishWaterZone stays non-collide so players can swim
--      through the surface instead of walking on it.
--   2. Snapshots the boat (and dock parts) at boot. On every player respawn
--      / leave, restores them to the snapshot. Prevents the softlock where
--      a drifted boat is unreachable from the lodge spawn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
	makeRamp(folder, "BeachRamp", Vector3.new(10, 0.35, 7),
		CFrame.new(7.4, 0.65, 0) * CFrame.Angles(0, 0, math.rad(-16)))
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
		-- Try to set one from the boat hull, if tagged.
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

	-- Stop any motion before teleporting; otherwise PivotTo can fight live
	-- velocity and the boat slides off again next frame.
	for _, ps in ipairs(snap.parts) do
		if ps.part.Parent then
			ps.part.AssemblyLinearVelocity = Vector3.zero
			ps.part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	snap.model:PivotTo(snap.pivot)
	-- Re-apply each part's snapshot CFrame in case of accumulated drift on
	-- unanchored decorations (rails, sterns).
	for _, ps in ipairs(snap.parts) do
		if ps.part.Parent then
			ps.part.CFrame = ps.cframe
			ps.part.Anchored = ps.anchored
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
-- 3. Boat hovercraft pin. Water tiles are CanCollide=false (so players can
--    swim through), which means an unanchored boat hull falls straight
--    through them. Force-based buoyancy proved finicky (forces fight the
--    VehicleSeat), so we use the original RowboatService's hovercraft
--    approach: every Heartbeat, snap the hull's Y to the water surface
--    while leaving X / Z free for the VehicleSeat to drive.
--
--    One pin per assembly (deduped by AssemblyRootPart).
-- ---------------------------------------------------------------------------

local HOVER_OFFSET = -0.1             -- hull bottom sits this far below water
local HOVER_RAYCAST_UP = 16
local HOVER_RAYCAST_DOWN = 40

local hullParts: { [BasePart]: boolean } = {}

local function bindHull(inst: Instance)
	if inst:IsA("BasePart") then
		hullParts[inst] = true
	end
end

local function unbindHull(inst: Instance)
	if inst:IsA("BasePart") then
		hullParts[inst] = nil
	end
end

local function waterSurfaceUnder(part: BasePart): number?
	local map = Workspace:FindFirstChild("PhishMap")
	local waterFolder = map and map:FindFirstChild("PhishWater")
	if not waterFolder then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { waterFolder }
	params.IgnoreWater = true
	local origin = part.Position + Vector3.new(0, HOVER_RAYCAST_UP, 0)
	local direction = Vector3.new(0, -(HOVER_RAYCAST_UP + HOVER_RAYCAST_DOWN), 0)
	local result = Workspace:Raycast(origin, direction, params)
	if result and result.Instance and CollectionService:HasTag(result.Instance, WATER_TAG) then
		return result.Position.Y
	end
	return nil
end

local function pinHovercraft()
	-- Dedupe by assembly so multi-tagged welded boats only get pinned once.
	local seenAssemblies: { [BasePart]: boolean } = {}
	for part in pairs(hullParts) do
		if not part.Parent then
			hullParts[part] = nil
			continue
		end
		if part.Anchored then
			continue
		end
		local rootPart = part.AssemblyRootPart or part
		if seenAssemblies[rootPart] then continue end
		seenAssemblies[rootPart] = true

		local waterY = waterSurfaceUnder(part)
		if not waterY then continue end
		local targetY = waterY + HOVER_OFFSET

		-- Snap Y on the assembly root, preserve X / Z and rotation.
		local cf = rootPart.CFrame
		if math.abs(cf.Y - targetY) > 0.005 then
			rootPart.CFrame = CFrame.new(cf.X, targetY, cf.Z) * (cf - cf.Position)
		end
		-- Zero out vertical velocity so accumulated falling speed doesn't
		-- punch through the pin on the next physics tick. Leave X / Z so
		-- VehicleSeat / driver input still moves the boat.
		local v = rootPart.AssemblyLinearVelocity
		if v.Y ~= 0 then
			rootPart.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Init.
-- ---------------------------------------------------------------------------

function MapIntegrityService.Init()
	makeAllWaterNonCollide()
	-- Catch any tile added later (e.g. live editing, deferred map gen).
	CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(makeWaterNonCollide)
	ensureEscapeRamps()
	hideAllVehicleSeatHuds()
	CollectionService:GetInstanceAddedSignal(BOAT_SEAT_TAG):Connect(hideVehicleSeatHud)

	-- Wire hovercraft pin to existing + future BoatHull-tagged parts.
	for _, p in ipairs(CollectionService:GetTagged(BOAT_HULL_TAG)) do
		bindHull(p)
	end
	CollectionService:GetInstanceAddedSignal(BOAT_HULL_TAG):Connect(bindHull)
	CollectionService:GetInstanceRemovedSignal(BOAT_HULL_TAG):Connect(unbindHull)
	RunService.Heartbeat:Connect(pinHovercraft)

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
