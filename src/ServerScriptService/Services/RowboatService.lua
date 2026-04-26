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

local SPEED = 28                -- studs/sec at full throttle (W=forward)
local REVERSE_SPEED = 14        -- studs/sec at full reverse (S)
local TURN_SPEED = 1.4          -- rad/sec at full steer (A/D), ~80°/sec
-- We sample the yaw angle once per boat and integrate from there. Storing
-- it on the state (instead of re-extracting from the CFrame each frame)
-- avoids any drift from ToEulerAnglesYXZ on a near-flat CFrame.

type BoatState = {
	model: Model,
	hull: BasePart,
	seat: VehicleSeat,
	lockedY: number,            -- the Y the boat will never leave
	yaw: number,                -- current heading in radians around world up
	wake: ParticleEmitter?,     -- water wake VFX behind the stern
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

-- Place a small invisible attachment behind the stern of the boat with a
-- ParticleEmitter on it. The emitter is disabled until the boat moves
-- forward; the tick loop toggles Enabled and adjusts Rate based on speed.
local function buildWake(model: Model, hull: BasePart): ParticleEmitter
	-- Tear down any prior wake emitter from a previous setup pass.
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "BoatWakeAttachment" then d:Destroy() end
	end

	-- Anchor the emitter to whichever part is the back of the boat. We
	-- prefer a part literally named "Stern" but fall back to the hull.
	local sternPart: BasePart = hull
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Stern" then sternPart = d; break end
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "BoatWakeAttachment"
	-- Place the attachment behind and slightly below the stern so the wake
	-- spawns at the waterline directly behind the boat. "Behind" depends
	-- on which axis is the boat's back; we place it at the part's local
	-- origin and let the model orientation point the spray rearward.
	attachment.CFrame = CFrame.new(0, -0.4, sternPart.Size.Z * 0.5 + 0.5)
	attachment.Parent = sternPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BoatWake"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.0)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Drag = 4
	emitter.Enabled = false
	emitter.Parent = attachment
	return emitter
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

	-- Sample the spawn-pose yaw once. The boat's bow points along its
	-- LookVector, so derive yaw from it: L = (-sin θ, 0, -cos θ).
	local lv = hull.CFrame.LookVector
	local startYaw = math.atan2(-lv.X, -lv.Z)

	boats[hull] = {
		model = model,
		hull = hull,
		seat = seat,
		lockedY = hull.Position.Y,
		yaw = startYaw,
		wake = buildWake(model, hull),
	}
	print(("[PHISH] RowboatService: kinematic boat ready %s (lockedY=%.2f, yaw=%.2frad)"):format(hull:GetFullName(), hull.Position.Y, startYaw))
end

local function cleanupBoat(hull: BasePart)
	local state = boats[hull]
	if state and state.wake then
		local att = state.wake.Parent
		state.wake:Destroy()
		if att and att:IsA("Attachment") and att.Name == "BoatWakeAttachment" then
			att:Destroy()
		end
	end
	boats[hull] = nil
end

-- Clamp a per-frame delta so a frame-rate spike can't teleport the boat.
local function clamp(x: number, lo: number, hi: number): number
	if x < lo then return lo end
	if x > hi then return hi end
	return x
end

local function tick(dt: number)
	dt = clamp(dt, 0, 0.1)
	for hull, state in pairs(boats) do
		if not hull.Parent then continue end
		local seat = state.seat
		-- Only drive when an occupant is steering. An empty boat sits.
		if not seat.Occupant then continue end

		local throttle = seat.ThrottleFloat   -- W = +1, S = -1
		local steer = seat.SteerFloat         -- A = -1, D = +1
		if throttle == 0 and steer == 0 then continue end

		-- Integrate yaw from the boat's stored heading. We never re-derive
		-- it from the CFrame each frame — that's what was making rotation
		-- feel unstable / spin-y in the previous version.
		state.yaw -= steer * TURN_SPEED * dt

		-- Forward speed: full SPEED forward, half SPEED reverse so backing
		-- up doesn't outrun the player.
		local speed = if throttle >= 0 then SPEED else REVERSE_SPEED
		local distance = throttle * speed * dt

		-- Build a clean upright CFrame from yaw, then translate along the
		-- boat's LookVector (the bow direction).
		local pivot = state.model:GetPivot()
		local pos = pivot.Position
		local heading = CFrame.new(pos.X, state.lockedY, pos.Z) * CFrame.Angles(0, state.yaw, 0)
		local nextCFrame = heading + heading.LookVector * distance

		state.model:PivotTo(nextCFrame)

		-- Wake VFX: more particles the faster we're going forward, off in
		-- reverse and when idling.
		if state.wake then
			if throttle > 0.05 then
				state.wake.Enabled = true
				state.wake.Rate = 30 + 60 * throttle
			else
				state.wake.Enabled = false
			end
		end
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
-- and yaw after a teleport to spawn pose.
function RowboatService.RelockY(hull: BasePart)
	local state = boats[hull]
	if not state then return end
	state.lockedY = hull.Position.Y
	local lv = hull.CFrame.LookVector
	state.yaw = math.atan2(-lv.X, -lv.Z)
end

return RowboatService
