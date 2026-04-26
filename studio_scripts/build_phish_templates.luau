-- build_phish_templates.luau
-- Builds ReplicatedStorage.PhishFishTemplates (8 = 6 phish species + 2 legit),
-- ServerStorage.PhishBobbers (4),
-- and .PhishLures (1). Aligned to docs/PHISH_PRD.md and docs/PHISH_PHISH_DEX.md.
-- Idempotent: re-running wipes the three folders and rebuilds.
-- Run via: Studio Command Bar (View > Command Bar > paste > Enter), or MCP execute_luau.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local C3 = Color3.fromRGB
local V3 = Vector3.new
local CF = CFrame.new

local function mkPart(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent; return p
end
local function tag(i, t) CollectionService:AddTag(i, t) end
local function attr(i, k, v) i:SetAttribute(k, v) end
local function weldTo(primary, others)
	for _, c in ipairs(others) do
		if c:IsA("BasePart") and c ~= primary then
			local w = Instance.new("WeldConstraint"); w.Part0 = primary; w.Part1 = c; w.Parent = primary
		end
	end
end
local function purge(parent, name)
	local existing = parent:FindFirstChild(name); if existing then existing:Destroy() end
end

-- 6 phish species + 2 legit. Visual cues per docs/PHISH_PHISH_DEX.md "Visual cue" lines.
local SPECIES = {
	{ id = "UrgencyEel", name = "Urgency Eel", body = C3(220, 60, 50), accent = C3(255, 230, 0), scale = 1.3, elongated = true, extra = function(model, body, s)
		local bolt = Instance.new("WedgePart"); bolt.Anchored = true
		bolt.Size = V3(0.6 * s, 1.2 * s, 0.3 * s); bolt.Color = C3(255, 230, 0)
		bolt.Material = Enum.Material.Neon
		bolt.CFrame = body.CFrame * CF(0, 1.0 * s, 0); bolt.Parent = model
	end },
	{ id = "AuthorityAnglerfish", name = "Authority Anglerfish", body = C3(20, 30, 80), accent = C3(255, 220, 100), scale = 1.1, extra = function(model, body, s)
		mkPart("Badge", model, {
			Size = V3(0.8 * s, 0.8 * s, 0.15 * s), Color = C3(255, 220, 100),
			Material = Enum.Material.Neon, Shape = Enum.PartType.Cylinder,
			CFrame = body.CFrame * CF(0.5 * s, 0.2 * s, 0.7 * s),
		})
	end },
	{ id = "RewardTuna", name = "Reward Tuna", body = C3(255, 200, 40), accent = C3(255, 255, 200), scale = 1.2, extra = function(model, body, s)
		for i = 1, 4 do
			mkPart("Confetti_" .. i, model, {
				Size = V3(0.2 * s, 0.2 * s, 0.2 * s),
				Color = C3(math.random(120, 255), math.random(120, 255), math.random(120, 255)),
				Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
				CFrame = body.CFrame * CF((i - 2.5) * 0.5 * s, 0.6 * s, 0.5 * s),
			})
		end
	end },
	{ id = "CuriosityCatfish", name = "Curiosity Catfish", body = C3(120, 120, 130), accent = C3(220, 220, 220), scale = 1.0, extra = function(model, body, s)
		for i, side in ipairs({ -1, 1 }) do
			mkPart("Eye_" .. i, model, {
				Size = V3(0.6 * s, 0.6 * s, 0.6 * s), Color = C3(255, 255, 255),
				Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball,
				CFrame = body.CFrame * CF(0.6 * s, 0.3 * s, side * 0.6 * s),
			})
		end
		for i = 1, 2 do
			mkPart("Whisker_" .. i, model, {
				Size = V3(0.8 * s, 0.05 * s, 0.05 * s), Color = C3(60, 60, 70),
				CFrame = body.CFrame * CF(0.8 * s, -0.4 * s, (i - 1.5) * 0.4 * s),
			})
		end
	end },
	{ id = "FearBass", name = "Fear Bass", body = C3(40, 30, 60), accent = C3(220, 30, 40), scale = 1.2, extra = function(model, body, s)
		for i, side in ipairs({ -1, 1 }) do
			local eye = mkPart("EyeRed_" .. i, model, {
				Size = V3(0.4 * s, 0.4 * s, 0.4 * s), Color = C3(255, 60, 60),
				Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
				CFrame = body.CFrame * CF(0.6 * s, 0.3 * s, side * 0.5 * s),
			})
			local pl = Instance.new("PointLight"); pl.Color = C3(255, 60, 60); pl.Range = 4; pl.Brightness = 2; pl.Parent = eye
		end
		for i = 1, 3 do
			local spike = Instance.new("WedgePart"); spike.Anchored = true
			spike.Size = V3(0.4 * s, 0.6 * s, 0.4 * s); spike.Color = C3(40, 30, 60)
			spike.Material = Enum.Material.SmoothPlastic
			spike.CFrame = body.CFrame * CF((i - 2) * 0.5 * s, 0.7 * s, 0); spike.Parent = model
		end
	end },
	{ id = "FamiliarityFlounder", name = "Familiarity Flounder", body = C3(220, 200, 200), accent = C3(180, 160, 200), scale = 1.0, flat = true, extra = function(model, body, s)
		for i = 1, 3 do
			mkPart("FakeStripe_" .. i, model, {
				Size = V3(0.2 * s, 1.4 * s, 0.05 * s),
				Color = C3(180 - i * 10, 160 - i * 10, 200),
				Material = Enum.Material.SmoothPlastic,
				CFrame = body.CFrame * CF((i - 2) * 0.7 * s, 0, 0.6 * s),
			})
		end
	end },
	-- LEGIT fish: clean and normal so KEEP isn't always wrong.
	{ id = "PlainCarp", name = "Plain Carp", legit = true, body = C3(120, 180, 200), accent = C3(180, 220, 240), scale = 1.0 },
	{ id = "HonestHerring", name = "Honest Herring", legit = true, body = C3(200, 210, 220), accent = C3(240, 240, 250), scale = 1.0 },
}

local function buildFishModel(parent, spec)
	local model = Instance.new("Model")
	model.Name = spec.name; model.Parent = parent
	local s = spec.scale
	local sx, sy, sz
	if spec.elongated then sx, sy, sz = 4 * s, 1 * s, 1 * s
	elseif spec.flat then sx, sy, sz = 3 * s, 0.5 * s, 2.5 * s
	else sx, sy, sz = 3 * s, 1.5 * s, 1.5 * s end

	local body = mkPart("Body", model, {
		Size = V3(sx, sy, sz), Color = spec.body,
		Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball,
	})
	local tail = Instance.new("WedgePart"); tail.Anchored = true
	tail.Size = V3(1.2 * s, sy, 1 * s); tail.Color = spec.accent
	tail.Material = Enum.Material.SmoothPlastic
	tail.CFrame = body.CFrame * CF(-(sx / 2 + 0.3 * s), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	tail.Parent = model
	if spec.extra then spec.extra(model, body, s) end

	weldTo(body, model:GetChildren())
	model.PrimaryPart = body
	tag(model, "PhishFishTemplate")
	attr(model, "FishId", spec.id)
	attr(model, "IsLegit", spec.legit == true)
end

local function buildBobber(parent, name, color, isNeon, withLight)
	local model = Instance.new("Model"); model.Name = name; model.Parent = parent
	local body = mkPart("Body", model, {
		Size = V3(0.8, 1.2, 0.8), Color = color,
		Material = isNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
	})
	if withLight then
		local light = Instance.new("PointLight"); light.Color = color
		light.Range = 6; light.Brightness = 1.5; light.Parent = body
	end
	model.PrimaryPart = body
end

purge(ReplicatedStorage, "PhishFishTemplates")
purge(ServerStorage, "PhishFishTemplates")
purge(ServerStorage, "PhishBobbers")
purge(ServerStorage, "PhishLures")

local fishFolder = Instance.new("Folder")
fishFolder.Name = "PhishFishTemplates"; fishFolder.Parent = ReplicatedStorage
for _, spec in ipairs(SPECIES) do buildFishModel(fishFolder, spec) end

local bobbers = Instance.new("Folder")
bobbers.Name = "PhishBobbers"; bobbers.Parent = ServerStorage
buildBobber(bobbers, "Bobber_Phish", C3(220, 60, 50), true, false)
buildBobber(bobbers, "Bobber_Legit", C3(120, 200, 180), false, true)
buildBobber(bobbers, "Bobber_Boss", C3(160, 30, 200), true, true)
buildBobber(bobbers, "Bobber_Default", C3(255, 255, 255), false, false)

local lures = Instance.new("Folder")
lures.Name = "PhishLures"; lures.Parent = ServerStorage
local lure = Instance.new("Model"); lure.Name = "DefaultLure"; lure.Parent = lures
local lureBody = mkPart("Body", lure, {
	Size = V3(0.4, 0.8, 0.4), Color = C3(180, 180, 180),
	Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder,
})
lure.PrimaryPart = lureBody

print(string.format("[PHISH! TEMPLATES] Done. Species=%d (%d phish, %d legit). Bobbers=4 Lures=1",
	#SPECIES, 6, 2))
return true
