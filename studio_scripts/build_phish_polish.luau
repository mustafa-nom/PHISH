-- build_phish_polish.luau
-- Polish pass: welcome sign at spawn, fireflies near Lodge, tide-pool particles, ambient SFX.
-- Depends on Workspace.PhishMap already existing (run build_phish_world.luau first).
-- Idempotent: re-running wipes Workspace.PhishMap.PhishPolish and rebuilds.
-- Run via: Studio Command Bar (View > Command Bar > paste > Enter), or MCP execute_luau.

local Workspace = game:GetService("Workspace")
local C3 = Color3.fromRGB
local V3 = Vector3.new
local CF = CFrame.new

local map = Workspace:FindFirstChild("PhishMap")
assert(map, "PhishMap missing — run build_phish_world.luau first")

local function mkPart(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent; return p
end

local existing = map:FindFirstChild("PhishPolish")
if existing then existing:Destroy() end
local polish = Instance.new("Folder")
polish.Name = "PhishPolish"
polish.Parent = map

-- Welcome sign at spawn (BillboardGui floating above a wood post).
local lodge = map:FindFirstChild("PhishLodge")
local spawnPart = lodge and lodge:FindFirstChild("PhishSpawn")
if spawnPart then
	mkPart("WelcomeSignPost", polish, {
		Size = V3(0.4, 6, 0.4), Color = C3(110, 70, 50), Material = Enum.Material.Wood,
		CFrame = CF(spawnPart.Position + V3(4, 3, 0)),
	})
	local board = mkPart("WelcomeSignBoard", polish, {
		Size = V3(0.4, 0.4, 0.4), Transparency = 1, CanCollide = false,
		CFrame = CF(spawnPart.Position + V3(4, 6.5, 0)),
	})
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromScale(12, 4); bg.LightInfluence = 0; bg.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = C3(255, 240, 200); frame.BorderSizePixel = 0; frame.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4; stroke.Color = C3(110, 70, 50); stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
	label.Text = "PHISH\nCast. Reel. Inspect. Don't get phish'd."; label.Font = Enum.Font.Cartoon
	label.TextScaled = true; label.TextColor3 = C3(110, 70, 50); label.Parent = frame
end

-- Tide-pool sparkle particles.
local island = map:FindFirstChild("PhishIsland")
if island then
	for _, child in ipairs(island:GetChildren()) do
		if child.Name:sub(1, 8) == "TidePool" then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Lifetime = NumberRange.new(2, 4)
			emitter.Rate = 4
			emitter.Speed = NumberRange.new(0.5, 1)
			emitter.Color = ColorSequence.new(C3(180, 230, 255))
			emitter.Size = NumberSequence.new(0.3, 0.1)
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Acceleration = V3(0, 4, 0)
			emitter.Parent = child
		end
	end
end

-- Fireflies near the Lodge (small Neon balls + PointLights).
local fireflyAnchors = {
	V3(-22, 5, 4), V3(-18, 4, -3), V3(-26, 6, 0), V3(-14, 5, 5),
	V3(-22, 7, -6), V3(-30, 5, 2),
}
for i, pos in ipairs(fireflyAnchors) do
	local fly = mkPart("Firefly_" .. i, polish, {
		Size = V3(0.25, 0.25, 0.25), Color = C3(255, 230, 130),
		Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
		CFrame = CF(pos), CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = C3(255, 230, 130); light.Range = 6; light.Brightness = 1.5
	light.Parent = fly
end

-- Ambient SFX. Built-in rbxasset paths only — user-uploaded ids drift
-- between public/private/deleted, but rbxasset bundle ships with every
-- client. Empty assetId skips the Sound entirely.
local function ambient(parent, name, assetId, volume)
	if not assetId or assetId == "" then return end
	local s = Instance.new("Sound")
	s.Name = name; s.SoundId = assetId; s.Volume = volume or 0.4
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10; s.RollOffMaxDistance = 60
	s.Parent = parent
	pcall(function() s:Play() end)
end

local dock = map:FindFirstChild("PhishDock")
local castAnchor = dock and dock:FindFirstChild("CastAnchor")
if castAnchor then ambient(castAnchor, "WaterLapping", "rbxasset://sounds/impact_water.mp3", 0.35) end

local centerAmbient = mkPart("AmbientCenter", polish, {
	Size = V3(0.4, 0.4, 0.4), Transparency = 1, CanCollide = false, CFrame = CF(0, 6, 0),
})
-- No good built-in for ambient wind/birds. Skip rather than 404 every join.
ambient(centerAmbient, "WindBirds", "", 0)

print("[PHISH! POLISH] Done.")
return true
