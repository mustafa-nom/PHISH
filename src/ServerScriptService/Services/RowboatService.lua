--!strict
-- Kinematic arcade rowboat. Physics-free, can't fall through anything.
--
-- The hull is anchored. Every other boat part is welded to the hull so the
-- whole rig moves as one rigid body when we PivotTo it. Driving is purely
-- CFrame-based: forward/back along the hull's RightVector, yaw on the
-- world-up axis. Y is locked to the boat's starting height — the boat
-- simply cannot sink, fall through tiles, or drift below the surface.
--
-- A VehicleSeat (tagged PhishBoatSeat) provides the input via its
-- ThrottleFloat / SteerFloat. We only drive while a Humanoid occupies the
-- seat, so an empty boat parks cleanly at its last spot instead of
-- coasting on stale input.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))

local RowboatService = {}

local BOAT_HULL_TAG = PhishConstants.Tags.BoatHull
local BOAT_SEAT_TAG = PhishConstants.Tags.BoatSeat
local BOAT_MODEL_NAMES = { "PhishBoat", "Rowboat" }
local HULL_PART_NAMES = { "Hull" }

local SPEED = 32                -- studs/sec at full throttle
local TURN_SPEED = 2.4          -- rad/sec at full steer

type BoatState = {
	model: Model,
	hull: BasePart,
	seat: VehicleSeat,
	lockedY: number,            -- the Y the boat will never leave
}

local boats: { [BasePart]: BoatState } = {}

-- Strip any leftover physics constraints from previous physics-based
-- rowboat experiments. They will fight the kinematic CFrame motion if left
-- in place.
local function clearPhysicsArtifacts(model: Model)
	for _, name in ipairs({
		"BoatLinearVelocity", "BoatAngularVelocity", "BoatStability",
		"BoatConstraintAttachment", "HACK_BoatDriver",
	}) do
		local existing = model:FindFirstChild(name, true)
		while existing do
			existing:Destroy()
			existing = model:FindFirstChild(name, true)
		end
	end
end

local function findSeat(model: Model): VehicleSeat?
	-- Prefer a tagged seat, fall back to any VehicleSeat in the rig.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("VehicleSeat") and CollectionService:HasTag(descendant, BOAT_SEAT_TAG) then
			return descendant
		end
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("VehicleSeat") then
			CollectionService:AddTag(descendant, BOAT_SEAT_TAG)
			return descendant
		end
	end
	-- Last resort: a regular Seat. We won't get throttle/steer input but at
	-- least the player can sit on it and the boat is still anchored stable.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Seat") then
			CollectionService:AddTag(descendant, BOAT_SEAT_TAG)
			return descendant :: any
		end
	end
	return nil
end

-- Find every boat-shaped model in the workspace and tag its hull + seat so
-- setupBoat picks them up. This is defensive: if a teammate rebuilds the
-- boat and forgets to re-apply tags, we still recognize it by name.
local function discoverBoats(): { BasePart }
	local hulls: { BasePart } = {}
	-- 1. Anything already tagged.
	for _, p in ipairs(CollectionService:GetTagged(BOAT_HULL_TAG)) do
		if p:IsA("BasePart") then table.insert(hulls, p) end
	end
	-- 2. Walk the workspace looking for a Model named PhishBoat / Rowboat
	--    that contains a part named Hull (or has a VehicleSeat).
	local function scan(parent: Instance)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("Model") then
				local matchesName = false
				for _, n in ipairs(BOAT_MODEL_NAMES) do
					if child.Name == n then matchesName = true; break end
				end
				if matchesName then
					local hull: BasePart? = nil
					for _, hn in ipairs(HULL_PART_NAMES) do
						local found = child:FindFirstChild(hn)
						if found and found:IsA("BasePart") then hull = found; break end
					end
					if not hull then
						-- Fall back to PrimaryPart, then largest BasePart.
						hull = child.PrimaryPart
						if not hull then
							local biggestVol = 0
							for _, d in ipairs(child:GetDescendants()) do
								if d:IsA("BasePart") then
									local v = d.Size.X * d.Size.Y * d.Size.Z
									if v > biggestVol then hull = d; biggestVol = v end
								end
							end
						end
					end
					if hull and not CollectionService:HasTag(hull, BOAT_HULL_TAG) then
						CollectionService:AddTag(hull, BOAT_HULL_TAG)
						table.insert(hulls, hull)
					end
				else
					scan(child)
				end
			elseif child:IsA("Folder") then
				scan(child)
			end
		end
	end
	scan(Workspace)
	return hulls
end

local function rigidify(hull: BasePart, model: Model)
	-- Anchor + collide on the hull. Anchor + weld every other part so the
	-- whole boat moves as one when we PivotTo. Welds re-anchor implicitly,
	-- but keeping each part Anchored=true is belt-and-suspenders against
	-- streaming or reparenting kicking off physics.
	hull.Anchored = true
	hull.CanCollide = true

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= hull then
			part.Anchored = true
			-- Decorative side rails / sterns shouldn't block the player from
			-- entering or exiting the seat.
			if part.Name:find("Side") or part.Name == "DriverSeat" then
				part.CanCollide = false
			end
			-- Re-establish a weld to the hull. WeldConstraint is forgiving
			-- about CFrame changes — better than Weld for this.
			local existing = part:FindFirstChild("BoatWeld")
			if existing then existing:Destroy() end
			local weld = Instance.new("WeldConstraint")
			weld.Name = "BoatWeld"
			weld.Part0 = hull
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function setupBoat(hull: BasePart)
	if boats[hull] then return end
	local model = hull:FindFirstAncestorOfClass("Model")
	if not model then return end
	local seat = findSeat(model)
	if not seat then
		warn("[PHISH] RowboatService: " .. model:GetFullName() .. " has no PhishBoatSeat VehicleSeat.")
		return
	end

	clearPhysicsArtifacts(model)
	rigidify(hull, model)
	if not model.PrimaryPart then model.PrimaryPart = hull end

	boats[hull] = {
		model = model,
		hull = hull,
		seat = seat,
		lockedY = hull.Position.Y,
	}
	print(("[PHISH] RowboatService: kinematic boat ready %s (lockedY=%.2f)"):format(hull:GetFullName(), hull.Position.Y))
end

local function cleanupBoat(hull: BasePart)
	boats[hull] = nil
end

local function tick(dt: number)
	for hull, state in pairs(boats) do
		if not hull.Parent then continue end
		local seat = state.seat
		-- Only drive when an occupant is steering. An empty boat sits.
		if not seat.Occupant then continue end

		local throttle = seat.ThrottleFloat
		local steer = seat.SteerFloat
		if throttle == 0 and steer == 0 then continue end

		local pivot = state.model:GetPivot()
		-- This boat's "forward" is its RightVector (matches the hull
		-- orientation set up in Studio). Keep that convention.
		local forward = pivot.RightVector
		-- Strip any pitch/roll that crept in. We only ever rotate around Y.
		local yaw = CFrame.Angles(0, -steer * TURN_SPEED * dt, 0)

		local nextPos = pivot.Position + forward * (throttle * SPEED * dt)
		nextPos = Vector3.new(nextPos.X, state.lockedY, nextPos.Z)

		-- Rebuild a clean upright CFrame at the new position. Discards any
		-- accidental tilt and locks Y to the spawn height.
		local nextCFrame = CFrame.new(nextPos) * CFrame.fromEulerAnglesYXZ(0, math.atan2(-forward.X, -forward.Z), 0) * yaw

		state.model:PivotTo(nextCFrame)
	end
end

function RowboatService.Init()
	for _, hull in ipairs(discoverBoats()) do
		setupBoat(hull)
	end
	CollectionService:GetInstanceAddedSignal(BOAT_HULL_TAG):Connect(function(p)
		if p:IsA("BasePart") then setupBoat(p) end
	end)
	CollectionService:GetInstanceRemovedSignal(BOAT_HULL_TAG):Connect(function(p)
		if p:IsA("BasePart") then cleanupBoat(p) end
	end)

	RunService.Heartbeat:Connect(tick)
end

-- Public API for MapIntegrityService.resetBoat to re-record the locked Y
-- after a teleport to spawn pose.
function RowboatService.RelockY(hull: BasePart)
	local state = boats[hull]
	if state then state.lockedY = hull.Position.Y end
end

return RowboatService
