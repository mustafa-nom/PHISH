--!strict
-- Fish Index screen. Toggle with the on-screen INDEX button or "P". Displays
-- species the player has found, with unseen entries kept as silhouettes.
-- Server-authoritative: fetches via GetPhishDex on each open.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local FishArt = require(Modules:WaitForChild("FishArt"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

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

-- Preview slot: wider/taller than the original viewport box so the wide
-- 2D fish art reads as a proper sticker instead of a thin sliver. Tile
-- height stays 168, so labels below shift up a touch (see grid loop).
local PREVIEW_ANCHOR = Vector2.new(0.5, 0.5)
local PREVIEW_POS = UDim2.new(0.5, 0, 0, 48)
local PREVIEW_SIZE = UDim2.fromOffset(134, 72)
local PREVIEW_ZINDEX = 5

-- Index uses 2D art only: uploaded fish stickers from FishArt.lua, with the
-- same art silhouette-tinted for NOT FOUND. No ViewportFrame / 3D models
-- (they read as "rotating" in the small tile and fight the card art look).
local function buildFishPreview(speciesId: string, found: boolean, parent: Instance): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "FishPreview"
	img.AnchorPoint = PREVIEW_ANCHOR
	img.Position = PREVIEW_POS
	img.Size = PREVIEW_SIZE
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = PREVIEW_ZINDEX
	img.BorderSizePixel = 0

	local art = FishArt.Get(speciesId)
	if art and art ~= "" then
		img.BackgroundTransparency = 1
		img.Image = art
		if not found then
			-- Same 2D asset as placeholder: dark silhouette so the shape
			-- still reads against the slot.
			img.ImageColor3 = Color3.fromRGB(75, 70, 95)
		else
			img.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end
		img.ImageTransparency = 0
	else
		-- No rbxassetid yet: static 2D card (never 3D).
		img.Image = ""
		img.BackgroundTransparency = 0.12
		img.BackgroundColor3 = UIStyle.Palette.CardSlot
		UIStyle.ApplyCorner(img, UDim.new(0, 8))
		UIStyle.ApplyStroke(img, UIStyle.Palette.SlotStroke, 2)
		UIStyle.MakeLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Text = "??",
			Font = UIStyle.FontDisplay,
			TextSize = 22,
			TextColor3 = UIStyle.Palette.TextMuted,
			ZIndex = PREVIEW_ZINDEX + 1,
			Parent = img,
		})
	end
	img.Parent = parent
	return img
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
	UIStyle.ApplyScale(panel, 0.7)

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

		-- 2D fish art (or static "??" slot if no rbxassetid in FishArt yet).
		buildFishPreview(tostring(e.id or ""), found, tile)

		-- Labels sit just below the 134x72 preview (bottom edge ~y=84).
		-- Spacing chosen so all three labels fit cleanly inside the 168px tile.
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -12, 0, 20),
			Position = UDim2.fromOffset(6, 94),
			Text = found and (e.displayName or "?") or "???",
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = tile,
		})

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -12, 0, 14),
			Position = UDim2.fromOffset(6, 118),
			Text = string.upper(e.rarity or "Common"),
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = rar,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -12, 0, 14),
			Position = UDim2.fromOffset(6, 136),
			Text = mastered
				and string.format("%d / %d · MASTERED", e.count or 0, e.catchesToUnlock or 3)
				or (found
					and string.format("%d / %d", e.count or 0, e.catchesToUnlock or 3)
					or "NOT FOUND"),
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = mastered and UIStyle.Palette.Safe or UIStyle.Palette.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})

		if mastered then
			UIStyle.SetSelected(tile, true)
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
UIStyle.ApplyGradient(indexBtn, {
	top = Color3.fromRGB(255, 220, 120),
	bottom = Color3.fromRGB(220, 160, 60),
	rotation = 90,
})
UIStyle.BindHover(indexBtn, 1.06)
indexBtn.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggle()
	end
end)
