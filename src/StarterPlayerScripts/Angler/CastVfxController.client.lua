--!strict
-- The cast/reel visual pipeline. Owns the bobber Part, the fishing-line Beam,
-- splash particles, idle bob, bite jiggle, and the bobber's return-to-rod
-- animation when a catch resolves. Plays SFX at every beat and shakes the
-- camera on landing + bite. Server only sends discrete events; this controller
-- handles all the in-between motion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local player = Players.LocalPlayer

-- ===== SOUND IDS =====
-- Built-in rbxasset paths only. Previous user-uploaded ids ("Asset type
-- does not match requested type") had been deleted or set private; built-in
-- paths ship with every Roblox client and never go away.
local SOUND_IDS = {
	CastWhoosh = "rbxasset://sounds/swordlunge.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Bite = "rbxasset://sounds/electronicpingshort.wav",
	ReelClick = "rbxasset://sounds/clickfast.wav",
	GotIt = "rbxasset://sounds/snap.mp3",
	GotAway = "rbxasset://sounds/uuhhh.mp3",
}

local function makeSound(id: string, volume: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Parent = script
	return s
end

local sounds = {
	cast = makeSound(SOUND_IDS.CastWhoosh, 0.45),
	splash = makeSound(SOUND_IDS.Splash, 0.55),
	bite = makeSound(SOUND_IDS.Bite, 0.6),
	reel = makeSound(SOUND_IDS.ReelClick, 0.35),
	gotIt = makeSound(SOUND_IDS.GotIt, 0.55),
	gotAway = makeSound(SOUND_IDS.GotAway, 0.45),
}
local function play(s: Sound) pcall(function() s:Play() end) end

-- ===== BOBBER + LINE STATE =====
local state: { bobber: Part?, beam: Beam?, idleConn: RBXScriptConnection?, startedAt: number, aim: Vector3? } = {
	bobber = nil, beam = nil, idleConn = nil, startedAt = 0, aim = nil,
}

local function findRodTip(): BasePart?
	local char = player.Character
	if not char then return nil end
	local rod = char:FindFirstChild("PhishRod")
	if rod then
		return (rod:FindFirstChild("Tip") or rod:FindFirstChild("Handle")) :: BasePart?
	end
	-- Fallback: hand or root
	return (char:FindFirstChild("RightHand") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local function cleanup()
	if state.idleConn then state.idleConn:Disconnect() end
	if state.beam then state.beam:Destroy() end
	if state.bobber then state.bobber:Destroy() end
	state.bobber = nil; state.beam = nil; state.idleConn = nil; state.aim = nil
end

local function makeBobber(pos: Vector3): Part
	local b = Instance.new("Part")
	b.Name = "PhishBobber"
	b.Size = Vector3.new(0.7, 0.9, 0.7)
	b.Shape = Enum.PartType.Ball
	b.Material = Enum.Material.SmoothPlastic
	b.Color = Color3.fromRGB(220, 60, 60)
	b.Anchored = true
	b.CanCollide = false
	b.CFrame = CFrame.new(pos)
	b.Parent = workspace
	-- Top half white for that classic bobber look.
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(0.72, 0.45, 0.72)
	cap.Shape = Enum.PartType.Ball
	cap.Material = Enum.Material.SmoothPlastic
	cap.Color = Color3.fromRGB(255, 255, 255)
	cap.Anchored = true
	cap.CanCollide = false
	cap.CFrame = b.CFrame * CFrame.new(0, 0.22, 0)
	cap.Parent = b
	return b
end

local function makeAttachment(parent: BasePart, name: string, offset: Vector3?): Attachment
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then return existing end
	local a = Instance.new("Attachment")
	a.Name = name
	if offset then a.Position = offset end
	a.Parent = parent
	return a
end

local function makeBeam(rodTip: BasePart, bobber: BasePart): Beam
	local a0 = makeAttachment(rodTip, "PhishLineAtt", Vector3.new(0, rodTip.Size.Y / 2, 0))
	local a1 = makeAttachment(bobber, "PhishLineAtt")
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0; beam.Attachment1 = a1
	beam.Width0 = 0.06; beam.Width1 = 0.06
	beam.Transparency = NumberSequence.new(0.15)
	beam.Color = ColorSequence.new(Color3.fromRGB(245, 245, 230))
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.CurveSize0 = -1.5
	beam.CurveSize1 = 0
	beam.Parent = workspace
	return beam
end

local function shakeCamera(duration: number, amplitude: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= duration then
			hum.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		local fade = 1 - (t / duration)
		local sx = (math.random() - 0.5) * amplitude * fade
		local sy = (math.random() - 0.5) * amplitude * fade
		hum.CameraOffset = Vector3.new(sx, sy, 0)
	end)
end

local function spawnSplash(pos: Vector3)
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "PhishSplashFx"
	emitterPart.Size = Vector3.new(0.1, 0.1, 0.1)
	emitterPart.Anchored = true; emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.CFrame = CFrame.new(pos)
	emitterPart.Parent = workspace

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.Rate = 0
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(50, 50)
	pe.Acceleration = Vector3.new(0, -30, 0)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Parent = emitterPart
	pe:Emit(36)

	-- Ring shock: a flat disc that scales out and fades.
	local ring = Instance.new("Part")
	ring.Name = "SplashRing"
	ring.Size = Vector3.new(1, 0.05, 1)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(220, 240, 255)
	ring.Transparency = 0.3
	ring.Anchored = true; ring.CanCollide = false
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1, 0.05, 8),
		Transparency = 1,
	}):Play()

	Debris:AddItem(emitterPart, 1.2)
	Debris:AddItem(ring, 0.7)
end

-- ===== ARC TWEEN =====
local function arcBobber(start: Vector3, finish: Vector3, duration: number, onArrive: () -> ())
	local bobber = state.bobber
	if not bobber then return end
	local elapsed = 0
	local apex = math.max(start.Y, finish.Y) + 12
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / duration, 1)
		-- Quadratic Bezier: B(t) = (1-t)^2*P0 + 2*(1-t)*t*P1 + t^2*P2
		local one = 1 - t
		local mid = Vector3.new((start.X + finish.X) / 2, apex, (start.Z + finish.Z) / 2)
		local p = (one * one) * start + (2 * one * t) * mid + (t * t) * finish
		bobber.CFrame = CFrame.new(p)
		if t >= 1 then
			conn:Disconnect()
			onArrive()
		end
	end)
end

local function startIdleBob()
	if state.idleConn then state.idleConn:Disconnect() end
	local bobber = state.bobber
	if not bobber then return end
	local baseY = bobber.Position.Y
	local startTime = os.clock()
	state.idleConn = RunService.RenderStepped:Connect(function()
		if not state.bobber then return end
		local t = os.clock() - startTime
		local y = baseY + math.sin(t * 2.4) * 0.18
		state.bobber.CFrame = CFrame.new(state.bobber.Position.X, y, state.bobber.Position.Z)
	end)
end

local function biteJiggle()
	local bobber = state.bobber
	if not bobber then return end
	-- Snap down 1.2 studs then back, three times, fast.
	if state.idleConn then state.idleConn:Disconnect(); state.idleConn = nil end
	local origin = bobber.Position
	task.spawn(function()
		for _ = 1, 3 do
			TweenService:Create(bobber, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
				CFrame = CFrame.new(origin - Vector3.new(0, 1.2, 0)),
			}):Play()
			task.wait(0.10)
			TweenService:Create(bobber, TweenInfo.new(0.10, Enum.EasingStyle.Quad), {
				CFrame = CFrame.new(origin),
			}):Play()
			task.wait(0.10)
		end
		startIdleBob()
	end)
end

local function reelReturn(onDone: () -> ())
	local bobber = state.bobber
	if not bobber then return onDone() end
	if state.idleConn then state.idleConn:Disconnect(); state.idleConn = nil end
	local rodTip = findRodTip()
	local target = rodTip and rodTip.Position or (bobber.Position + Vector3.new(0, 6, 0))
	local tween = TweenService:Create(bobber, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		CFrame = CFrame.new(target),
	})
	tween.Completed:Connect(onDone)
	tween:Play()
end

local function sinkAndFade(onDone: () -> ())
	local bobber = state.bobber
	if not bobber then return onDone() end
	if state.idleConn then state.idleConn:Disconnect(); state.idleConn = nil end
	local target = bobber.Position - Vector3.new(0, 3, 0)
	TweenService:Create(bobber, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(target),
		Transparency = 1,
	}):Play()
	task.delay(0.6, onDone)
end

-- ===== EVENT HANDLERS =====
RemoteService.OnClientEvent("CastStarted", function(payload)
	cleanup()
	if type(payload) ~= "table" then return end
	local aim = payload.aim
	if typeof(aim) ~= "Vector3" then return end
	local rodTip = findRodTip()
	if not rodTip then return end

	state.aim = aim
	state.startedAt = os.clock()
	state.bobber = makeBobber(rodTip.Position)
	state.beam = makeBeam(rodTip, state.bobber :: BasePart)

	play(sounds.cast)
	arcBobber(rodTip.Position, aim, 0.55, function()
		play(sounds.splash)
		spawnSplash(aim)
		shakeCamera(0.18, 0.18)
		startIdleBob()
	end)
end)

RemoteService.OnClientEvent("BiteOccurred", function()
	if not state.bobber then return end
	play(sounds.bite)
	shakeCamera(0.22, 0.4)
	biteJiggle()
end)

RemoteService.OnClientEvent("ReelProgress", function()
	play(sounds.reel)
end)

RemoteService.OnClientEvent("ShowInspectionCard", function()
	play(sounds.gotIt)
	reelReturn(cleanup)
end)

RemoteService.OnClientEvent("ReelFailed", function()
	play(sounds.gotAway)
	sinkAndFade(cleanup)
end)

-- Clean up on respawn.
player.CharacterAdded:Connect(cleanup)
