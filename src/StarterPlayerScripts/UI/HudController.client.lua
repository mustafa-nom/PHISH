--!strict
-- Top HUD: coins, accuracy %, role badge. Listens to HudUpdated.

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
hud.Size = UDim2.new(1, 0, 0, 56)
hud.Position = UDim2.fromScale(0, 0)
hud.BackgroundTransparency = 1
hud.Parent = screen

local function makeChip(name: string, color: Color3, anchor: Vector2, pos: UDim2): Frame
	local frame = UIStyle.MakePanel({
		Name = name,
		Size = UDim2.new(0, 200, 0, 40),
		AnchorPoint = anchor,
		Position = pos,
		BackgroundColor3 = color,
	})
	frame.Parent = hud
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = frame
	return frame
end

local function makeIconChip(name: string, color: Color3, anchor: Vector2, pos: UDim2, icon: GuiObject): TextLabel
	local frame = makeChip(name, color, anchor, pos)
	local _, label = IconFactory.Pill(frame, icon, "—", UIStyle.Palette.TextPrimary, 22)
	return label
end

local coinsLabel = makeIconChip("CoinsChip", UIStyle.Palette.AskFirst,
	Vector2.new(0, 0), UDim2.new(0, 16, 0, 8),
	IconFactory.Coin(28))
local accuracyLabel = makeIconChip("AccuracyChip", UIStyle.Palette.Highlight,
	Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8),
	IconFactory.Target(26))

local roleFrame = makeChip("RoleChip", UIStyle.Palette.Safe, Vector2.new(1, 0), UDim2.new(1, -16, 0, 8))
local roleLabel = UIStyle.MakeLabel({
	Size = UDim2.fromScale(1, 1),
	Text = "Angler",
	TextSize = UIStyle.TextSize.Heading,
	TextColor3 = UIStyle.Palette.TextPrimary,
})
roleLabel.Parent = roleFrame

local function render(snapshot: any)
	if not snapshot then return end
	coinsLabel.Text = tostring(snapshot.coins or 0)
	local acc = snapshot.accuracy or 0
	accuracyLabel.Text = string.format("%d%%", math.floor(acc * 100))
	roleLabel.Text = snapshot.role or "Angler"
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
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(440, 110),
		BackgroundColor3 = UIStyle.Palette.AskFirst,
	})
	card.Parent = screen
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 8),
		Text = payload.title or "Tip",
		Font = UIStyle.FontBold, TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 40),
		Text = payload.text or "",
		TextSize = UIStyle.TextSize.Body, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	task.delay(payload.durationSec or 6, function()
		if card and card.Parent then card:Destroy() end
	end)
end
RemoteService.OnClientEvent("TutorialNudge", showNudge)

-- CastStarted: server confirmed the cast. Play a quick local SFX so the
-- input feels acknowledged. (Sound stays unloaded if asset id is missing.)
local castSound = Instance.new("Sound")
castSound.Name = "CastWhoosh"
castSound.SoundId = "rbxassetid://9114143000"  -- placeholder — swap when real sfx lands
castSound.Volume = 0.4
castSound.Parent = script
RemoteService.OnClientEvent("CastStarted", function()
	pcall(function() castSound:Play() end)
end)
