--!strict
-- Single source of UI styling. Inspired by Fisch-style Roblox UIs:
-- dark glassy panels, cream banner titles, gold-accent text, and dark
-- inset card slots with bright selection outlines.

local UIStyle = {}

UIStyle.Font = Enum.Font.GothamBold
UIStyle.FontDisplay = Enum.Font.FredokaOne
UIStyle.FontBold = Enum.Font.GothamBold

UIStyle.TextSize = {
	Title = 30,
	Heading = 22,
	Body = 16,
	Subtitle = 14,
	Caption = 12,
}

-- Dark cinematic palette. Background panels are deep, near-black with a
-- subtle warm undertone; cards are inset darker; banner titles are cream
-- to gold; selection / safe is bright spring green; risky is coral red.
UIStyle.Palette = {
	-- Backgrounds
	Background      = Color3.fromRGB(34, 28, 36),    -- outer/dim layer
	Panel           = Color3.fromRGB(42, 34, 42),    -- main panel
	PanelDeep       = Color3.fromRGB(26, 22, 28),    -- nested panels
	CardSlot        = Color3.fromRGB(28, 24, 30),    -- card / slot
	CardSlotHover   = Color3.fromRGB(38, 32, 40),    -- hovered slot

	-- Strokes
	PanelStroke     = Color3.fromRGB(18, 14, 20),    -- panel outer outline
	SlotStroke      = Color3.fromRGB(60, 50, 60),    -- slot outline
	BannerStroke    = Color3.fromRGB(95, 60, 30),

	-- Banner gradient endpoints (cream → orange)
	BannerTop       = Color3.fromRGB(255, 232, 178),
	BannerBottom    = Color3.fromRGB(232, 158, 60),

	-- Text
	TextPrimary     = Color3.fromRGB(245, 238, 224),
	TextMuted       = Color3.fromRGB(168, 158, 150),
	TextOnBanner    = Color3.fromRGB(70, 38, 14),
	TitleGold       = Color3.fromRGB(255, 200, 90),  -- "[Day 1]" style headers
	TitleGoldHero   = Color3.fromRGB(255, 178, 60),  -- featured slot title

	-- Status
	Accent          = Color3.fromRGB(255, 153, 84),
	Safe            = Color3.fromRGB(110, 220, 110), -- buy/owned outline + selection
	Risky           = Color3.fromRGB(220, 92, 92),
	AskFirst        = Color3.fromRGB(245, 200, 90),
	Highlight       = Color3.fromRGB(120, 196, 240),

	-- Rarity tints (used as top stripe / icon backdrop)
	Common          = Color3.fromRGB(160, 160, 170),
	Uncommon        = Color3.fromRGB(110, 200, 130),
	Rare            = Color3.fromRGB(110, 170, 240),
	Epic            = Color3.fromRGB(200, 130, 240),
	Legendary       = Color3.fromRGB(255, 198, 80),
}

UIStyle.Corner = UDim.new(0, 14)
UIStyle.SmallCorner = UDim.new(0, 8)
UIStyle.SlotCorner = UDim.new(0, 10)

-- Lazy helper: ensure a UICorner with the canonical radius on `instance`.
function UIStyle.ApplyCorner(instance: Instance, radius: UDim?)
	local existing = instance:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = radius or UIStyle.Corner
		return existing
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UIStyle.Corner
	corner.Parent = instance
	return corner
end

function UIStyle.ApplyStroke(instance: Instance, color: Color3?, thickness: number?): UIStroke
	local existing = instance:FindFirstChildOfClass("UIStroke")
	if existing then
		if color then existing.Color = color end
		if thickness then existing.Thickness = thickness end
		return existing
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UIStyle.Palette.PanelStroke
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

-- Apply a vertical gradient. Useful for panels and banners.
function UIStyle.ApplyGradient(instance: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local existing = instance:FindFirstChildOfClass("UIGradient")
	if existing then existing:Destroy() end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	g.Rotation = rotation or 90
	g.Parent = instance
	return g
end

-- Build a styled TextLabel with our defaults.
function UIStyle.MakeLabel(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = UIStyle.Font
	label.TextSize = UIStyle.TextSize.Body
	label.TextColor3 = UIStyle.Palette.TextPrimary
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.RichText = true
	for k, v in pairs(props) do
		(label :: any)[k] = v
	end
	return label
end

-- Build a styled TextButton.
function UIStyle.MakeButton(props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = UIStyle.Palette.Accent
	button.TextColor3 = UIStyle.Palette.TextPrimary
	button.Font = UIStyle.Font
	button.TextSize = UIStyle.TextSize.Heading
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	for k, v in pairs(props) do
		(button :: any)[k] = v
	end
	UIStyle.ApplyCorner(button, UIStyle.SmallCorner)
	return button
end

-- Dark glassy panel. Slight gradient + dark stroke for depth.
function UIStyle.MakePanel(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = UIStyle.Palette.Panel
	frame.BorderSizePixel = 0
	for k, v in pairs(props) do
		(frame :: any)[k] = v
	end
	UIStyle.ApplyCorner(frame)
	UIStyle.ApplyStroke(frame, UIStyle.Palette.PanelStroke, 2)
	UIStyle.ApplyGradient(frame,
		Color3.new(
			math.min(1, frame.BackgroundColor3.R + 0.04),
			math.min(1, frame.BackgroundColor3.G + 0.04),
			math.min(1, frame.BackgroundColor3.B + 0.04)
		),
		Color3.new(
			math.max(0, frame.BackgroundColor3.R - 0.04),
			math.max(0, frame.BackgroundColor3.G - 0.04),
			math.max(0, frame.BackgroundColor3.B - 0.04)
		),
		90
	)
	return frame
end

-- Cream banner title that sits at the top of a panel, like the reference's
-- "Daily Reward" header. `props` controls Size/Position/Parent + Text.
function UIStyle.BannerTitle(props: { [string]: any }): Frame
	local banner = Instance.new("Frame")
	banner.BackgroundColor3 = UIStyle.Palette.BannerBottom
	banner.BorderSizePixel = 0
	banner.Size = UDim2.fromOffset(props.Width or 320, props.Height or 56)
	banner.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0)
	banner.Position = props.Position or UDim2.new(0.5, 0, 0, -18)
	if props.Parent then banner.Parent = props.Parent end

	UIStyle.ApplyCorner(banner, UDim.new(0, 14))
	UIStyle.ApplyStroke(banner, UIStyle.Palette.BannerStroke, 3)
	UIStyle.ApplyGradient(banner, UIStyle.Palette.BannerTop, UIStyle.Palette.BannerBottom, 90)

	-- Inner highlight strip across the top half.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.new(0.5, 0, 0, 4)
	shine.Size = UDim2.new(1, -16, 0, 6)
	shine.BackgroundColor3 = Color3.fromRGB(255, 250, 230)
	shine.BackgroundTransparency = 0.45
	shine.BorderSizePixel = 0
	shine.Parent = banner
	UIStyle.ApplyCorner(shine, UDim.new(0, 4))

	local label = UIStyle.MakeLabel({
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "TITLE",
		Font = UIStyle.FontDisplay,
		TextSize = props.TextSize or UIStyle.TextSize.Title,
		TextColor3 = UIStyle.Palette.TextOnBanner,
		Parent = banner,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 246, 220)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = label

	return banner
end

-- Dark inset card slot, used for grid items. Returns the slot frame; caller
-- fills it with icon/label content.
function UIStyle.CardSlot(props: { [string]: any }): Frame
	local slot = Instance.new("Frame")
	slot.BackgroundColor3 = UIStyle.Palette.CardSlot
	slot.BorderSizePixel = 0
	for k, v in pairs(props) do
		(slot :: any)[k] = v
	end
	UIStyle.ApplyCorner(slot, UIStyle.SlotCorner)
	UIStyle.ApplyStroke(slot, UIStyle.Palette.SlotStroke, 1)
	UIStyle.ApplyGradient(slot,
		Color3.fromRGB(46, 38, 46),
		Color3.fromRGB(20, 16, 22),
		90
	)
	return slot
end

-- Hero / featured slot. Taller than CardSlot, with a gold inner accent.
function UIStyle.HeroSlot(props: { [string]: any }): Frame
	local slot = Instance.new("Frame")
	slot.BackgroundColor3 = UIStyle.Palette.CardSlot
	slot.BorderSizePixel = 0
	for k, v in pairs(props) do
		(slot :: any)[k] = v
	end
	UIStyle.ApplyCorner(slot, UDim.new(0, 12))
	UIStyle.ApplyStroke(slot, UIStyle.Palette.Legendary, 2)
	UIStyle.ApplyGradient(slot,
		Color3.fromRGB(60, 40, 30),
		Color3.fromRGB(20, 14, 18),
		90
	)
	return slot
end

-- Small pill chip — used in HUD for coins / level / accuracy.
function UIStyle.Chip(props: { [string]: any }): Frame
	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = UIStyle.Palette.Panel
	chip.BorderSizePixel = 0
	for k, v in pairs(props) do
		(chip :: any)[k] = v
	end
	UIStyle.ApplyCorner(chip, UDim.new(1, 0))
	UIStyle.ApplyStroke(chip, UIStyle.Palette.PanelStroke, 1)
	return chip
end

return UIStyle
