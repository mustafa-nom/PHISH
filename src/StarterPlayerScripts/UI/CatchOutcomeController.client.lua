--!strict
-- Renders the post-catch panel: fish name, lesson line, optional aquarium prompt.
-- Auto-fades after 4 seconds unless the aquarium choice is shown.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()
local activeFrame: Frame? = nil
local activeFishId: string? = nil

local function close()
	if activeFrame then activeFrame:Destroy() end
	activeFrame = nil
	activeFishId = nil
end

RemoteService.OnClientEvent("CatchResolved", function(payload)
	if typeof(payload) ~= "table" then return end
	close()
	activeFishId = payload.FishId

	local frame = UIStyle.MakePanel({
		Name = "CatchOutcomeFrame",
		Size = UDim2.new(0, 480, 0, 220),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		BackgroundColor3 = payload.WasCorrect and UIStyle.Palette.Safe or UIStyle.Palette.Risky,
		Parent = screen,
	})
	activeFrame = frame

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 8),
		Text = payload.DisplayName or "Fish",
		TextSize = UIStyle.TextSize.Title,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 44),
		Text = ("%s • %s"):format(tostring(payload.Category), tostring(payload.Rarity)),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 56),
		Position = UDim2.new(0, 8, 0, 70),
		Text = payload.LessonLine or "",
		TextSize = UIStyle.TextSize.Body,
		TextWrapped = true,
		Parent = frame,
	})
	if payload.Pearls and payload.Pearls > 0 then
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.new(0, 8, 0, 130),
			Text = ("+%d pearls   +%d XP"):format(payload.Pearls or 0, payload.Xp or 0),
			TextSize = UIStyle.TextSize.Body,
			Parent = frame,
		})
	end

	if payload.AquariumPromptable then
		local btn = UIStyle.MakeButton({
			Size = UDim2.new(0, 220, 0, 40),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Text = "Place in Aquarium",
			BackgroundColor3 = UIStyle.Palette.Highlight,
			Parent = frame,
		})
		btn.Activated:Connect(function()
			if activeFishId then
				RemoteService.FireServer("RequestPlaceFishInAquarium", { fishId = activeFishId })
			end
			close()
		end)
		task.delay(8, function()
			if activeFrame == frame then close() end
		end)
		return
	end

	if payload.Nudge then
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 22),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Text = payload.Nudge,
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = UIStyle.Palette.TextMuted,
			Parent = frame,
		})
	end

	task.delay(4, function()
		if activeFrame == frame then close() end
	end)
end)
