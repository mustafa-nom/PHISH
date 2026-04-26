--!strict
-- Map integrity & soft-lock prevention.
--   1. Every part tagged PhishWaterZone gets CanCollide=true so players can't
--      phase through the surface and die in the void below.
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

-- ---------------------------------------------------------------------------
-- 1. Make water tiles solid.
-- ---------------------------------------------------------------------------

local function solidifyWaterPart(instance: Instance)
	if not instance:IsA("BasePart") then return end
	-- Anchored, walkable. We don't change Anchored or Transparency — only
	-- collision. The map keeps its visual look.
	instance.CanCollide = true
end

local function solidifyAllWater()
	local count = 0
	for _, part in ipairs(CollectionService:GetTagged(WATER_TAG)) do
		if part:IsA("BasePart") and not part.CanCollide then
			part.CanCollide = true
			count += 1
		end
	end
	if count > 0 then
		print(("[PHISH] MapIntegrity: solidified %d water tile(s)."):format(count))
	end
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
-- Init.
-- ---------------------------------------------------------------------------

function MapIntegrityService.Init()
	solidifyAllWater()
	-- Catch any tile added later (e.g. live editing, deferred map gen).
	CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(solidifyWaterPart)

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
