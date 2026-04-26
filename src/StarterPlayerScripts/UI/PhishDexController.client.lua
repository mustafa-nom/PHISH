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
local fishTemplates = ReplicatedStorage:WaitForChild("PhishFishTemplates")

local function clearOld()
	local old = screen:FindFirstChild("PhishDex")
	if old then old:Destroy() end
end

local function rarityColor(rarity: string?): Color3
	if rarity == "Rare" then return UIStyle.Palette.Rare end
	if rarity == "Uncommon" then return UIStyle.Palette.Uncommon end
	if rarity == "Epic" then return UIStyle.Palette.Epic end
	if rarity == "Legendary" then return UIStyle.Palette.Legendary end
	return UIStyle.Palette.Common
end

local function buildFishPreview(speciesId: string, found: boolean, parent: Instance): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "FishPreview"
	vf.AnchorPoint = Vector2.new(0.5, 0)
	vf.Position = UDim2.new(0.5, 0, 0, 14)
	vf.Size = UDim2.fromOffset(110, 64)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(150, 140, 130)
	vf.LightColor = Color3.fromRGB(255, 240, 210)
	vf.LightDirection = Vector3.new(-0.4, -1, -0.25)
	vf.Parent = parent

	local template = fishTemplates:FindFirstChild(speciesId)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.Color = found and part.Color or Color3.fromRGB(50, 45, 55)
				part.Transparency = found and part.Transparency or 0.25
			elseif not found and part:IsA("PointLight") then
				part.Enabled = false
			end
		end
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-20), 0))
		clone.Parent = vf
	end

	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.CFrame = CFrame.new(Vector3.new(0, 0.4, 8), Vector3.new(0, 0.1, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
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
		Size = UDim2.fromOffset(720, 540),
		BackgroundColor3 = UIStyle.Palette.Panel,
	})
	panel.Parent = screen

	-- Banner title
	UIStyle.BannerTitle({
		Width = 320,
		Height = 56,
		Position = UDim2.new(0.5, 0, 0, -28),
		Text = "FISH INDEX",
		TextSize = 26,
		Parent = panel,
	})

	local foundCount = 0
	for _, e in ipairs(entries) do
		if e.found then foundCount += 1 end
	end
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -32, 0, 22),
		Position = UDim2.fromOffset(16, 44),
		Text = string.format("%d / %d species found", foundCount, #entries),
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TitleGold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	local closeBtn = UIStyle.MakeButton({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -12, 0, 12),
		Text = "X",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Risky,
		TextColor3 = Color3.fromRGB(255, 245, 240),
	})
	closeBtn.Parent = panel
	UIStyle.ApplyCorner(closeBtn, UDim.new(1, 0))
	UIStyle.ApplyStroke(closeBtn, Color3.fromRGB(140, 50, 50), 2)
	closeBtn.MouseButton1Click:Connect(clearOld)

	local gridFrame = Instance.new("ScrollingFrame")
	gridFrame.Name = "TileGrid"
	gridFrame.Size = UDim2.new(1, -32, 1, -88)
	gridFrame.Position = UDim2.fromOffset(16, 76)
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.CanvasSize = UDim2.fromOffset(0, 0)
	gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridFrame.ScrollBarThickness = 6
	gridFrame.ScrollBarImageColor3 = UIStyle.Palette.PanelStroke
	gridFrame.Parent = panel

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingBottom = UDim.new(0, 8)
	gridPadding.Parent = gridFrame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 168)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	for _, e in ipairs(entries) do
		local found = e.found == true
		local mastered = e.unlocked == true
		local rar = rarityColor(e.rarity)

		local tile = UIStyle.CardSlot({
			Name = tostring(e.id or "FishTile"),
			Size = UDim2.fromOffset(150, 168),
		})
		tile.Parent = gridFrame

		-- Top accent stripe colored by rarity.
		local stripe = Instance.new("Frame")
		stripe.Name = "RarityStripe"
		stripe.Size = UDim2.new(1, -8, 0, 4)
		stripe.Position = UDim2.fromOffset(4, 4)
		stripe.BackgroundColor3 = rar
		stripe.BorderSizePixel = 0
		stripe.BackgroundTransparency = found and 0 or 0.6
		stripe.Parent = tile
		UIStyle.ApplyCorner(stripe, UDim.new(0, 2))

		buildFishPreview(tostring(e.id or ""), found, tile)

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 88),
			Text = found and (e.displayName or "?") or "???",
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = tile,
		})

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 16),
			Position = UDim2.fromOffset(8, 112),
			Text = e.rarity or "Common",
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = rar,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 16),
			Position = UDim2.fromOffset(8, 130),
			Text = string.format("%d / %d", e.count or 0, e.catchesToUnlock or 3),
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = mastered and UIStyle.Palette.Safe or UIStyle.Palette.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 14),
			Position = UDim2.fromOffset(8, 148),
			Text = mastered and "MASTERED" or (found and "FOUND" or "—"),
			Font = UIStyle.FontBold,
			TextSize = 10,
			TextColor3 = mastered and UIStyle.Palette.Safe or UIStyle.Palette.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})

		if mastered then
			local stroke = tile:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = UIStyle.Palette.Safe
				stroke.Thickness = 2
			end
		end
	end
end

local indexBtn = UIStyle.MakeButton({
	Name = "FishIndexButton",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(116, 38),
	Position = UDim2.new(1, -16, 0, 110),
	Text = "INDEX",
	Font = UIStyle.FontBold,
	TextSize = UIStyle.TextSize.Body,
	BackgroundColor3 = UIStyle.Palette.AskFirst,
	TextColor3 = Color3.fromRGB(60, 40, 10),
	Parent = screen,
})
UIStyle.ApplyStroke(indexBtn, Color3.fromRGB(120, 80, 20), 2)
indexBtn.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggle()
	end
end)
