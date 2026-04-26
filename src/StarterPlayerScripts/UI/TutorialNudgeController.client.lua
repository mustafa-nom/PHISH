--!strict
-- One-shot tutorial banner. Slides in from the top, holds for `durationSec`,
-- slides out. Used for the first-card nudge and any future "press X to do Y"
-- hints. Safe to spam — each call replaces the previous nudge.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

local function clear()
	local old = screen:FindFirstChild("PhishTutorialNudge")
	if old then old:Destroy() end
end

RemoteService.OnClientEvent("TutorialNudge", function(payload)
	if type(payload) ~= "table" then return end
	clear()
	local frame = UIStyle.MakePanel({
		Name = "PhishTutorialNudge",
		Size = UDim2.new(0, 460, 0, 84),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -100),
		BackgroundColor3 = UIStyle.Palette.Highlight,
		Parent = screen,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 6),
		Text = payload.title or "Tip",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 34),
		Text = payload.text or "",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		TextWrapped = true,
		Parent = frame,
	})
	TweenService:Create(frame,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 96) }):Play()
	local dur = payload.durationSec or 6
	task.delay(dur, function()
		if not frame.Parent then return end
		TweenService:Create(frame,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -100) }):Play()
		task.wait(0.4)
		if frame.Parent then frame:Destroy() end
	end)
end)
