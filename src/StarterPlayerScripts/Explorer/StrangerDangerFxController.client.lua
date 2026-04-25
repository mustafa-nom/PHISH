--!strict
-- Visual juice for Stranger Danger:
-- - Particle bursts on Approach result (gold sparkle for clue, red puff for
--   risky, blue puff for avoid)
-- - Camera shake on RiskyConsequence
-- - Puppy reveal celebration with a screen flash + chime
--
-- All client-side and cosmetic — no server trust required.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))

local localPlayer = Players.LocalPlayer

local function findNpcModel(npcId: string): Model?
	for _, slot in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.PlayArenaSlot)) do
		local playArea = slot:FindFirstChild("PlayArea")
		if playArea then
			for _, level in ipairs(playArea:GetChildren()) do
				local m = level:FindFirstChild(npcId)
				if m and m:IsA("Model") then return m end
			end
		end
	end
	return nil
end

local function spawnBurst(host: BasePart, color: Color3, count: number, lifetime: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = host
	emitter:Emit(count)
	task.delay(lifetime + 0.5, function() emitter:Destroy() end)
end

local function shakeCamera(amount: number, duration: number)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local elapsed = 0
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			conn:Disconnect()
			return
		end
		local fade = 1 - (elapsed / duration)
		local jitter = CFrame.new(
			(math.random() - 0.5) * amount * fade,
			(math.random() - 0.5) * amount * fade,
			(math.random() - 0.5) * amount * fade
		)
		camera.CFrame = camera.CFrame * jitter
	end)
end

local function playSfx(name: string)
	local s = SoundService:FindFirstChild(name)
	if s and s:IsA("Sound") then
		local clone = s:Clone()
		clone.Parent = SoundService
		clone:Play()
		task.delay(3, function() clone:Destroy() end)
	end
end

local function celebratePuppy()
	-- screen flash via ColorCorrection
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.8
	cc.Saturation = 0.4
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Saturation = 0,
	}):Play()
	task.delay(2, function() cc:Destroy() end)
	playSfx("RoundComplete")

	-- big text overlay
	local screen = Instance.new("ScreenGui")
	screen.Name = "BB_PuppyFound"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 10
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.4, 0)
	label.Size = UDim2.new(0, 600, 0, 120)
	label.BackgroundTransparency = 1
	label.Text = "PUPPY FOUND!"
	label.Font = Enum.Font.Cartoon
	label.TextSize = 96
	label.TextColor3 = Color3.fromRGB(255, 232, 196)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(132, 44, 40)
	label.TextScaled = true
	label.Parent = screen
	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.new(0.5, 0, 0.5, 0)
	sub.Size = UDim2.new(0, 500, 0, 50)
	sub.BackgroundTransparency = 1
	sub.Text = "you talked, you trusted, you won"
	sub.Font = Enum.Font.Cartoon
	sub.TextSize = 32
	sub.TextColor3 = Color3.fromRGB(255, 232, 196)
	sub.TextStrokeTransparency = 0.4
	sub.TextStrokeColor3 = Color3.fromRGB(60, 40, 20)
	sub.Parent = screen
	-- fade out
	task.delay(2.5, function()
		for _, l in ipairs({ label, sub }) do
			TweenService:Create(l, TweenInfo.new(1.0), { TextTransparency = 1 }):Play()
		end
		task.delay(1.5, function() screen:Destroy() end)
	end)
end

RemoteService.OnClientEvent("NpcActionResolved", function(payload)
	local model = findNpcModel(payload.NpcId or "")
	if not model then return end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end

	if payload.Result == "ClueGranted" then
		spawnBurst(root, Color3.fromRGB(255, 220, 120), 36, 1.2)
		playSfx("ClueCollected")
	elseif payload.Result == "RiskyConsequence" then
		spawnBurst(root, Color3.fromRGB(220, 92, 92), 32, 1.0)
		playSfx("WrongSort")
		shakeCamera(0.8, 0.6)
	elseif payload.Result == "AvoidedSafely" then
		spawnBurst(root, Color3.fromRGB(140, 200, 240), 18, 0.8)
		playSfx("CorrectSort")
	elseif payload.Result == "MissedClue" then
		spawnBurst(root, Color3.fromRGB(180, 180, 180), 12, 0.8)
	end
end)

RemoteService.OnClientEvent("PuppyRevealed", function(_payload)
	celebratePuppy()
end)
