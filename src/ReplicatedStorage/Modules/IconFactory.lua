--!strict
-- Font-independent emoji-style icons. Roblox's Cartoon font (and most
-- bundled fonts) don't include the coin / bullseye / sparkle / check / X
-- glyphs from Unicode 13+, so the source emoji render as tofu boxes. These
-- factories return Frame compositions that look like the intended emoji
-- and render anywhere.

local IconFactory = {}

-- Gold coin: round gold body, darker amber stroke, soft highlight, $ in
-- the middle. Looks emoji-ish at any size from 16px up.
function IconFactory.Coin(size: number?): Frame
	local s = size or 24
	local coin = Instance.new("Frame")
	coin.Name = "CoinIcon"
	coin.Size = UDim2.fromOffset(s, s)
	coin.BackgroundColor3 = Color3.fromRGB(255, 196, 60)
	coin.BorderSizePixel = 0
	coin.AnchorPoint = Vector2.new(0, 0.5)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = coin

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(176, 110, 28)
	stroke.Thickness = math.max(1, math.floor(s / 14))
	stroke.Parent = coin

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.32, 0.30)
	shine.Size = UDim2.fromScale(0.28, 0.20)
	shine.BackgroundColor3 = Color3.fromRGB(255, 245, 200)
	shine.BackgroundTransparency = 0.15
	shine.BorderSizePixel = 0
	shine.Parent = coin
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = shine

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.9)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.55)
	label.BackgroundTransparency = 1
	label.Text = "$"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 70, 14)
	label.Parent = coin

	return coin
end

-- Red bullseye with a dot. Replaces accuracy crosshair emoji.
function IconFactory.Target(size: number?): Frame
	local s = size or 24
	local outer = Instance.new("Frame")
	outer.Name = "TargetIcon"
	outer.Size = UDim2.fromOffset(s, s)
	outer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	outer.BorderSizePixel = 0
	outer.AnchorPoint = Vector2.new(0, 0.5)
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(1, 0)
	oc.Parent = outer
	local os_ = Instance.new("UIStroke")
	os_.Color = Color3.fromRGB(220, 60, 60)
	os_.Thickness = math.max(1, math.floor(s / 8))
	os_.Parent = outer

	local mid = Instance.new("Frame")
	mid.AnchorPoint = Vector2.new(0.5, 0.5)
	mid.Position = UDim2.fromScale(0.5, 0.5)
	mid.Size = UDim2.fromScale(0.55, 0.55)
	mid.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	mid.BorderSizePixel = 0
	mid.Parent = outer
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(1, 0)
	mc.Parent = mid

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.22, 0.22)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.Parent = outer
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot

	return outer
end

-- Tiny sparkle for XP gains.
function IconFactory.Sparkle(size: number?): Frame
	local s = size or 22
	local star = Instance.new("Frame")
	star.Name = "SparkleIcon"
	star.Size = UDim2.fromOffset(s, s)
	star.BackgroundTransparency = 1
	star.AnchorPoint = Vector2.new(0, 0.5)

	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.55, 0.55)
	core.BackgroundColor3 = Color3.fromRGB(255, 230, 110)
	core.BorderSizePixel = 0
	core.Rotation = 45
	core.Parent = star

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.3, 0.3)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.Parent = star
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot

	return star
end

-- Green check (filled circle + tick).
function IconFactory.Check(size: number?): Frame
	local s = size or 28
	local circle = Instance.new("Frame")
	circle.Name = "CheckIcon"
	circle.Size = UDim2.fromOffset(s, s)
	circle.BackgroundColor3 = Color3.fromRGB(108, 196, 96)
	circle.BorderSizePixel = 0
	circle.AnchorPoint = Vector2.new(0, 0.5)
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circle

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.9)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.55)
	label.BackgroundTransparency = 1
	label.Text = "v"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Rotation = -8
	label.Parent = circle

	return circle
end

-- Red X (filled circle + X).
function IconFactory.Cross(size: number?): Frame
	local s = size or 28
	local circle = Instance.new("Frame")
	circle.Name = "CrossIcon"
	circle.Size = UDim2.fromOffset(s, s)
	circle.BackgroundColor3 = Color3.fromRGB(220, 92, 92)
	circle.BorderSizePixel = 0
	circle.AnchorPoint = Vector2.new(0, 0.5)
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circle

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.9)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.55)
	label.BackgroundTransparency = 1
	label.Text = "X"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = circle

	return circle
end

-- Helper: lay out an icon + a label in a single horizontal pill. Returns
-- the (frame, label) so callers can update the text reactively.
function IconFactory.Pill(parent: Instance, icon: GuiObject, text: string, textColor: Color3?, fontSize: number?): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	icon.LayoutOrder = 1
	icon.Parent = row

	local label = Instance.new("TextLabel")
	label.LayoutOrder = 2
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = fontSize or 22
	label.TextColor3 = textColor or Color3.fromRGB(60, 40, 20)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = row

	return row, label
end

return IconFactory
