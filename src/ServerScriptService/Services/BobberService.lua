--!strict
-- Diegetic bobber lure. Spawns a glowing Part on the water in front of the
-- caster, replicates a server-authoritative position to the client, and
-- emits BobberSpawned / BobberDip / BobberDespawned for the client effects
-- controller to pick up.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local BobberService = {}

type BobberRecord = {
	part: Part,
	basePosition: Vector3,
	startedAt: number,
	dipUntil: number?,
	color: Color3,
	lucky: boolean,
	ripple: ParticleEmitter?,
}

-- Visual presets per ripple style (matched to fish.bobberCue.ripple in
-- FishRegistry). Different particle shapes/colors per category sell the
-- bite cue in the world.
local RIPPLE_PRESETS: { [string]: { color: Color3, rate: number, lifetime: NumberRange, size: NumberSequence, speed: NumberRange } } = {
	GlitterSplash = {
		color = Color3.fromRGB(255, 220, 100),
		rate = 28,
		lifetime = NumberRange.new(0.4, 0.7),
		size = NumberSequence.new(0.5, 0),
		speed = NumberRange.new(4, 8),
	},
	ConfettiSplash = {
		color = Color3.fromRGB(240, 130, 240),
		rate = 22,
		lifetime = NumberRange.new(0.5, 0.9),
		size = NumberSequence.new(0.6, 0.1),
		speed = NumberRange.new(3, 7),
	},
	UnderlineRipple = {
		color = Color3.fromRGB(80, 150, 240),
		rate = 16,
		lifetime = NumberRange.new(0.6, 1.0),
		size = NumberSequence.new(0.8, 0),
		speed = NumberRange.new(2, 5),
	},
	WobbleRipple = {
		color = Color3.fromRGB(190, 210, 255),
		rate = 14,
		lifetime = NumberRange.new(0.7, 1.1),
		size = NumberSequence.new(0.7, 0.2),
		speed = NumberRange.new(2, 4),
	},
	PageFlutter = {
		color = Color3.fromRGB(230, 230, 230),
		rate = 18,
		lifetime = NumberRange.new(0.5, 0.9),
		size = NumberSequence.new(0.5, 0),
		speed = NumberRange.new(3, 6),
	},
	PixelGlitch = {
		color = Color3.fromRGB(180, 255, 220),
		rate = 26,
		lifetime = NumberRange.new(0.3, 0.55),
		size = NumberSequence.new(0.3, 0),
		speed = NumberRange.new(5, 9),
	},
	FakeBadge = {
		color = Color3.fromRGB(120, 160, 230),
		rate = 12,
		lifetime = NumberRange.new(0.7, 1.2),
		size = NumberSequence.new(0.7, 0.1),
		speed = NumberRange.new(2, 4),
	},
	LifebuoyHook = {
		color = Color3.fromRGB(150, 200, 240),
		rate = 14,
		lifetime = NumberRange.new(0.7, 1.0),
		size = NumberSequence.new(0.7, 0.2),
		speed = NumberRange.new(2, 5),
	},
	CrownGlint = {
		color = Color3.fromRGB(255, 220, 110),
		rate = 22,
		lifetime = NumberRange.new(0.4, 0.7),
		size = NumberSequence.new(0.6, 0),
		speed = NumberRange.new(4, 8),
	},
	SoftGlow = {
		color = Color3.fromRGB(255, 200, 220),
		rate = 12,
		lifetime = NumberRange.new(0.9, 1.4),
		size = NumberSequence.new(0.8, 0.3),
		speed = NumberRange.new(1, 3),
	},
	WarmGlow = {
		color = Color3.fromRGB(255, 230, 140),
		rate = 14,
		lifetime = NumberRange.new(0.9, 1.4),
		size = NumberSequence.new(0.8, 0.3),
		speed = NumberRange.new(1, 3),
	},
	RainbowShimmer = {
		color = Color3.fromRGB(180, 240, 255),
		rate = 36,
		lifetime = NumberRange.new(0.6, 1.2),
		size = NumberSequence.new(0.6, 0),
		speed = NumberRange.new(3, 7),
	},
}

local bobbers: { [Player]: BobberRecord } = {}

local function makePart(color: Color3, lucky: boolean): Part
	local part = Instance.new("Part")
	part.Name = "PhishBobber"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Size = Vector3.new(0.7, 0.7, 0.7)
	part.Shape = Enum.PartType.Ball
	part.Color = color
	part.Transparency = 0.05

	local light = Instance.new("PointLight")
	light.Brightness = lucky and 3.5 or 2
	light.Range = lucky and 14 or 10
	light.Color = color
	light.Parent = part

	if lucky then
		local sparkle = Instance.new("Sparkles")
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 130))
		sparkle.SparkleColor = Color3.fromRGB(255, 235, 130)
		sparkle.Parent = part
	end
	return part
end

local function lookForwardAt(player: Player): Vector3?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local cf = root.CFrame
	return cf.Position + cf.LookVector * Constants.BOBBER.ForwardOffset + Vector3.new(0, Constants.BOBBER.UpOffset, 0)
end

function BobberService.SpawnFor(player: Player, color: Color3?, lucky: boolean?)
	BobberService.Despawn(player)
	local pos = lookForwardAt(player)
	if not pos then return end
	local resolved = color or Color3.fromRGB(255, 200, 120)
	local part = makePart(resolved, lucky == true)
	part.Position = pos
	part.Parent = workspace
	bobbers[player] = {
		part = part,
		basePosition = pos,
		startedAt = os.clock(),
		dipUntil = nil,
		color = resolved,
		lucky = lucky == true,
		ripple = nil,
	}
	RemoteService.FireClient(player, "BobberSpawned", {
		Color = resolved,
		Lucky = lucky == true,
		Position = pos,
	})
end

function BobberService.SetCue(player: Player, color: Color3, ripple: string?)
	local record = bobbers[player]
	if not record then return end
	record.color = color
	record.part.Color = color
	local light = record.part:FindFirstChildOfClass("PointLight")
	if light then light.Color = color end
	record.dipUntil = os.clock() + Constants.BOBBER.BiteDipReturnTime

	-- Spawn (or refresh) a ParticleEmitter on the bobber matching the cue.
	if record.ripple and record.ripple.Parent then record.ripple:Destroy() end
	local preset = ripple and RIPPLE_PRESETS[ripple] or nil
	if preset then
		local p = Instance.new("ParticleEmitter")
		p.Color = ColorSequence.new(preset.color)
		p.Rate = preset.rate
		p.Lifetime = preset.lifetime
		p.Size = preset.size
		p.Speed = preset.speed
		p.Rotation = NumberRange.new(0, 360)
		p.RotSpeed = NumberRange.new(-180, 180)
		p.LightEmission = 0.5
		p.LightInfluence = 0
		p.SpreadAngle = Vector2.new(40, 40)
		p.VelocityInheritance = 0
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Parent = record.part
		record.ripple = p
		-- Burst on the dip.
		p:Emit(20)
	end

	RemoteService.FireClient(player, "BobberDip", {
		Color = color,
		Ripple = ripple,
	})
end

function BobberService.Despawn(player: Player)
	local record = bobbers[player]
	if not record then return end
	if record.part and record.part.Parent then record.part:Destroy() end
	bobbers[player] = nil
	RemoteService.FireClient(player, "BobberDespawned", {})
end

local function step()
	local now = os.clock()
	for _, rec in pairs(bobbers) do
		if rec.part and rec.part.Parent then
			local elapsed = now - rec.startedAt
			local bob = math.sin((elapsed / Constants.BOBBER.IdleBobPeriod) * math.pi * 2) * Constants.BOBBER.IdleBobAmplitude
			local dipOffset = 0
			if rec.dipUntil and now < rec.dipUntil then
				local t = 1 - ((rec.dipUntil - now) / Constants.BOBBER.BiteDipReturnTime)
				dipOffset = -math.sin(t * math.pi) * Constants.BOBBER.BiteDipDepth
			end
			rec.part.Position = rec.basePosition + Vector3.new(0, bob + dipOffset, 0)
		end
	end
end

function BobberService.Init()
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		BobberService.Despawn(player)
	end)
end

return BobberService
