--!strict
-- Stub Phish-Dex screen. Toggle with the "P" key. Displays unlocked species
-- (collapses locked entries to silhouettes). Server-authoritative — fetches
-- via GetPhishDex on each open, cheap because the dex is small.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

local function clearOld()
	local old = screen:FindFirstChild("PhishDex")
	if old then old:Destroy() end
end

local function open()
	clearOld()
	local entries = nil
	local ok = pcall(function() entries = RemoteService.InvokeServer("GetPhishDex") end)
	if not ok or type(entries) ~= "table" then return end

	local panel = UIStyle.MakePanel({
		Name = "PhishDex",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 520),
		BackgroundColor3 = UIStyle.Palette.Background,
	})
	panel.Parent = screen

	UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 8),
		Text = "PHISH-DEX",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Title,
	}).Parent = panel

	local closeBtn = UIStyle.MakeButton({
		Size = UDim2.fromOffset(40, 32),
		Position = UDim2.new(1, -52, 0, 12),
		Text = "X",
		BackgroundColor3 = UIStyle.Palette.Risky,
	})
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(clearOld)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -80)
	list.Position = UDim2.fromOffset(16, 64)
	list.BackgroundTransparency = 1
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	for _, e in ipairs(entries) do
		local row = UIStyle.MakePanel({
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = e.unlocked and UIStyle.Palette.Panel or UIStyle.Palette.Background,
		})
		row.Parent = list
		local title = UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(12, 4),
			Text = e.unlocked and e.displayName or "???",
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		title.Parent = row
		local sub = string.format("%s  ·  %d / %d", e.rarity or "Common", e.count or 0, e.catchesToUnlock or 3)
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 20),
			Position = UDim2.fromOffset(12, 30),
			Text = e.unlocked and ((e.realPatternName or "") .. "  ·  " .. sub) or sub,
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = UIStyle.Palette.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.P then
		if screen:FindFirstChild("PhishDex") then clearOld() else open() end
	end
end)
