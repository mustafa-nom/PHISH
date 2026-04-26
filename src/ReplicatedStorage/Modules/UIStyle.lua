--!strict
-- Single source of UI styling. Modeled on Fisch-style Roblox UIs:
-- semi-transparent near-black panels, rectangular cream banner titles
-- that overhang the top edge, flat dark card slots (items sit directly
-- on them — no colored backdrops behind every icon), bright lime
-- selection strokes. Featured/hero slots get a radial glow.

local UIStyle = {}

UIStyle.Font = Enum.Font.GothamBold
UIStyle.FontDisplay = Enum.Font.FredokaOne
UIStyle.FontBold = Enum.Font.GothamBold

UIStyle.TextSize = {
	Title = 32,
	Heading = 22,
	Body = 16,
	Subtitle = 14,
	Caption = 12,
}

UIStyle.Palette = {
	-- Backgrounds
	Background      = Color3.fromRGB(18, 14, 20),
	Panel           = Color3.fromRGB(24, 18, 26),
	PanelDeep       = Color3.fromRGB(14, 10, 16),
	CardSlot        = Color3.fromRGB(22, 16, 24),
	CardSlotHover   = Color3.fromRGB(34, 26, 36),

	-- Strokes
	PanelStroke     = Color3.fromRGB(8, 4, 10),
	PanelInnerRim   = Color3.fromRGB(58, 46, 64),
	SlotStroke      = Color3.fromRGB(8, 4, 10),
	SlotInnerRim    = Color3.fromRGB(54, 42, 58),
	BannerStroke    = Color3.fromRGB(80, 40, 14),

	-- Banner gradient
	BannerTop       = Color3.fromRGB(255, 232, 178),
	BannerMid       = Color3.fromRGB(248, 184, 86),
	BannerBottom    = Color3.fromRGB(212, 130, 50),

	-- Text
	TextPrimary     = Color3.fromRGB(248, 240, 226),
	TextMuted       = Color3.fromRGB(165, 155, 148),
	TextOnBanner    = Color3.fromRGB(70, 36, 12),
	TitleGold       = Color3.fromRGB(255, 198, 80),
	TitleGoldHero   = Color3.fromRGB(255, 178, 60),

	-- Status
	Accent          = Color3.fromRGB(255, 153, 84),
	Safe            = Color3.fromRGB(120, 240, 110),
	Risky           = Color3.fromRGB(220, 92, 92),
	AskFirst        = Color3.fromRGB(245, 200, 90),
	Highlight       = Color3.fromRGB(120, 196, 240),

	-- Rarity tints
	Common          = Color3.fromRGB(160, 160, 170),
	Uncommon        = Color3.fromRGB(110, 220, 140),
	Rare            = Color3.fromRGB(110, 170, 240),
	Epic            = Color3.fromRGB(200, 130, 240),
	Legendary       = Color3.fromRGB(255, 198, 80),
}

UIStyle.Corner = UDim.new(0, 10)
UIStyle.SmallCorner = UDim.new(0, 6)
UIStyle.SlotCorner = UDim.new(0, 8)

function UIStyle.ApplyCorner(instance: Instance, radius: UDim?): UICorner
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
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

type GradientOpts = {
	top: Color3?, bottom: Color3?, mid: Color3?,
	color: ColorSequence?,
	transparency: NumberSequence?,
	transparencyTop: number?, transparencyBottom: number?,
	rotation: number?,
}
function UIStyle.ApplyGradient(instance: Instance, opts: GradientOpts): UIGradient
	local existing = instance:FindFirstChildOfClass("UIGradient")
	if existing then existing:Destroy() end
	local g = Instance.new("UIGradient")
	if opts.color then
		g.Color = opts.color
	elseif opts.mid and opts.top and opts.bottom then
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, opts.top),
			ColorSequenceKeypoint.new(0.5, opts.mid),
			ColorSequenceKeypoint.new(1, opts.bottom),
		})
	elseif opts.top and opts.bottom then
		g.Color = ColorSequence.new(opts.top, opts.bottom)
	end
	if opts.transparency then
		g.Transparency = opts.transparency
	elseif opts.transparencyTop or opts.transparencyBottom then
		g.Transparency = NumberSequence.new(
			opts.transparencyTop or 0,
			opts.transparencyBottom or 0
		)
	end
	g.Rotation = opts.rotation or 90
	g.Parent = instance
	return g
end

-- Subtle inner highlight rim — placed *inside* a panel/card to fake the
-- second layer of a 2-stroke bevel without needing a real second stroke.
function UIStyle.AddInnerRim(parent: GuiObject, color: Color3?, transparency: number?, cornerRadius: UDim?): Frame
	local rim = Instance.new("Frame")
	rim.Name = "InnerRim"
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.new(1, -4, 1, -4)
	rim.BackgroundTransparency = 1
	rim.BorderSizePixel = 0
	rim.ZIndex = (parent.ZIndex or 1) + 1
	rim.Parent = parent
	UIStyle.ApplyCorner(rim, cornerRadius or (UIStyle.Corner - UDim.new(0, 2)))
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UIStyle.Palette.PanelInnerRim
	stroke.Thickness = 1
	stroke.Transparency = transparency or 0.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = rim
	return rim
end

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

-- Semi-transparent dark glass panel. Flat fill (very subtle gradient) so
-- the scene reads through as background, not as foreground noise. Hard
-- near-black outer stroke. Subtle inner rim for layered bevel.
function UIStyle.MakePanel(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = UIStyle.Palette.Panel
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	for k, v in pairs(props) do
		(frame :: any)[k] = v
	end
	UIStyle.ApplyCorner(frame, UIStyle.Corner)
	UIStyle.ApplyStroke(frame, UIStyle.Palette.PanelStroke, 3)
	UIStyle.AddInnerRim(frame, UIStyle.Palette.PanelInnerRim, 0.7)
	return frame
end

-- Rectangular cream banner title. Sits overhanging the top edge of a
-- panel with ~50% inside, ~50% above. Cream→orange vertical gradient,
-- dark brown stroke, italic-feeling display text in dark brown.
function UIStyle.BannerTitle(props: { [string]: any }): Frame
	local height = props.Height or 64
	local width = props.Width or 360
	local banner = Instance.new("Frame")
	banner.Name = "BannerTitle"
	banner.BackgroundColor3 = UIStyle.Palette.BannerMid
	banner.BorderSizePixel = 0
	banner.Size = UDim2.fromOffset(width, height)
	banner.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0)
	banner.Position = props.Position or UDim2.new(0.5, 0, 0, -math.floor(height * 0.55))
	banner.ZIndex = (props.ZIndex or 5)
	if props.Parent then banner.Parent = props.Parent end

	UIStyle.ApplyCorner(banner, UDim.new(0, 14))
	UIStyle.ApplyStroke(banner, UIStyle.Palette.BannerStroke, 3)
	UIStyle.ApplyGradient(banner, {
		top = UIStyle.Palette.BannerTop,
		mid = UIStyle.Palette.BannerMid,
		bottom = UIStyle.Palette.BannerBottom,
		rotation = 90,
	})

	-- Inner subtle 1px highlight along the top edge.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.new(0.5, 0, 0, 4)
	shine.Size = UDim2.new(1, -22, 0, 3)
	shine.BackgroundColor3 = Color3.fromRGB(255, 252, 232)
	shine.BackgroundTransparency = 0.3
	shine.BorderSizePixel = 0
	shine.ZIndex = banner.ZIndex + 1
	shine.Parent = banner
	UIStyle.ApplyCorner(shine, UDim.new(0, 2))

	local label = UIStyle.MakeLabel({
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "TITLE",
		Font = UIStyle.FontDisplay,
		TextSize = props.TextSize or UIStyle.TextSize.Title,
		TextColor3 = UIStyle.Palette.TextOnBanner,
		ZIndex = banner.ZIndex + 2,
		Parent = banner,
	})
	-- Slight cream stroke on the text for the embossed feel.
	local txtStroke = Instance.new("UIStroke")
	txtStroke.Color = Color3.fromRGB(255, 245, 215)
	txtStroke.Thickness = 1.2
	txtStroke.Transparency = 0.4
	txtStroke.Parent = label

	return banner
end

-- Flat dark card slot. Items sit directly on this — NO colored backdrop
-- circle behind every icon (the reference doesn't use those). Subtle
-- gradient (top edge ~6% darker, simulating inset shadow), 2px black
-- outer stroke, faint inner rim.
function UIStyle.CardSlot(props: { [string]: any }): Frame
	local slot = Instance.new("Frame")
	slot.BackgroundColor3 = UIStyle.Palette.CardSlot
	slot.BackgroundTransparency = 0.05
	slot.BorderSizePixel = 0
	for k, v in pairs(props) do
		(slot :: any)[k] = v
	end
	UIStyle.ApplyCorner(slot, UIStyle.SlotCorner)
	UIStyle.ApplyStroke(slot, UIStyle.Palette.SlotStroke, 2)
	-- Very subtle inset shadow at top edge.
	UIStyle.ApplyGradient(slot, {
		top = Color3.fromRGB(14, 10, 18),
		mid = Color3.fromRGB(28, 22, 32),
		bottom = Color3.fromRGB(22, 16, 26),
		rotation = 90,
	})
	UIStyle.AddInnerRim(slot, UIStyle.Palette.SlotInnerRim, 0.78,
		UIStyle.SlotCorner - UDim.new(0, 2))
	return slot
end

-- Hero / featured slot. Same dark slot but with a radial-feel colored
-- backdrop (the colored glow behind the centerpiece icon, like the
-- Cosmic Relic's purple aura in the reference). This is the ONE place
-- where the colored circle backdrop is appropriate.
function UIStyle.HeroSlot(props: { [string]: any }): Frame
	local slot = Instance.new("Frame")
	slot.BackgroundColor3 = UIStyle.Palette.CardSlot
	slot.BackgroundTransparency = 0.05
	slot.BorderSizePixel = 0
	for k, v in pairs(props) do
		(slot :: any)[k] = v
	end
	UIStyle.ApplyCorner(slot, UIStyle.SlotCorner)
	UIStyle.ApplyStroke(slot, UIStyle.Palette.SlotStroke, 2)
	UIStyle.ApplyGradient(slot, {
		top = Color3.fromRGB(14, 10, 18),
		mid = Color3.fromRGB(30, 22, 32),
		bottom = Color3.fromRGB(20, 14, 22),
		rotation = 90,
	})
	UIStyle.AddInnerRim(slot, UIStyle.Palette.SlotInnerRim, 0.7,
		UIStyle.SlotCorner - UDim.new(0, 2))
	return slot
end

-- Radial-style colored glow used inside a HeroSlot to back the
-- centerpiece icon (like the magenta swirl behind the Cosmic Relic).
function UIStyle.HeroGlow(props: { [string]: any }): Frame
	local size = props.Size or UDim2.fromOffset(180, 180)
	local accent = props.Color or Color3.fromRGB(220, 80, 200)

	local halo = Instance.new("Frame")
	halo.Name = "HeroGlow"
	halo.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	halo.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	halo.Size = size
	halo.BackgroundColor3 = accent
	halo.BackgroundTransparency = 0.45
	halo.BorderSizePixel = 0
	halo.ZIndex = props.ZIndex or 3
	if props.Parent then halo.Parent = props.Parent end
	UIStyle.ApplyCorner(halo, UDim.new(1, 0))
	UIStyle.ApplyGradient(halo, {
		top = Color3.new(
			math.min(1, accent.R * 1.35),
			math.min(1, accent.G * 1.35),
			math.min(1, accent.B * 1.35)
		),
		bottom = Color3.new(accent.R * 0.4, accent.G * 0.4, accent.B * 0.4),
		transparencyTop = 0.3,
		transparencyBottom = 0.85,
		rotation = 90,
	})
	return halo
end

-- Selection state: bright lime green stroke replaces the slot's normal
-- dark stroke. Plain, no glow / pulse — matches the reference exactly.
function UIStyle.SetSelected(slot: GuiObject, selected: boolean)
	local stroke = slot:FindFirstChildOfClass("UIStroke")
	if not stroke then return end
	if selected then
		stroke.Color = UIStyle.Palette.Safe
		stroke.Thickness = 3
		stroke.Transparency = 0
	else
		stroke.Color = UIStyle.Palette.SlotStroke
		stroke.Thickness = 2
		stroke.Transparency = 0
	end
end

-- Apply a UIScale to a GuiObject. Scales the object + descendants
-- uniformly without touching individual offsets. Used on main modal
-- panels to downscale the whole UI without rewriting layout.
function UIStyle.ApplyScale(target: GuiObject, scale: number): UIScale
	local existing = target:FindFirstChildOfClass("UIScale")
	if existing then
		existing.Scale = scale
		return existing
	end
	local s = Instance.new("UIScale")
	s.Scale = scale
	s.Parent = target
	return s
end

-- Hover binding: subtle scale up on enter. Restraint over flair.
function UIStyle.BindHover(button: GuiButton, scale: number?)
	local TweenService = game:GetService("TweenService")
	local baseSize = button.Size
	local sx = scale or 1.03
	local hoverSize = UDim2.new(
		baseSize.X.Scale * sx, math.floor(baseSize.X.Offset * sx),
		baseSize.Y.Scale * sx, math.floor(baseSize.Y.Offset * sx)
	)
	local tInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, tInfo, { Size = hoverSize }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, tInfo, { Size = baseSize }):Play()
	end)
end

function UIStyle.Chip(props: { [string]: any }): Frame
	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = UIStyle.Palette.Panel
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	for k, v in pairs(props) do
		(chip :: any)[k] = v
	end
	UIStyle.ApplyCorner(chip, UDim.new(0, 8))
	UIStyle.ApplyStroke(chip, UIStyle.Palette.PanelStroke, 2)
	return chip
end

return UIStyle
