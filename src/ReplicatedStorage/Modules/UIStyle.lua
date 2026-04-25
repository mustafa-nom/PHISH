--!strict
-- Single source of UI styling. JUDGING_STRATEGY.md and user1_map_prompt.md
-- both flag visual consistency as a make-or-break for the judges, so every
-- UI controller pulls fonts/palette from here.

local UIStyle = {}

UIStyle.Font = Enum.Font.Cartoon
UIStyle.FontBold = Enum.Font.GothamBold

UIStyle.TextSize = {
	Title = 32,
	Heading = 24,
	Body = 18,
	Caption = 14,
}

-- Warm cartoon palette. No grays, no neon.
UIStyle.Palette = {
	Background = Color3.fromRGB(255, 248, 232),
	Panel = Color3.fromRGB(255, 235, 200),
	PanelStroke = Color3.fromRGB(176, 122, 70),
	TextPrimary = Color3.fromRGB(60, 40, 20),
	TextMuted = Color3.fromRGB(110, 90, 70),
	Accent = Color3.fromRGB(255, 153, 84),
	Safe = Color3.fromRGB(108, 196, 96),
	Risky = Color3.fromRGB(220, 92, 92),
	AskFirst = Color3.fromRGB(245, 200, 90),
	Highlight = Color3.fromRGB(120, 196, 240),
}

UIStyle.Corner = UDim.new(0, 16)
UIStyle.SmallCorner = UDim.new(0, 8)

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

function UIStyle.ApplyStroke(instance: Instance, color: Color3?, thickness: number?)
	local existing = instance:FindFirstChildOfClass("UIStroke")
	if existing then
		return existing
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UIStyle.Palette.PanelStroke
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
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

-- Build a styled background panel.
function UIStyle.MakePanel(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = UIStyle.Palette.Panel
	frame.BorderSizePixel = 0
	for k, v in pairs(props) do
		(frame :: any)[k] = v
	end
	UIStyle.ApplyCorner(frame)
	UIStyle.ApplyStroke(frame)
	return frame
end

return UIStyle
