-- build_phish_decor.luau
-- Per-biome flora + 8 hand-placed scattered islets. Depends on
-- Workspace.PhishMap.PhishWater (run build_phish_water.luau first — tiles
-- need their Biome attribute for this to know what to decorate).
-- Idempotent: wipes PhishWaterFlora + PhishIslets and rebuilds.
-- Run via: Studio Command Bar (View > Command Bar > paste > Enter), or MCP execute_luau.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local C3 = Color3.fromRGB
local V3 = Vector3.new
local CF = CFrame.new

local map = Workspace:FindFirstChild("PhishMap"); assert(map, "PhishMap missing")
local oldFlora = map:FindFirstChild("PhishWaterFlora"); if oldFlora then oldFlora:Destroy() end
local oldIslets = map:FindFirstChild("PhishIslets"); if oldIslets then oldIslets:Destroy() end
local flora = Instance.new("Folder"); flora.Name = "PhishWaterFlora"; flora.Parent = map
local islets = Instance.new("Folder"); islets.Name = "PhishIslets"; islets.Parent = map

local function mkPart(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	-- Default flora to non-collidable so boats / players drift through kelp,
	-- buoys, etc. Islet bases set CanCollide back to true via props.
	p.CanCollide = false
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent; return p
end

local rng = Random.new(20260425)

-- Snapshot tile positions per biome from the live map.
local tilesByBiome = { CalmCove = {}, OpenSea = {}, MossyMarsh = {}, StormChannel = {}, Abyss = {} }
for _, t in ipairs(CollectionService:GetTagged("PhishWaterZone")) do
	local biome = t:GetAttribute("Biome")
	if biome and tilesByBiome[biome] then table.insert(tilesByBiome[biome], t.Position) end
end

local function decorate(biomeId, perTilePct, fn)
	for _, pos in ipairs(tilesByBiome[biomeId]) do
		if rng:NextNumber() < perTilePct then fn(pos, rng) end
	end
end
local function near(pos, jitter)
	return Vector3.new(pos.X + rng:NextNumber(-jitter, jitter), 0, pos.Z + rng:NextNumber(-jitter, jitter))
end

-- ====== CALM COVE ======
decorate("CalmCove", 0.30, function(pos)
	local p = near(pos, 5)
	mkPart("LilyPad", flora, { Size = V3(2.5, 0.2, 2.5), Color = C3(120, 180, 90),
		Material = Enum.Material.Grass, Shape = Enum.PartType.Cylinder,
		CFrame = CF(p.X, 0.7, p.Z) * CFrame.Angles(0, 0, math.rad(90)) })
end)
decorate("CalmCove", 0.18, function(pos, r)
	local p = near(pos, 4)
	for i = 1, r:NextInteger(3, 6) do
		local h = r:NextNumber(1.5, 3)
		mkPart("Reed", flora, { Size = V3(0.18, h, 0.18), Color = C3(220, 200, 110),
			Material = Enum.Material.Grass,
			CFrame = CF(p.X + r:NextNumber(-0.6, 0.6), h / 2, p.Z + r:NextNumber(-0.6, 0.6))
				* CFrame.Angles(math.rad(r:NextNumber(-8, 8)), 0, math.rad(r:NextNumber(-8, 8))) })
	end
end)
decorate("CalmCove", 0.08, function(pos)
	local p = near(pos, 5)
	mkPart("DockPost", flora, { Size = V3(0.6, 4, 0.6), Color = C3(95, 65, 45),
		Material = Enum.Material.Wood, CFrame = CF(p.X, 1.5, p.Z) })
	mkPart("DockPostMoss", flora, { Size = V3(0.7, 0.6, 0.7), Color = C3(80, 130, 70),
		Material = Enum.Material.Grass, CFrame = CF(p.X, 3.4, p.Z) })
end)
decorate("CalmCove", 0.05, function(pos, r)
	local p = near(pos, 4)
	mkPart("Sandbar", flora, { Size = V3(r:NextNumber(4, 7), 0.4, r:NextNumber(4, 7)),
		Color = C3(240, 220, 180), Material = Enum.Material.Sand, Shape = Enum.PartType.Cylinder,
		CFrame = CF(p.X, 0.8, p.Z) * CFrame.Angles(0, r:NextNumber(0, math.pi), math.rad(90)) })
end)

-- ====== OPEN SEA ======
decorate("OpenSea", 0.05, function(pos)
	local p = near(pos, 5)
	local body = mkPart("Buoy", flora, { Size = V3(1.4, 1.4, 1.4), Color = C3(220, 80, 60),
		Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball, CFrame = CF(p.X, 1.3, p.Z) })
	mkPart("BuoyTop", flora, { Size = V3(0.4, 1.0, 0.4), Color = C3(40, 40, 40),
		Material = Enum.Material.SmoothPlastic, CFrame = CF(p.X, 2.4, p.Z) })
	local pl = Instance.new("PointLight"); pl.Color = C3(255, 220, 130); pl.Range = 10; pl.Brightness = 1.2; pl.Parent = body
end)
decorate("OpenSea", 0.04, function(pos, r)
	local p = near(pos, 4)
	mkPart("Crate", flora, { Size = V3(2, 1.4, 2), Color = C3(150, 110, 70),
		Material = Enum.Material.WoodPlanks,
		CFrame = CF(p.X, 0.95, p.Z) * CFrame.Angles(0, math.rad(r:NextNumber(0, 360)), 0) })
end)
decorate("OpenSea", 0.06, function(pos, r)
	local p = near(pos, 5)
	local len = r:NextNumber(4, 7)
	mkPart("Driftwood", flora, { Size = V3(len, 0.7, 0.7), Color = C3(120, 90, 65),
		Material = Enum.Material.Wood,
		CFrame = CF(p.X, 0.85, p.Z) * CFrame.Angles(0, math.rad(r:NextNumber(0, 360)), 0) })
end)

-- ====== MOSSY MARSH ======
decorate("MossyMarsh", 0.20, function(pos, r)
	local p = near(pos, 4)
	for i = 1, r:NextInteger(2, 4) do
		local h = r:NextNumber(3, 5)
		mkPart("Kelp", flora, { Size = V3(0.5, h, 0.5), Color = C3(40, 100, 60),
			Material = Enum.Material.Grass,
			CFrame = CF(p.X + r:NextNumber(-1.2, 1.2), h / 2, p.Z + r:NextNumber(-1.2, 1.2))
				* CFrame.Angles(math.rad(r:NextNumber(-12, 12)), 0, math.rad(r:NextNumber(-12, 12))) })
	end
end)
decorate("MossyMarsh", 0.10, function(pos, r)
	local p = near(pos, 4)
	mkPart("MossyRock", flora, { Size = V3(r:NextNumber(2, 3.5), 1.5, r:NextNumber(2, 3.5)),
		Color = C3(95, 95, 80), Material = Enum.Material.Slate,
		CFrame = CF(p.X, 1.25, p.Z) * CFrame.Angles(math.rad(r:NextNumber(-10, 10)), math.rad(r:NextNumber(0, 360)), math.rad(r:NextNumber(-10, 10))) })
	mkPart("MossCap", flora, { Size = V3(2.6, 0.4, 2.6), Color = C3(70, 140, 70),
		Material = Enum.Material.Grass, CFrame = CF(p.X, 2.1, p.Z) })
end)
decorate("MossyMarsh", 0.04, function(pos)
	local p = near(pos, 3)
	mkPart("FrogBody", flora, { Size = V3(1.6, 1.2, 1.4), Color = C3(70, 150, 80),
		Material = Enum.Material.SmoothPlastic, CFrame = CF(p.X, 1.1, p.Z) })
	for _, side in ipairs({-1, 1}) do
		mkPart("FrogEye", flora, { Size = V3(0.4, 0.4, 0.4), Color = C3(255, 255, 255),
			Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball,
			CFrame = CF(p.X + side * 0.4, 1.85, p.Z + 0.5) })
	end
end)

-- ====== STORM CHANNEL ======
decorate("StormChannel", 0.16, function(pos, r)
	local p = near(pos, 5)
	local sx = r:NextNumber(2, 4); local sy = r:NextNumber(1.5, 3)
	mkPart("Rock", flora, { Size = V3(sx, sy, sx), Color = C3(80, 80, 95),
		Material = Enum.Material.Slate,
		CFrame = CF(p.X, sy / 2 + 0.5, p.Z) * CFrame.Angles(math.rad(r:NextNumber(-8, 8)), math.rad(r:NextNumber(0, 360)), math.rad(r:NextNumber(-8, 8))) })
end)
decorate("StormChannel", 0.04, function(pos, r)
	local p = near(pos, 4)
	local h = r:NextNumber(5, 8)
	mkPart("WreckMast", flora, { Size = V3(0.5, h, 0.5), Color = C3(95, 65, 45),
		Material = Enum.Material.Wood,
		CFrame = CF(p.X, h / 2, p.Z) * CFrame.Angles(math.rad(r:NextNumber(15, 35)), math.rad(r:NextNumber(0, 360)), math.rad(r:NextNumber(-10, 10))) })
end)
decorate("StormChannel", 0.03, function(pos)
	local p = near(pos, 3)
	mkPart("AnchorShaft", flora, { Size = V3(0.4, 3, 0.4), Color = C3(45, 45, 55),
		Material = Enum.Material.Metal, CFrame = CF(p.X, 1.5, p.Z) })
	mkPart("AnchorCross", flora, { Size = V3(2.5, 0.4, 0.4), Color = C3(45, 45, 55),
		Material = Enum.Material.Metal, CFrame = CF(p.X, 0.7, p.Z) })
end)
decorate("StormChannel", 0.05, function(pos, r)
	local p = near(pos, 4)
	local h = r:NextNumber(4, 7)
	mkPart("RockSpire", flora, { Size = V3(1.2, h, 1.2), Color = C3(60, 60, 70),
		Material = Enum.Material.Slate,
		CFrame = CF(p.X, h / 2 + 0.5, p.Z) * CFrame.Angles(math.rad(r:NextNumber(-5, 5)), 0, math.rad(r:NextNumber(-5, 5))) })
end)

-- ====== ABYSS ======
decorate("Abyss", 0.10, function(pos)
	local p = near(pos, 4)
	local glow = mkPart("AbyssBuoy", flora, { Size = V3(1.2, 1.2, 1.2), Color = C3(255, 100, 200),
		Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CFrame = CF(p.X, 1.5, p.Z) })
	local pl = Instance.new("PointLight"); pl.Color = C3(255, 100, 200); pl.Range = 18; pl.Brightness = 2.5; pl.Parent = glow
end)
decorate("Abyss", 0.10, function(pos, r)
	local p = near(pos, 4)
	for i = 1, r:NextInteger(3, 5) do
		local h = r:NextNumber(2, 4)
		mkPart("Coral", flora, { Size = V3(0.5, h, 0.5),
			Color = (i % 2 == 0) and C3(180, 80, 220) or C3(80, 200, 220),
			Material = Enum.Material.Neon,
			CFrame = CF(p.X + r:NextNumber(-1.5, 1.5), h / 2 + 0.5, p.Z + r:NextNumber(-1.5, 1.5))
				* CFrame.Angles(math.rad(r:NextNumber(-15, 15)), 0, math.rad(r:NextNumber(-15, 15))) })
	end
end)
decorate("Abyss", 0.08, function(pos, r)
	local p = near(pos, 4)
	mkPart("Monolith", flora, { Size = V3(2, r:NextNumber(6, 9), 2), Color = C3(40, 30, 50),
		Material = Enum.Material.Slate, CFrame = CF(p.X, 4.5, p.Z) * CFrame.Angles(0, math.rad(r:NextNumber(0, 90)), 0) })
	mkPart("MonolithGlow", flora, { Size = V3(2.05, 0.3, 2.05), Color = C3(200, 80, 220),
		Material = Enum.Material.Neon, CFrame = CF(p.X, 1.2, p.Z) })
end)
decorate("Abyss", 0.04, function(pos)
	local p = near(pos, 3)
	mkPart("Whirlpool", flora, { Size = V3(6, 0.2, 6), Color = C3(20, 10, 40),
		Material = Enum.Material.Glass, Shape = Enum.PartType.Cylinder, Transparency = 0.3,
		CFrame = CF(p.X, 0.55, p.Z) * CFrame.Angles(0, 0, math.rad(90)) })
end)

-- ====== SCATTERED ISLETS ======
local function islet(name, pos, build)
	local model = Instance.new("Model"); model.Name = name; model.Parent = islets
	build(model, pos)
end
local function sandBase(model, pos, radius, color)
	mkPart("SandBase", model, { Size = V3(radius * 2, 1.2, radius * 2),
		Color = color or C3(240, 220, 180), Material = Enum.Material.Sand, Shape = Enum.PartType.Cylinder,
		CFrame = CF(pos.X, 1.0, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = true })
end

islet("PalmIslet", V3(-180, 0, -120), function(m, pos)
	sandBase(m, pos, 8)
	mkPart("PalmTrunk", m, { Size = V3(0.8, 8, 0.8), Color = C3(110, 70, 50),
		Material = Enum.Material.Wood, CFrame = CF(pos.X, 5.6, pos.Z) })
	mkPart("PalmFronds", m, { Size = V3(6, 1.3, 6), Color = C3(60, 160, 70),
		Material = Enum.Material.Grass, CFrame = CF(pos.X, 10.2, pos.Z) })
end)
islet("DriftwoodIslet", V3(200, 0, -150), function(m, pos)
	sandBase(m, pos, 6, C3(220, 200, 160))
	for i = 1, 5 do
		local len = 5 + math.random() * 2
		mkPart("Log", m, { Size = V3(len, 0.7, 0.7), Color = C3(110, 80, 55),
			Material = Enum.Material.Wood,
			CFrame = CF(pos.X + (i - 3) * 0.8, 2.0 + math.random() * 0.4, pos.Z + math.random() * 1.6 - 0.8)
				* CFrame.Angles(0, math.rad(i * 27), math.rad(math.random(-12, 12))) })
	end
end)
islet("SpikyRockIslet", V3(-280, 0, 80), function(m, pos)
	mkPart("RockBase", m, { Size = V3(14, 2, 14), Color = C3(70, 70, 85),
		Material = Enum.Material.Slate, Shape = Enum.PartType.Cylinder,
		CFrame = CF(pos.X, 1.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = true })
	for i = 1, 5 do
		local h = 4 + math.random() * 4
		mkPart("Spire", m, { Size = V3(1.2, h, 1.2), Color = C3(60, 60, 75),
			Material = Enum.Material.Slate,
			CFrame = CF(pos.X + math.random(-4, 4), 2 + h / 2, pos.Z + math.random(-4, 4))
				* CFrame.Angles(math.rad(math.random(-6, 6)), 0, math.rad(math.random(-6, 6))) })
	end
end)
islet("LighthouseStub", V3(320, 0, 250), function(m, pos)
	mkPart("Foundation", m, { Size = V3(10, 1.5, 10), Color = C3(70, 70, 80),
		Material = Enum.Material.Slate, Shape = Enum.PartType.Cylinder,
		CFrame = CF(pos.X, 1.0, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = true })
	mkPart("Tower", m, { Size = V3(3.2, 8, 3.2), Color = C3(220, 220, 220),
		Material = Enum.Material.Concrete, Shape = Enum.PartType.Cylinder,
		CFrame = CF(pos.X, 5.5, pos.Z) })
	mkPart("Roof", m, { Size = V3(3.6, 1.2, 3.6), Color = C3(180, 60, 60),
		Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder,
		CFrame = CF(pos.X, 10.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90)) })
	local glow = mkPart("LightGlow", m, { Size = V3(2, 1.5, 2), Color = C3(255, 230, 130),
		Material = Enum.Material.Neon, CFrame = CF(pos.X, 9.0, pos.Z) })
	local pl = Instance.new("PointLight"); pl.Color = C3(255, 230, 130); pl.Range = 30; pl.Brightness = 3; pl.Parent = glow
end)
islet("MarshIslet", V3(-100, 0, 220), function(m, pos)
	mkPart("MossyBase", m, { Size = V3(11, 1.4, 11), Color = C3(95, 130, 80),
		Material = Enum.Material.Grass, Shape = Enum.PartType.Cylinder,
		CFrame = CF(pos.X, 1.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = true })
	for i = 1, 8 do
		local h = 3 + math.random() * 2
		mkPart("Reed", m, { Size = V3(0.18, h, 0.18), Color = C3(220, 200, 110),
			Material = Enum.Material.Grass,
			CFrame = CF(pos.X + math.random(-4, 4), 1.8 + h / 2, pos.Z + math.random(-4, 4)) })
	end
end)
islet("CampfireIslet", V3(280, 0, -50), function(m, pos)
	sandBase(m, pos, 7, C3(230, 210, 170))
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2)
		mkPart("FireLog", m, { Size = V3(2.5, 0.5, 0.5), Color = C3(80, 50, 30),
			Material = Enum.Material.Wood,
			CFrame = CF(pos.X + math.cos(angle) * 1, 2.0, pos.Z + math.sin(angle) * 1) * CFrame.Angles(0, angle + math.pi / 2, 0) })
	end
	local fire = mkPart("Embers", m, { Size = V3(1, 0.4, 1), Color = C3(255, 130, 60),
		Material = Enum.Material.Neon, CFrame = CF(pos.X, 2.0, pos.Z) })
	local pl = Instance.new("PointLight"); pl.Color = C3(255, 150, 60); pl.Range = 12; pl.Brightness = 2; pl.Parent = fire
end)
islet("BirdRock", V3(-220, 0, -280), function(m, pos)
	mkPart("RockBase", m, { Size = V3(8, 4, 8), Color = C3(180, 180, 175),
		Material = Enum.Material.Slate, CanCollide = true,
		CFrame = CF(pos.X, 2.5, pos.Z) * CFrame.Angles(math.rad(math.random(-6, 6)), math.rad(math.random(0, 360)), math.rad(math.random(-6, 6))) })
	mkPart("GuanoCap", m, { Size = V3(8.2, 0.4, 8.2), Color = C3(245, 245, 240),
		Material = Enum.Material.Plaster, CFrame = CF(pos.X, 4.7, pos.Z) })
	for i = 1, 3 do
		mkPart("Bird", m, { Size = V3(0.7, 0.7, 0.7), Color = C3(255, 255, 250),
			Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball,
			CFrame = CF(pos.X + math.random(-3, 3), 5.4, pos.Z + math.random(-3, 3)) })
	end
end)
islet("AbyssMonolith", V3(180, 0, 320), function(m, pos)
	mkPart("Pedestal", m, { Size = V3(6, 1.5, 6), Color = C3(40, 30, 50),
		Material = Enum.Material.Slate, CFrame = CF(pos.X, 1.2, pos.Z),
		CanCollide = true })
	mkPart("Monolith", m, { Size = V3(2, 12, 2), Color = C3(30, 20, 40),
		Material = Enum.Material.Slate, CFrame = CF(pos.X, 8.0, pos.Z) * CFrame.Angles(0, math.rad(15), 0) })
	local glow = mkPart("MonolithRune", m, { Size = V3(2.05, 1.5, 2.05), Color = C3(220, 80, 220),
		Material = Enum.Material.Neon, CFrame = CF(pos.X, 11.0, pos.Z) })
	local pl = Instance.new("PointLight"); pl.Color = C3(220, 80, 220); pl.Range = 24; pl.Brightness = 2.5; pl.Parent = glow
end)

print(string.format("[PHISH! DECOR] Done. Flora=%d Islets=%d", #flora:GetChildren(), #islets:GetChildren()))
return true
