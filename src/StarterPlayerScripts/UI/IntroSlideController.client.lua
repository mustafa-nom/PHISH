--!strict
-- Cold-open framing slide. Shows once on session join. Dark backdrop, big
-- LARP-style headline, three side-by-side metaphor rows, single CTA button.
-- Direct response to judge feedback "state RIGHT AWAY the purpose of the
-- game". Auto-dismisses after AutoDismissSec.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local active: ScreenGui? = nil

local function close()
	if active then active:Destroy() end
	active = nil
end

local function show(payload)
	if active then close() end

	-- Use a dedicated full-screen gui so it sits above the regular HUD.
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhishIntroSlide"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = screen.Parent
	active = gui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(15, 22, 36)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	TweenService:Create(backdrop, TweenInfo.new(0.6), { BackgroundTransparency = 0.05 }):Play()

	local card = UIStyle.MakePanel({
		Size = UDim2.new(0, 640, 0, 460),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = UIStyle.Palette.Background,
		Parent = gui,
	})

	local lines = (typeof(payload) == "table" and payload.Lines) or {
		"You grew up safe.",
		"Someone watched out for you.",
		"Now you're the watchout.",
	}

	for i, line in ipairs(lines) do
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -32, 0, 36),
			Position = UDim2.new(0, 16, 0, 24 + (i - 1) * 38),
			Text = line,
			TextSize = i == #lines and UIStyle.TextSize.Title or UIStyle.TextSize.Heading,
			TextColor3 = UIStyle.Palette.TextPrimary,
			Parent = card,
		})
	end

	local frameLines = (typeof(payload) == "table" and payload.FrameLines) or {
		{ left = "Internet", right = "Ocean" },
		{ left = "Scams",    right = "Fish" },
		{ left = "You",      right = "Angler" },
	}
	local startY = 168
	for i, pair in ipairs(frameLines) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -64, 0, 30)
		row.Position = UDim2.new(0, 32, 0, startY + (i - 1) * 36)
		row.BackgroundTransparency = 1
		row.Parent = card
		UIStyle.MakeLabel({
			Size = UDim2.new(0.45, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Text = pair.left,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextMuted,
			Parent = row,
		})
		UIStyle.MakeLabel({
			Size = UDim2.new(0.1, 0, 1, 0),
			Position = UDim2.new(0.45, 0, 0, 0),
			Text = "→",
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.Accent,
			Parent = row,
		})
		UIStyle.MakeLabel({
			Size = UDim2.new(0.45, 0, 1, 0),
			Position = UDim2.new(0.55, 0, 0, 0),
			Text = pair.right,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextPrimary,
			Parent = row,
		})
	end

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -32, 0, 24),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -68),
		Text = "Every fish you reel is a real online-safety moment in disguise.",
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextWrapped = true,
		Parent = card,
	})

	local btn = UIStyle.MakeButton({
		Size = UDim2.new(0, 240, 0, 44),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Text = (typeof(payload) == "table" and payload.ButtonText) or "Cast a line",
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Accent,
		Parent = card,
	})
	btn.Activated:Connect(close)

	local autoSec = (typeof(payload) == "table" and payload.AutoDismissSec) or 8
	task.delay(autoSec, function()
		if active == gui then close() end
	end)
end

RemoteService.OnClientEvent("ShowIntroSlide", show)
