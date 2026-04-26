--!strict
-- Field Guide overlay. When FieldGuideEntryUnlocked fires with OpenOnClient
-- true, opens a modal with the entry text. The player can press B (book) to
-- toggle a journal browser later — for MVP it just shows the most recent
-- unlocked entry.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local entries: { [string]: { DisplayName: string, Category: string, Rarity: string, Entry: string, CorrectAction: string } } = {}
local activeFrame: Frame? = nil

local function close()
	if activeFrame then activeFrame:Destroy() end
	activeFrame = nil
end

local function open(entry)
	close()
	local frame = UIStyle.MakePanel({
		Name = "FieldGuideFrame",
		Size = UDim2.new(0, 520, 0, 300),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Parent = screen,
	})
	activeFrame = frame

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 8),
		Text = "Field Guide",
		TextSize = UIStyle.TextSize.Heading,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 40),
		Text = entry.DisplayName,
		TextSize = UIStyle.TextSize.Title,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 76),
		Text = ("%s • %s"):format(entry.Category, entry.Rarity),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 130),
		Position = UDim2.new(0, 8, 0, 102),
		Text = entry.Entry,
		TextSize = UIStyle.TextSize.Body,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -32),
		Text = ("Right move: %s"):format(entry.CorrectAction),
		TextSize = UIStyle.TextSize.Body,
		Parent = frame,
	})
	local btn = UIStyle.MakeButton({
		Size = UDim2.new(0, 110, 0, 28),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Text = "Close (B)",
		TextSize = UIStyle.TextSize.Caption,
		Parent = frame,
	})
	btn.Activated:Connect(close)
end

RemoteService.OnClientEvent("FieldGuideEntryUnlocked", function(payload)
	if typeof(payload) ~= "table" then return end
	entries[payload.FishId] = {
		DisplayName = payload.DisplayName,
		Category = payload.Category,
		Rarity = payload.Rarity,
		Entry = payload.Entry,
		CorrectAction = payload.CorrectAction,
	}
	if payload.OpenOnClient then
		open(entries[payload.FishId])
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		if activeFrame then close() return end
		-- Open the most recent entry; if no entries, show a placeholder.
		local lastEntry
		for _, e in pairs(entries) do lastEntry = e end
		if lastEntry then
			open(lastEntry)
		else
			local frame = UIStyle.MakePanel({
				Size = UDim2.new(0, 360, 0, 120),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Parent = screen,
			})
			activeFrame = frame
			UIStyle.MakeLabel({
				Size = UDim2.new(1, -16, 1, -16),
				Position = UDim2.new(0, 8, 0, 8),
				Text = "Field Guide is empty. Verify a bite to fill it.",
				TextSize = UIStyle.TextSize.Body,
				TextWrapped = true,
				Parent = frame,
			})
			task.delay(3, function()
				if activeFrame == frame then close() end
			end)
		end
	end
end)
