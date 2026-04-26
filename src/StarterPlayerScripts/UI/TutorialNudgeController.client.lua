--!strict
-- Top-center tutorial nudge. Slides in, holds, slides out. Used for the
-- first-cast tip and any future "press X to do Y" hints.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

RemoteService.OnClientEvent("TutorialNudge", function(payload)
	if typeof(payload) ~= "table" then return end
	local frame = UIStyle.MakePanel({
		Name = "TutorialNudge",
		Size = UDim2.new(0, 460, 0, 80),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -100),
		BackgroundColor3 = UIStyle.Palette.Highlight,
		Parent = screen,
	})
	if typeof(payload.Title) == "string" and payload.Title ~= "" then
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.new(0, 8, 0, 6),
			Text = payload.Title,
			TextSize = UIStyle.TextSize.Heading,
			TextColor3 = Color3.fromRGB(40, 28, 16),
			Parent = frame,
		})
	end
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.new(0, 8, 0, 32),
		Text = payload.Text or "",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		TextWrapped = true,
		Parent = frame,
	})
	TweenService:Create(frame,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 96) }):Play()
	local dur = payload.DurationSec or 6
	task.delay(dur, function()
		if not frame.Parent then return end
		TweenService:Create(frame,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -100) }):Play()
		task.wait(0.45)
		if frame.Parent then frame:Destroy() end
	end)
end)
