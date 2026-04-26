--!strict
-- Sell shop UI. Press E near a part tagged PhishSellPrompt. Lists each fish
-- the player has caught with sell and quick-sell buttons.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local NumberFormatter = require(Modules:WaitForChild("NumberFormatter"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local activeFrame: Frame? = nil
local nearSell = false

local function close()
	if activeFrame then activeFrame:Destroy() end
	activeFrame = nil
end

local function buildList()
	close()
	local quote
	local ok, q = pcall(function()
		return RemoteService.InvokeServer("GetSellQuote")
	end)
	if ok then quote = q end
	if not quote then return end

	local frame = UIStyle.MakePanel({
		Name = "SellFrame",
		Size = UDim2.new(0, 520, 0, 420),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Parent = screen,
	})
	activeFrame = frame
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 8),
		Text = "Sell Fish",
		TextSize = UIStyle.TextSize.Title,
		Parent = frame,
	})
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -120)
	scroll.Position = UDim2.new(0, 8, 0, 44)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	if #quote.Entries == 0 then
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 32),
			Text = "No fish to sell. Catch some first.",
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextMuted,
			Parent = scroll,
		})
	else
		for i, entry in ipairs(quote.Entries) do
			local row = UIStyle.MakePanel({
				Size = UDim2.new(1, -8, 0, 56),
				BackgroundColor3 = UIStyle.Palette.Background,
				LayoutOrder = i,
				Parent = scroll,
			})
			UIStyle.MakeLabel({
				Size = UDim2.new(0.55, 0, 0, 24),
				Position = UDim2.new(0, 12, 0, 6),
				Text = ("%s × %d"):format(entry.DisplayName, entry.Count),
				TextSize = UIStyle.TextSize.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			UIStyle.MakeLabel({
				Size = UDim2.new(0.55, 0, 0, 22),
				Position = UDim2.new(0, 12, 0, 30),
				Text = ("%s • %d each"):format(entry.Rarity, entry.PerUnit),
				TextSize = UIStyle.TextSize.Caption,
				TextColor3 = UIStyle.Palette.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			local btn = UIStyle.MakeButton({
				Size = UDim2.new(0, 130, 0, 36),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Text = "Sell 1",
				BackgroundColor3 = UIStyle.Palette.Accent,
				TextSize = UIStyle.TextSize.Body,
				Parent = row,
			})
			btn.Activated:Connect(function()
				RemoteService.FireServer("RequestSellFish", { fishId = entry.FishId })
				task.wait(0.1)
				buildList()
			end)
		end
	end

	local quickBtn = UIStyle.MakeButton({
		Size = UDim2.new(0, 220, 0, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -44),
		Text = ("Sell All for %s"):format(NumberFormatter.Comma(quote.QuickSellTotal)),
		BackgroundColor3 = UIStyle.Palette.Safe,
		TextSize = UIStyle.TextSize.Body,
		Parent = frame,
	})
	quickBtn.Activated:Connect(function()
		RemoteService.FireServer("RequestSellAll", {})
		close()
	end)

	local closeBtn = UIStyle.MakeButton({
		Size = UDim2.new(0, 110, 0, 28),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Text = "Close",
		TextSize = UIStyle.TextSize.Caption,
		Parent = frame,
	})
	closeBtn.Activated:Connect(close)
end

local function inRange(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	for _, p in ipairs(CollectionService:GetTagged(Constants.TAGS.SellPrompt)) do
		if p:IsA("BasePart") and (p.Position - root.Position).Magnitude < 12 then
			return true
		end
	end
	return false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E and nearSell then
		if activeFrame then close() else buildList() end
	end
end)

task.spawn(function()
	while true do
		nearSell = inRange()
		task.wait(0.5)
	end
end)
