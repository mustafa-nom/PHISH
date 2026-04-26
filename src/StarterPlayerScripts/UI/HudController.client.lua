--!strict
-- Top HUD: coins, accuracy %, level/XP. Dark themed pill chips.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local IconFactory = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("IconFactory"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

local existing = screen:FindFirstChild("PhishHud")
if existing then existing:Destroy() end

local hud = Instance.new("Frame")
hud.Name = "PhishHud"
hud.Size = UDim2.new(1, 0, 0, 100)
hud.Position = UDim2.fromScale(0, 0)
hud.BackgroundTransparency = 1
hud.Parent = screen

-- Build a dark pill chip with optional left-side icon.
local function makePill(name: string, anchor: Vector2, pos: UDim2, size: Vector2, icon: GuiObject?): TextLabel
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.AnchorPoint = anchor
	chip.Position = pos
	chip.Size = UDim2.fromOffset(size.X, size.Y)
	chip.BackgroundColor3 = UIStyle.Palette.Panel
	chip.BorderSizePixel = 0
	chip.Parent = hud
	UIStyle.ApplyCorner(chip, UDim.new(0, 12))
	UIStyle.ApplyStroke(chip, UIStyle.Palette.PanelStroke, 2)
	UIStyle.ApplyGradient(chip, {
		top = Color3.fromRGB(60, 50, 60),
		bottom = Color3.fromRGB(28, 22, 30),
		rotation = 90,
	})

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = chip

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = chip

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = row

	if icon then
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.LayoutOrder = 1
		icon.Parent = row
	end

	local label = UIStyle.MakeLabel({
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = "—",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextPrimary,
		Parent = row,
	})
	return label
end

-- TOP-RIGHT cluster: coins (gold) above level/XP.
local coinsLabel = makePill("CoinsChip",
	Vector2.new(1, 0), UDim2.new(1, -16, 0, 12),
	Vector2.new(170, 40),
	IconFactory.Coin(24))
coinsLabel.TextColor3 = UIStyle.Palette.TitleGold
coinsLabel.Font = UIStyle.FontDisplay
coinsLabel.TextSize = UIStyle.TextSize.Heading

local levelLabel = makePill("LevelChip",
	Vector2.new(1, 0), UDim2.new(1, -16, 0, 60),
	Vector2.new(220, 40),
	nil)
levelLabel.TextColor3 = UIStyle.Palette.TextPrimary
levelLabel.Font = UIStyle.FontBold

-- TOP-LEFT: accuracy chip (kept for parity with previous HUD).
local accuracyLabel = makePill("AccuracyChip",
	Vector2.new(0, 0), UDim2.new(0, 16, 0, 12),
	Vector2.new(140, 40),
	IconFactory.Target(24))
accuracyLabel.TextColor3 = UIStyle.Palette.Highlight
accuracyLabel.Font = UIStyle.FontBold

local function render(snapshot: any)
	if not snapshot then return end
	coinsLabel.Text = string.format("%d C$", snapshot.coins or 0)

	local acc = snapshot.accuracy or 0
	accuracyLabel.Text = string.format("%d%%", math.floor(acc * 100))

	local level = snapshot.level or 1
	local role = snapshot.role or "Angler"
	if snapshot.isMaxLevel == true then
		levelLabel.Text = string.format("Lv %d %s · MAX", level, role)
	else
		local cur = snapshot.xpIntoLevel or 0
		local need = snapshot.xpForNextLevel or 1
		levelLabel.Text = string.format("Lv %d %s · %d/%d XP", level, role, cur, need)
	end
end

RemoteService.OnClientEvent("HudUpdated", render)

-- Warm initial state from the server.
task.spawn(function()
	local ok, snapshot = pcall(function() return RemoteService.InvokeServer("GetPlayerSnapshot") end)
	if ok then render(snapshot) end
end)

-- Generic notify toasts.
RemoteService.OnClientEvent("Notify", function(payload)
	if type(payload) ~= "table" then return end
	UIBuilder.Toast(payload.message or "", payload.duration, payload.kind)
end)

-- Species unlock toast.
RemoteService.OnClientEvent("SpeciesUnlocked", function(payload)
	if type(payload) ~= "table" then return end
	UIBuilder.Toast("New dex entry: " .. (payload.displayName or ""), 5, "Success")
end)

-- Tutorial nudge: a richer one-shot card with title + body + auto-dismiss.
local function showNudge(payload: any)
	if type(payload) ~= "table" then return end
	local old = screen:FindFirstChild("PhishTutorialNudge")
	if old then old:Destroy() end
	local card = UIStyle.MakePanel({
		Name = "PhishTutorialNudge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(440, 110),
		BackgroundColor3 = UIStyle.Palette.Panel,
	})
	card.Parent = screen
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 8),
		Text = payload.title or "Tip",
		Font = UIStyle.FontDisplay, TextSize = UIStyle.TextSize.Heading,
		TextColor3 = UIStyle.Palette.TitleGold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 40),
		Text = payload.text or "",
		TextSize = UIStyle.TextSize.Body, TextWrapped = true,
		TextColor3 = UIStyle.Palette.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	task.delay(payload.durationSec or 6, function()
		if card and card.Parent then card:Destroy() end
	end)
end
RemoteService.OnClientEvent("TutorialNudge", showNudge)

-- CastStarted: server confirmed the cast. Play a quick local SFX.
local castSound = Instance.new("Sound")
castSound.Name = "CastWhoosh"
castSound.SoundId = "rbxassetid://9114143000"
castSound.Volume = 0.4
castSound.Parent = script
RemoteService.OnClientEvent("CastStarted", function()
	pcall(function() castSound:Play() end)
end)
