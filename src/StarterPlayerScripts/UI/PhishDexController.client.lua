--!strict
-- Fish Index screen. Toggle with the on-screen INDEX button or "P". Displays
-- species the player has found, with unseen entries kept as silhouettes.
-- Server-authoritative: fetches via GetPhishDex on each open.

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

local open: () -> ()

local function toggle()
	if screen:FindFirstChild("PhishDex") then
		clearOld()
	else
		open()
	end
end

open = function()
	clearOld()
	local entries = nil
	local ok = pcall(function() entries = RemoteService.InvokeServer("GetPhishDex") end)
	if not ok or type(entries) ~= "table" then return end

	local panel = UIStyle.MakePanel({
		Name = "PhishDex",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 540),
		BackgroundColor3 = UIStyle.Palette.Background,
	})
	panel.Parent = screen

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -96, 0, 42),
		Position = UDim2.fromOffset(16, 8),
		Text = "FISH INDEX",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	local foundCount = 0
	for _, e in ipairs(entries) do
		if e.found then foundCount += 1 end
	end
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -112, 0, 22),
		Position = UDim2.fromOffset(16, 48),
		Text = string.format("%d / %d fish found", foundCount, #entries),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
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
	list.Size = UDim2.new(1, -32, 1, -88)
	list.Position = UDim2.fromOffset(16, 76)
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
		local found = e.found == true
		local mastered = e.unlocked == true
		local row = UIStyle.MakePanel({
			Size = UDim2.new(1, 0, 0, found and 86 or 58),
			BackgroundColor3 = found and UIStyle.Palette.Panel or UIStyle.Palette.Background,
		})
		row.Parent = list

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -24, 0, 24),
			Position = UDim2.fromOffset(12, 4),
			Text = found and e.displayName or "Unknown fish",
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		local status = mastered and "Mastered" or (found and "Found" or "Not found")
		local sub = string.format("%s  |  %s  |  %d / %d",
			e.rarity or "Common",
			status,
			e.count or 0,
			e.catchesToUnlock or 3)
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -24, 0, 20),
			Position = UDim2.fromOffset(12, 30),
			Text = found and ((e.realPatternName or "") .. "  |  " .. sub) or sub,
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = UIStyle.Palette.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		if found then
			UIStyle.MakeLabel({
				Size = UDim2.new(1, -24, 0, 28),
				Position = UDim2.fromOffset(12, 52),
				Text = e.description or "",
				TextSize = UIStyle.TextSize.Caption,
				TextColor3 = UIStyle.Palette.TextPrimary,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}).Parent = row
		end
	end
end

local indexBtn = UIStyle.MakeButton({
	Name = "FishIndexButton",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(116, 38),
	Position = UDim2.new(1, -16, 0, 58),
	Text = "INDEX",
	TextSize = UIStyle.TextSize.Body,
	BackgroundColor3 = UIStyle.Palette.AskFirst,
	Parent = screen,
})
indexBtn.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggle()
	end
end)
