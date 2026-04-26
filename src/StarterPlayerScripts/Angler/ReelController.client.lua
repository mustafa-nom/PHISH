--!strict
-- Bite → one deliberate "Reel it in" on a large green button (no more 3× screen taps).
-- Fires RequestReelTap; server counts toward PhishConstants.REEL_TAPS_REQUIRED, then
-- ShowInspectionCard. Optional Space/Enter when this panel is up for accessibility.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local UIBuilder = require(Players.LocalPlayer.PlayerScripts:WaitForChild("UI"):WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

local active = false
local taps = 0
local required = PhishConstants.REEL_TAPS_REQUIRED
local mainButton: TextButton? = nil
local barFill: Frame? = nil

local function clearBar()
	local old = screen:FindFirstChild("PhishReelBar")
	if old then old:Destroy() end
	mainButton = nil
	barFill = nil
end

local function onReelPressed()
	if not active then return end
	RemoteService.FireServer("RequestReelTap")
end

local function setBarProgress(fraction: number)
	if barFill then
		barFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
	if mainButton and active then
		mainButton.Text = if taps >= required then "Reeling in…" else "Reel it in!"
		mainButton.AutoButtonColor = taps < required
		mainButton.Active = taps < required
	end
end

local function showReelUI()
	clearBar()
	local panel = UIStyle.MakePanel({
		Name = "PhishReelBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 400, 0, 200),
	})
	panel.Parent = screen
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(320, 180)
	minSize.MaxSize = Vector2.new(480, 240)
	minSize.Parent = panel

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(12, 12),
		Text = "Fish on the line!",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	UIStyle.MakeLabel({
		Name = "Subtext",
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 48),
		Text = "Tap the green button (or press Space) to land the catch and open the message.",
		TextSize = UIStyle.TextSize.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = panel,
	})

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -32, 0, 10)
	barBg.Position = UDim2.new(0, 16, 0, 100)
	barBg.BackgroundColor3 = UIStyle.Palette.Background
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	UIStyle.ApplyCorner(barBg, UDim.new(0, 6))
	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = UIStyle.Palette.Safe
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	UIStyle.ApplyCorner(barFill, UDim.new(0, 6))

	local btn = UIStyle.MakeButton({
		Name = "ReelCta",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -32, 0, 58),
		Text = "Reel it in!",
		BackgroundColor3 = UIStyle.Palette.Safe,
		Parent = panel,
	})
	mainButton = btn
	UIStyle.ApplyStroke(btn, Color3.fromRGB(60, 120, 55), 2)
	btn.Activated:Connect(onReelPressed)
	setBarProgress(0)
end

local function updateBar()
	local panel = screen:FindFirstChild("PhishReelBar")
	if not panel then return end
	local sub = panel:FindFirstChild("Subtext") :: TextLabel?
	if sub and required > 0 then
		if required == 1 and taps == 0 then
			sub.Text = "One pull on the green button to finish."
		else
			sub.Text = string.format("Reel progress: %d / %d", taps, required)
		end
	end
	if required > 0 then
		setBarProgress(taps / required)
	else
		setBarProgress(1)
	end
end

RemoteService.OnClientEvent("BiteOccurred", function(payload)
	if type(payload) == "table" and payload.tapsRequired then
		required = payload.tapsRequired
	else
		required = PhishConstants.REEL_TAPS_REQUIRED
	end
	taps = 0
	active = true
	showReelUI()
end)

RemoteService.OnClientEvent("ReelProgress", function(payload)
	if type(payload) ~= "table" then return end
	taps = payload.count or taps
	required = payload.required or required
	updateBar()
end)

RemoteService.OnClientEvent("ReelFailed", function()
	active = false
	clearBar()
	UIBuilder.Toast("Got away! Cast again.", 2, "Error")
end)

RemoteService.OnClientEvent("ShowInspectionCard", function()
	active = false
	clearBar()
end)

-- Accessibility: same action as the green button (only while reel is active)
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or not active then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
		onReelPressed()
	end
end)
