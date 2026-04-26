--!strict
-- Reel mini-game UI. Player taps Space (or clicks) at least 3 times within
-- the duration to succeed. Server is authoritative on success threshold;
-- client just forwards inputs and shows a tap counter + timer.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local state = {
	frame = nil :: Frame?,
	encounterId = nil :: string?,
	deadline = nil :: number?,
	taps = 0,
	tapLabel = nil :: TextLabel?,
	timerLabel = nil :: TextLabel?,
}

local function destroyFrame()
	if state.frame then state.frame:Destroy() end
	state.frame = nil
	state.tapLabel = nil
	state.timerLabel = nil
end

local function buildFrame(duration: number)
	destroyFrame()
	local frame = UIStyle.MakePanel({
		Name = "ReelFrame",
		Size = UDim2.new(0, 360, 0, 160),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		Parent = screen,
	})
	state.frame = frame

	UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0, 8),
		Text = "REEL!",
		TextSize = UIStyle.TextSize.Title,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 44),
		Text = "Tap SPACE three times to land it.",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = frame,
	})
	state.tapLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 78),
		Text = "Taps: 0 / 3",
		TextSize = UIStyle.TextSize.Heading,
		Parent = frame,
	})
	state.timerLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 116),
		Text = ("%.1fs"):format(duration),
		TextSize = UIStyle.TextSize.Body,
		Parent = frame,
	})
end

local function tap()
	if not state.encounterId then return end
	state.taps += 1
	if state.tapLabel then
		state.tapLabel.Text = ("Taps: %d / 3"):format(state.taps)
	end
	RemoteService.FireServer("RequestReelInput", { encounterId = state.encounterId })
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not state.encounterId then return end
	if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
		tap()
	end
end)

RemoteService.OnClientEvent("ReelMinigameStarted", function(payload)
	if typeof(payload) ~= "table" then return end
	state.encounterId = payload.EncounterId
	state.taps = 0
	state.deadline = os.clock() + (payload.DurationSec or 4)
	buildFrame(payload.DurationSec or 4)
end)

RemoteService.OnClientEvent("ReelMinigameTick", function(payload)
	if typeof(payload) ~= "table" then return end
	if state.tapLabel and payload.Count then
		state.tapLabel.Text = ("Taps: %d / 3"):format(payload.Count)
	end
end)

RemoteService.OnClientEvent("ReelMinigameResolved", function()
	state.encounterId = nil
	state.deadline = nil
end)

RemoteService.OnClientEvent("CatchResolved", function()
	destroyFrame()
end)

RunService.RenderStepped:Connect(function()
	if state.deadline and state.timerLabel then
		local remaining = state.deadline - os.clock()
		state.timerLabel.Text = ("%.1fs"):format(math.max(0, remaining))
	end
end)
