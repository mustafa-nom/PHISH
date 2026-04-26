--!strict
-- Outcome juice: on a correct DecisionResult, spawn confetti particles in
-- screen space + briefly shake the camera. Stronger reaction for rare
-- species (anything except PlainCarp / HonestHerring) and the Phisherman.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

local function shakeCamera(intensity: number, durationSec: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local fade = math.max(0, 1 - elapsed / durationSec)
		local k = intensity * fade
		camera.CFrame = camera.CFrame * CFrame.Angles(
			(math.random() - 0.5) * k * 0.02,
			(math.random() - 0.5) * k * 0.02,
			(math.random() - 0.5) * k * 0.02
		)
		if elapsed >= durationSec then
			conn:Disconnect()
		end
	end)
end

local function makeConfettiPiece(parent: Instance, hue: Color3)
	local size = math.random(8, 16)
	local piece = Instance.new("Frame")
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.fromScale(0.5, 0.45)
	piece.Size = UDim2.fromOffset(size, size + math.random(2, 8))
	piece.BackgroundColor3 = hue
	piece.BorderSizePixel = 0
	piece.Rotation = math.random(0, 359)
	piece.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = piece

	local angle = math.random() * math.pi * 2
	local dist = math.random(140, 320)
	local fx = math.cos(angle) * dist
	local fy = math.sin(angle) * dist - math.random(80, 220)
	local landY = math.random(80, 180)
	local lifetime = 1.4 + math.random() * 0.4

	-- Burst outward + slightly up.
	TweenService:Create(piece,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, fx, 0.45, fy), Rotation = piece.Rotation + math.random(-180, 180) }
	):Play()

	-- Then fall + fade.
	task.delay(0.5, function()
		if not piece.Parent then return end
		local fallTween = TweenService:Create(piece,
			TweenInfo.new(lifetime - 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(0.5, fx + math.random(-40, 40), 0.45, fy + landY),
				BackgroundTransparency = 1,
				Rotation = piece.Rotation + math.random(-90, 90),
			}
		)
		fallTween:Play()
		fallTween.Completed:Connect(function()
			if piece.Parent then piece:Destroy() end
		end)
	end)
end

local function bigBurst(count: number)
	local container = Instance.new("Frame")
	container.Name = "PhishConfetti"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = screen

	local palette = {
		Color3.fromRGB(255, 220, 110),
		Color3.fromRGB(120, 220, 130),
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(255, 175, 90),
	}
	for _ = 1, count do
		makeConfettiPiece(container, palette[math.random(1, #palette)])
	end
	task.delay(2.5, function()
		if container.Parent then container:Destroy() end
	end)
end

local rareSpecies = {
	UrgencyEel = true,
	AuthorityAnglerfish = true,
	RewardTuna = true,
	CuriosityCatfish = true,
	FearBass = true,
	FamiliarityFlounder = true,
}

RemoteService.OnClientEvent("DecisionResult", function(payload)
	if type(payload) ~= "table" then return end
	if not payload.wasCorrect then
		shakeCamera(0.5, 0.18)
		return
	end
	-- Always a small celebration on correct.
	bigBurst(18)
	shakeCamera(0.4, 0.22)
	if payload.species and rareSpecies[payload.species] then
		-- Rare species: bigger burst + harder shake.
		task.delay(0.05, function() bigBurst(30) end)
		shakeCamera(1.2, 0.4)
	end
end)

RemoteService.OnClientEvent("PhishermanDefeated", function()
	bigBurst(60)
	shakeCamera(1.6, 0.6)
end)

RemoteService.OnClientEvent("SpeciesUnlocked", function()
	bigBurst(36)
end)
