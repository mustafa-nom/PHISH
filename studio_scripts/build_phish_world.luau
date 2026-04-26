-- build_phish_world.luau
-- Builds the Workspace.PhishMap world (island, lodge, dock, water, boat, shops).
-- Templates (fish, bobbers, lures) live in build_phish_templates.luau — run that next.
-- Run via: Studio Command Bar (View > Command Bar > paste > Enter), or MCP execute_luau.
-- Idempotent: re-running wipes Workspace.PhishMap and rebuilds.
-- Contract source of truth: prompts/user1_map_prompt.md (Shared Contract section).

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local C3 = Color3.fromRGB
local V3 = Vector3.new
local CF = CFrame.new

local WOOD = C3(130, 90, 60)
local SAND = C3(240, 220, 180)
local GRASS = C3(140, 200, 110)
local LANTERN = C3(255, 220, 150)
local GLASS = C3(180, 220, 240)

local TIER_COLORS = {
	Beginner = C3(64, 200, 200),
	Intermediate = C3(40, 100, 200),
	Expert = C3(100, 50, 160),
	Legendary = C3(180, 40, 60),
}
local TIER_RODS = { Beginner = 1, Intermediate = 2, Expert = 3, Legendary = 4 }

local function mkPart(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function tag(inst, t) CollectionService:AddTag(inst, t) end
local function attr(inst, k, v) inst:SetAttribute(k, v) end

local function weldTo(primary, others)
	for _, child in ipairs(others) do
		if child:IsA("BasePart") and child ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = child
			w.Parent = primary
		end
	end
end

local function lantern(parent, pos)
	mkPart("LanternPost", parent, { Size = V3(0.4, 4, 0.4), Color = WOOD, Material = Enum.Material.Wood, CFrame = CF(pos + V3(0, 2, 0)) })
	local glow = mkPart("LanternGlow", parent, { Size = V3(1, 1, 1), Color = LANTERN, Material = Enum.Material.Neon, CFrame = CF(pos + V3(0, 4.2, 0)), Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Color = LANTERN; light.Range = 12; light.Brightness = 1.5; light.Parent = glow
end

local function purge(container, name)
	local existing = container:FindFirstChild(name); if existing then existing:Destroy() end
end

-- ============================================================
-- BLOCK 1 — Foundation
-- ============================================================
local function buildFoundation()
	purge(Workspace, "PhishMap")
	-- Wipe legacy Buddy Bridge containers if present (do not touch Rojo-mapped src/ folders).
	for _, legacyName in ipairs({ "Lobby", "PlayAreas", "PlayAreaSlots", "GuideBooths" }) do
		local node = Workspace:FindFirstChild(legacyName)
		if node then node:Destroy() end
	end
	-- Default SpawnLocation cleanup
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("SpawnLocation") and child.Name == "SpawnLocation" then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 17.5
	-- Technology requires RobloxScript capability (plugin sandbox can't set it). Skip if denied.
	pcall(function() Lighting.Technology = Enum.Technology.ShadowMap end)
	Lighting.Ambient = C3(180, 130, 90)
	Lighting.OutdoorAmbient = C3(120, 90, 60)
	Lighting.Brightness = 2
	Lighting.FogEnd = 600
	Lighting.FogStart = 200
	Lighting.FogColor = C3(255, 200, 150)
	Workspace.Gravity = 196.2

	local map = Instance.new("Folder")
	map.Name = "PhishMap"
	map.Parent = Workspace
	return map
end

-- ============================================================
-- BLOCK 2 — Island
-- ============================================================
local function buildIsland(map)
	local island = Instance.new("Folder")
	island.Name = "PhishIsland"
	island.Parent = map

	mkPart("Beach", island, {
		Size = V3(80, 1, 80), Color = SAND, Material = Enum.Material.Sand,
		CFrame = CF(0, 0.5, 0), Shape = Enum.PartType.Block,
	})
	mkPart("Grass", island, {
		Size = V3(56, 1, 56), Color = GRASS, Material = Enum.Material.Grass,
		CFrame = CF(0, 1.5, 0),
	})

	-- Palm trees
	local palmSpots = {
		V3(-22, 0, -22), V3(22, 0, -22), V3(-22, 0, 22),
		V3(22, 0, 22), V3(0, 0, -28),
	}
	for i, spot in ipairs(palmSpots) do
		local trunk = mkPart("PalmTrunk_" .. i, island, {
			Size = V3(1, 12, 1), Color = WOOD, Material = Enum.Material.Wood,
			CFrame = CF(spot + V3(0, 8, 0)),
		})
		mkPart("PalmFronds_" .. i, island, {
			Size = V3(8, 1.5, 8), Color = C3(60, 160, 70), Material = Enum.Material.Grass,
			CFrame = CF(trunk.Position + V3(0, 6.5, 0)),
		})
	end

	-- Tide pools
	local tideSpots = { V3(-30, 0, 6), V3(28, 0, -8) }
	for i, spot in ipairs(tideSpots) do
		mkPart("TidePool_" .. i, island, {
			Size = V3(6, 0.4, 6), Color = C3(80, 180, 200), Material = Enum.Material.Glass,
			CFrame = CF(spot + V3(0, 1.2, 0)), Transparency = 0.3,
		})
	end

	-- Stone paths
	mkPart("PathToDock", island, {
		Size = V3(20, 0.2, 4), Color = C3(180, 180, 170), Material = Enum.Material.Slate,
		CFrame = CF(15, 1.6, 0),
	})
	mkPart("PathToBoat", island, {
		Size = V3(4, 0.2, 14), Color = C3(180, 180, 170), Material = Enum.Material.Slate,
		CFrame = CF(20, 1.6, 12),
	})
	return island
end

-- ============================================================
-- BLOCK 3 — Lodge
-- ============================================================
local function buildLodge(map)
	local lodge = Instance.new("Model")
	lodge.Name = "PhishLodge"
	lodge.Parent = map

	local origin = V3(-20, 2, 0)
	local floor = mkPart("Floor", lodge, {
		Size = V3(16, 0.4, 16), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(0, -1.7, 0)),
	})
	-- Walls (open archway facing east, +X)
	mkPart("WallN", lodge, { Size = V3(16, 6, 0.4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(0, 1.5, -8)) })
	mkPart("WallS", lodge, { Size = V3(16, 6, 0.4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(0, 1.5, 8)) })
	mkPart("WallW", lodge, { Size = V3(0.4, 6, 16), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(-8, 1.5, 0)) })
	-- East wall has archway: two short segments
	mkPart("WallE_N", lodge, { Size = V3(0.4, 6, 5), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(8, 1.5, -5.5)) })
	mkPart("WallE_S", lodge, { Size = V3(0.4, 6, 5), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(8, 1.5, 5.5)) })
	mkPart("WallE_Top", lodge, { Size = V3(0.4, 2, 6), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(8, 3.5, 0)) })

	-- Sloped roof (two wedges)
	local roofN = Instance.new("WedgePart")
	roofN.Anchored = true; roofN.Size = V3(8, 4, 16); roofN.Color = C3(100, 60, 40)
	roofN.Material = Enum.Material.WoodPlanks
	roofN.CFrame = CF(origin + V3(-4, 6.5, 0)) * CFrame.Angles(0, math.rad(180), 0)
	roofN.Parent = lodge
	local roofS = Instance.new("WedgePart")
	roofS.Anchored = true; roofS.Size = V3(8, 4, 16); roofS.Color = C3(100, 60, 40)
	roofS.Material = Enum.Material.WoodPlanks
	roofS.CFrame = CF(origin + V3(4, 6.5, 0))
	roofS.Parent = lodge

	-- Lanterns inside
	lantern(lodge, origin + V3(-5, -1.5, -5))
	lantern(lodge, origin + V3(5, -1.5, 5))

	-- Aquarium volume (glass-fronted Part)
	local aquarium = mkPart("Aquarium", lodge, {
		Size = V3(12, 6, 4), Color = GLASS, Material = Enum.Material.Glass,
		CFrame = CF(origin + V3(0, 1, -7.6)), Transparency = 0.5,
	})
	tag(aquarium, "PhishAquariumDisplay")
	-- Aquarium origin anchor (named, referenced by User 2 as workspace.PhishMap.PhishLodge.AquariumOrigin)
	local aqOrigin = mkPart("AquariumOrigin", lodge, {
		Size = V3(0.5, 0.5, 0.5), Transparency = 1, CanCollide = false,
		CFrame = CF(origin + V3(0, 1, -7.6)),
	})
	aqOrigin.Name = "AquariumOrigin"

	-- Spawn point just outside the archway
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PhishSpawn"
	spawn.Anchored = true
	spawn.Size = V3(6, 1, 6)
	spawn.CFrame = CF(origin + V3(11, -1.5, 0))
	spawn.Color = C3(255, 200, 100)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lodge
	tag(spawn, "PhishLodgeSpawn")

	lodge.PrimaryPart = floor
	return lodge
end

-- ============================================================
-- BLOCK 4 — Dock
-- ============================================================
local function buildDock(map)
	local dock = Instance.new("Model")
	dock.Name = "PhishDock"
	dock.Parent = map

	-- Dock extends east from beach edge (~+8) out to ~+34
	local planks = mkPart("Planks", dock, {
		Size = V3(26, 0.4, 6), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(21, 1.4, 0),
	})

	-- Lantern posts at intervals along the dock
	for i = 0, 2 do
		local x = 12 + i * 8
		lantern(dock, V3(x, 1.4, -3))
		lantern(dock, V3(x, 1.4, 3))
	end

	-- 4-stud step bridging the dock tip to the boat's port side at z=4.
	mkPart("BoatStep", dock, {
		Size = V3(4, 0.4, 4), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(35, 1.4, 4),
	})

	-- Swim escape ramps. These make it possible to walk back onto the dock
	-- from non-colliding water without needing a perfect jump.
	mkPart("DockRampNorth", dock, {
		Size = V3(6, 0.35, 4), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(27, 0.75, -4.4) * CFrame.Angles(math.rad(-18), 0, 0),
	})
	mkPart("DockRampSouth", dock, {
		Size = V3(6, 0.35, 4), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(27, 0.75, 4.4) * CFrame.Angles(math.rad(18), 0, 0),
	})
	mkPart("DockTipRamp", dock, {
		Size = V3(5, 0.35, 4), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(35.2, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-18)),
	})
	-- mkPart("BeachRamp", dock, {
	-- 	Size = V3(10, 0.35, 7), Color = C3(194, 144, 86), Material = Enum.Material.WoodPlanks,
	-- 	CFrame = CF(7.4, 0.65, 0) * CFrame.Angles(0, 0, math.rad(-16)),
	-- })

	-- Cast zones at the water-facing tip (3 of them spread across the tip)
	for i = 1, 3 do
		local zone = mkPart("CastZone_" .. i, dock, {
			Size = V3(2, 0.2, 2), Color = C3(255, 230, 120),
			Material = Enum.Material.Neon, Transparency = 0.4,
			CFrame = CF(33, 1.7, -2 + (i - 1) * 2),
		})
		tag(zone, "PhishCastZone")
	end

	-- CastAnchor at dock tip (User 2 spawns lures from this Part's Position)
	local anchor = mkPart("CastAnchor", dock, {
		Size = V3(0.5, 0.5, 0.5), Transparency = 1, CanCollide = false,
		CFrame = CF(34, 2, 0),
	})
	anchor.Name = "CastAnchor"

	dock.PrimaryPart = planks
	return dock
end

-- ============================================================
-- BLOCK 5 — Water tile grid (12x12, concentric difficulty rings)
-- ============================================================
-- Water grid lives in studio_scripts/build_phish_water.luau (50x50 biome
-- variant). The world builder only stamps a placeholder folder so the
-- contract's `Workspace.PhishMap.PhishWater` path exists immediately.
local function buildWater(map)
	local water = Instance.new("Folder")
	water.Name = "PhishWater"
	water.Parent = map
	return water, 0
end

-- ============================================================
-- BLOCK 6 — Rowboat
-- ============================================================
local function buildBoat(map)
	local boat = Instance.new("Model")
	boat.Name = "PhishBoat"
	boat.Parent = map

	-- Boat is parked abutting the dock tip (dock ends at x=34; hull spans x=34→x=42).
	local origin = V3(38, 1.5, 4)
	local hull = mkPart("Hull", boat, {
		Size = V3(8, 1, 4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin),
		-- HACKATHON FALLBACK: Hull anchored so the boat stays put. User 2's hovercraft
		-- physics replaces this — they should set Anchored=false and add VectorForce/
		-- AlignOrientation. Marked via HACK_AnchoredUntilHovercraftLands attribute.
		Anchored = true,
	})
	hull:SetAttribute("HACK_AnchoredUntilHovercraftLands", true)
	tag(hull, "PhishBoatHull")

	local bow = Instance.new("WedgePart")
	bow.Name = "Bow"
	bow.Anchored = false; bow.Size = V3(2, 1, 4); bow.Color = WOOD
	bow.Material = Enum.Material.Wood
	bow.CFrame = CF(origin + V3(5, 0, 0))
	bow.Parent = boat

	mkPart("Stern", boat, {
		Size = V3(1, 1.5, 4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(-4, 0.25, 0)), Anchored = false,
	})
	-- Side rims: CanCollide false so they don't fence players away from the seats.
	mkPart("SideN", boat, {
		Size = V3(8, 1, 0.4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(0, 0.5, -2)), Anchored = false, CanCollide = false,
	})
	mkPart("SideS", boat, {
		Size = V3(8, 1, 0.4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(origin + V3(0, 0.5, 2)), Anchored = false, CanCollide = false,
	})

	local driver = Instance.new("VehicleSeat")
	driver.Name = "DriverSeat"
	driver.Anchored = false
	driver.CanCollide = false
	driver.Size = V3(2, 0.5, 2)
	driver.Color = C3(180, 60, 60)
	driver.CFrame = CF(origin + V3(2, 0.75, 0))
	pcall(function() driver.HeadsUpDisplay = false end)
	driver.Parent = boat
	tag(driver, "PhishBoatSeat")
	attr(driver, "IsDriver", true)

	local passengerSpots = { V3(-1, 0.75, 0), V3(0, 0.75, -1), V3(0, 0.75, 1) }
	for i, spot in ipairs(passengerSpots) do
		local seat = Instance.new("Seat")
		seat.Name = "PassengerSeat_" .. i
		seat.Anchored = false
		seat.CanCollide = false
		seat.Size = V3(2, 0.5, 1)
		seat.Color = C3(160, 120, 80)
		seat.CFrame = CF(origin + spot)
		seat.Parent = boat
		tag(seat, "PhishBoatSeat")
		attr(seat, "IsDriver", false)
	end

	-- Weld every part to the Hull so the boat moves as one when User 2 swaps Anchored=false
	-- and drives via Hull.CFrame or VectorForce.
	weldTo(hull, boat:GetChildren())

	-- HACKATHON FALLBACK: placeholder driver Script so the boat moves with WASD before
	-- User 2's hovercraft physics ships. Readable source at studio_scripts/hack_boat_driver.server.luau.
	local driverScript = Instance.new("Script")
	driverScript.Name = "HACK_BoatDriver"
	driverScript.Source = [[
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService"))

local boat = script.Parent
local hull = boat:WaitForChild("Hull")
local driver = boat:WaitForChild("DriverSeat")

local SPEED = 24
local TURN = 1.4
local ROD_TOOL_NAME = "PhishRod"

local jumpConnections = {}
local seatByHumanoid = {}

local function playerFromHumanoid(humanoid)
	local character = humanoid and humanoid.Parent
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function containerHasRod(container)
	if not container then return false end
	local tool = container:FindFirstChild(ROD_TOOL_NAME)
	return tool ~= nil and (tool:GetAttribute("PhishRod") == true or tool:IsA("Tool"))
end

local function playerHasRod(player)
	if containerHasRod(player.Character) then return true end
	if containerHasRod(player:FindFirstChildOfClass("Backpack")) then return true end
	return DataService.Get(player).rodGiven == true
end

local function notify(player, message)
	RemoteService.FireClient(player, "Notify", {
		kind = "Error",
		message = message,
		duration = 3,
	})
end

local function dismount(humanoid, seat)
	if not humanoid or humanoid.Health <= 0 then return end
	local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	humanoid.Sit = false
	if root and root:IsA("BasePart") then
		local side = hull.CFrame.RightVector
		local back = -hull.CFrame.LookVector
		root.CFrame = CFrame.new(seat.Position + side * 5 + back * 2 + Vector3.new(0, 3, 0))
	end
end

local function bindSeat(seat)
	if not seat:IsA("Seat") and not seat:IsA("VehicleSeat") then return end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if not humanoid then return end
		local player = playerFromHumanoid(humanoid)
		if not player then return end

		if not playerHasRod(player) then
			dismount(humanoid, seat)
			notify(player, "Grab a fishing rod before boarding the boat.")
			return
		end

		if jumpConnections[humanoid] and seatByHumanoid[humanoid] == seat then return end
		if jumpConnections[humanoid] then jumpConnections[humanoid]:Disconnect() end
		seatByHumanoid[humanoid] = seat
		jumpConnections[humanoid] = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
			if humanoid.Jump and humanoid.SeatPart == seat then
				dismount(humanoid, seat)
			end
		end)
	end)
end

for _, descendant in ipairs(boat:GetDescendants()) do
	bindSeat(descendant)
end

boat.DescendantAdded:Connect(bindSeat)

RunService.Heartbeat:Connect(function(dt)
	local throttle = driver.ThrottleFloat or 0
	local steer = driver.SteerFloat or 0
	if throttle == 0 and steer == 0 then return end
	local fwd = hull.CFrame.RightVector * (throttle * SPEED * dt)
	local rot = CFrame.fromEulerAnglesYXZ(0, -steer * TURN * dt, 0)
	hull.CFrame = (hull.CFrame + fwd) * rot
end)
]]
	driverScript.Parent = boat
	boat:SetAttribute("HACK_HasPlaceholderDriver", true)

	boat.PrimaryPart = hull
	return boat
end

-- ============================================================
-- BLOCK 7 + 8 — Shop builder (DRY)
-- ============================================================
local function buildShop(map, name, signText, shopType, position, accentColor)
	local shop = Instance.new("Model")
	shop.Name = name
	shop.Parent = map

	local floor = mkPart("Floor", shop, {
		Size = V3(8, 0.4, 8), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(position + V3(0, 0.7, 0)),
	})
	-- Three walls (front open)
	mkPart("BackWall", shop, { Size = V3(8, 5, 0.4), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(position + V3(0, 3, -4)) })
	mkPart("LeftWall", shop, { Size = V3(0.4, 5, 8), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(position + V3(-4, 3, 0)) })
	mkPart("RightWall", shop, { Size = V3(0.4, 5, 8), Color = WOOD, Material = Enum.Material.Wood,
		CFrame = CF(position + V3(4, 3, 0)) })
	-- Roof
	mkPart("Roof", shop, { Size = V3(9, 0.4, 9), Color = accentColor, Material = Enum.Material.WoodPlanks,
		CFrame = CF(position + V3(0, 5.5, 0)) })

	-- Counter (front-facing)
	local counter = mkPart("Counter", shop, {
		Size = V3(7, 2, 1.5), Color = WOOD, Material = Enum.Material.WoodPlanks,
		CFrame = CF(position + V3(0, 1.5, 3)),
	})

	-- Sign (SurfaceGui on the back wall, facing forward)
	local signPart = mkPart("Sign", shop, {
		Size = V3(7, 1.5, 0.2), Color = accentColor, Material = Enum.Material.SmoothPlastic,
		CFrame = CF(position + V3(0, 4, -3.8)),
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = signPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = signText
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.TextColor3 = C3(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = sg

	-- Trigger volume (invisible)
	local trigger = mkPart("Trigger", shop, {
		Size = V3(6, 6, 6), Transparency = 1, CanCollide = false,
		CFrame = CF(position + V3(0, 3, 4.5)),
	})
	tag(trigger, "PhishShopTrigger")
	attr(trigger, "ShopType", shopType)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = (shopType == "Sell") and "Sell Fish" or "Shop"
	prompt.ObjectText = signText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	shop.PrimaryPart = floor
	return shop
end

-- ============================================================
-- ORCHESTRATOR
-- ============================================================
local function buildAll()
	local map = buildFoundation()
	buildIsland(map)
	buildLodge(map)
	buildDock(map)
	local _, tileCount = buildWater(map)
	buildBoat(map)
	buildShop(map, "PhishFishermanShop", "FISHERMAN'S WARES", "Powerup", V3(-30, 0, 18), C3(180, 100, 60))
	buildShop(map, "PhishSellShop", "FISH MARKET", "Sell", V3(20, 0, -18), C3(120, 160, 90))
	print(string.format("[PHISH! WORLD] Done. WaterTiles=%d. Run build_phish_templates.luau next.", tileCount))
	return map
end

return buildAll()
