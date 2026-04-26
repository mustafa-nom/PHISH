--!strict
-- Journal browser. Press J to toggle. Lists every fish in the registry with
-- a checkmark for unlocked entries. Click a fish to read its entry.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local FishRegistry = require(Modules:WaitForChild("FishRegistry"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local journalUnlocked: { [string]: boolean } = {}
local activeFrame: Frame? = nil

local function close()
	if activeFrame then activeFrame:Destroy() end
	activeFrame = nil
end

local function buildList()
	close()
	local frame = UIStyle.MakePanel({
		Name = "JournalFrame",
		Size = UDim2.new(0, 480, 0, 420),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Parent = screen,
	})
	activeFrame = frame
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 8),
		Text = "Journal",
		TextSize = UIStyle.TextSize.Title,
		Parent = frame,
	})
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -56)
	scroll.Position = UDim2.new(0, 8, 0, 44)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll
	for _, fish in ipairs(FishRegistry.All()) do
		local unlocked = journalUnlocked[fish.id] == true
		local row = UIStyle.MakePanel({
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = unlocked and UIStyle.Palette.Panel or UIStyle.Palette.Background,
			Parent = scroll,
		})
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.new(0, 8, 0, 4),
			Text = unlocked and fish.displayName or "??? ???",
			TextSize = UIStyle.TextSize.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.new(0, 8, 0, 32),
			Text = unlocked
				and (fish.fieldGuideEntry)
				or "Locked. Verify or correctly resolve a bite to unlock.",
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = UIStyle.Palette.TextMuted,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
	local closeBtn = UIStyle.MakeButton({
		Size = UDim2.new(0, 110, 0, 28),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Text = "Close (J)",
		TextSize = UIStyle.TextSize.Caption,
		Parent = frame,
	})
	closeBtn.Activated:Connect(close)
end

RemoteService.OnClientEvent("InventoryUpdated", function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.JournalUnlocked then
		journalUnlocked = payload.JournalUnlocked
	end
end)

RemoteService.OnClientEvent("JournalUpdated", function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.FishId then journalUnlocked[payload.FishId] = true end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.J then
		if activeFrame then close() else buildList() end
	end
end)

task.spawn(function()
	local ok, snap = pcall(function()
		return RemoteService.InvokeServer("GetSnapshot")
	end)
	if ok and snap and snap.JournalUnlocked then
		journalUnlocked = snap.JournalUnlocked
	end
end)
