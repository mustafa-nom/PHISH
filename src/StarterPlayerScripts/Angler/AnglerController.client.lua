--!strict
-- Angler input: F to cast (or hold to charge). Reads zone state from
-- ZoneEntered/ZoneLeft and disables cast UI when in shop/boat.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local _ = player

local state = {
	charging = false,
	chargeStart = 0,
	zone = nil :: { ZoneId: string, Tier: number, DisplayName: string, RequiredRodTier: number, Color: Color3 }?,
	inputBlocked = false,
}

local screen = UIBuilder.GetScreenGui()

local panel = screen:FindFirstChild("AnglerHud") or UIStyle.MakePanel({
	Name = "AnglerHud",
	Size = UDim2.new(0, 320, 0, 92),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Parent = screen,
})

local title = UIStyle.MakeLabel({
	Size = UDim2.new(1, -16, 0, 28),
	Position = UDim2.new(0, 8, 0, 4),
	Text = "Hold F to cast",
	TextSize = UIStyle.TextSize.Heading,
})
title.Parent = panel

local hint = UIStyle.MakeLabel({
	Size = UDim2.new(1, -16, 0, 22),
	Position = UDim2.new(0, 8, 0, 32),
	Text = "Walk to the dock to fish.",
	TextSize = UIStyle.TextSize.Body,
	TextColor3 = UIStyle.Palette.TextMuted,
})
hint.Parent = panel

local chargeBg = Instance.new("Frame")
chargeBg.Size = UDim2.new(1, -16, 0, 12)
chargeBg.Position = UDim2.new(0, 8, 1, -22)
chargeBg.BackgroundColor3 = UIStyle.Palette.Background
chargeBg.BorderSizePixel = 0
chargeBg.Parent = panel
UIStyle.ApplyCorner(chargeBg, UDim.new(0, 6))

local chargeFill = Instance.new("Frame")
chargeFill.Size = UDim2.new(0, 0, 1, 0)
chargeFill.BackgroundColor3 = UIStyle.Palette.Accent
chargeFill.BorderSizePixel = 0
chargeFill.Parent = chargeBg
UIStyle.ApplyCorner(chargeFill, UDim.new(0, 6))

local function updateHud()
	if state.zone then
		title.Text = ("Tier %d — %s"):format(state.zone.Tier, state.zone.DisplayName)
		title.TextColor3 = state.zone.Color
		hint.Text = ("Hold F to cast (Tier %d rod required)"):format(state.zone.RequiredRodTier)
		hint.TextColor3 = UIStyle.Palette.TextMuted
	else
		title.Text = "Hold F to cast"
		title.TextColor3 = UIStyle.Palette.TextPrimary
		hint.Text = "Walk to a dock or pond edge first."
	end
end
updateHud()

RemoteService.OnClientEvent("ZoneEntered", function(payload)
	if typeof(payload) ~= "table" then return end
	state.zone = {
		ZoneId = payload.ZoneId,
		Tier = payload.Tier,
		DisplayName = payload.DisplayName,
		RequiredRodTier = payload.RequiredRodTier,
		Color = payload.Color,
	}
	updateHud()
end)

RemoteService.OnClientEvent("ZoneLeft", function()
	state.zone = nil
	updateHud()
end)

local function chargePower(): number
	local elapsed = os.clock() - state.chargeStart
	local span = Constants.CAST_CHARGE_MAX - Constants.CAST_CHARGE_MIN
	if span <= 0 then return 1 end
	return math.clamp((elapsed - Constants.CAST_CHARGE_MIN) / span, 0, 1)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or state.inputBlocked then return end
	if input.KeyCode == Enum.KeyCode.F and not state.charging then
		state.charging = true
		state.chargeStart = os.clock()
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.F and state.charging then
		state.charging = false
		if processed or state.inputBlocked then return end
		local power = chargePower()
		chargeFill.Size = UDim2.new(0, 0, 1, 0)
		RemoteService.FireServer("RequestCast", { chargePower = power })
	end
end)

RunService.RenderStepped:Connect(function()
	if state.charging then
		local power = chargePower()
		chargeFill.Size = UDim2.new(power, 0, 1, 0)
	end
end)

local function setBlocked(blocked: boolean)
	state.inputBlocked = blocked
end

-- Other controllers can write to a BoolValue so we don't tightly couple via require.
local block = Instance.new("BoolValue")
block.Name = "AnglerInputBlocked"
block.Value = false
block.Parent = screen
block.Changed:Connect(function() setBlocked(block.Value) end)
