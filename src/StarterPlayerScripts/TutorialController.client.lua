--!strict
-- First-run tutorial. Walks a new player through the four core moments:
--   1. Find the angler NPC and grab a rod
--   2. Cast a line at the water
--   3. Decide on the card that pops up
--   4. Closing nudge — keep fishing, every catch teaches you a phish pattern
--
-- Stage 1 places a bobbing 3D arrow over the angler. Subsequent stages
-- are just sticky banner text. Tutorial advances by listening to the
-- existing RodGranted / CastStarted / DecisionResult remotes — no new
-- server events needed.
--
-- Skips entirely if the player already has a rod tool on character add
-- (e.g. they rejoined). State is per-session; not persisted in profile.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROD_TOOL_NAME = "Fishing Rod"

local stage = 0
local activeArrow: BillboardGui? = nil
local activeBanner: Frame? = nil
local sawCastFirst = false
local sawDecisionFirst = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function tutorialScreen(): ScreenGui
	local existing = playerGui:FindFirstChild("PhishTutorialGui")
	if existing and existing:IsA("ScreenGui") then return existing end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhishTutorialGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 25
	gui.Parent = playerGui
	return gui
end

local function findNpcAdornee(): BasePart?
	-- Prefer the Head of the angler model so the arrow floats above it,
	-- fall back to PrimaryPart, then any BasePart.
	local tagged = CollectionService:GetTagged(PhishConstants.Tags.NpcAngler)
	for _, npc in ipairs(tagged) do
		if npc:IsA("Model") then
			local head = npc:FindFirstChild("Head")
			if head and head:IsA("BasePart") then return head end
			if npc.PrimaryPart then return npc.PrimaryPart end
			for _, d in ipairs(npc:GetDescendants()) do
				if d:IsA("BasePart") then return d end
			end
		elseif npc:IsA("BasePart") then
			return npc
		end
	end
	return nil
end

local function clearArrow()
	if activeArrow then
		activeArrow:Destroy()
		activeArrow = nil
	end
end

local function showArrow(target: BasePart)
	clearArrow()
	local gui = Instance.new("BillboardGui")
	gui.Name = "PhishTutorialArrow"
	gui.Adornee = target
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(80, 110)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.Parent = target

	-- Big animated arrow head.
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Head"
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Position = UDim2.new(0.5, 0, 0, 28)
	arrow.Size = UDim2.fromOffset(80, 64)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.Font = UIStyle.FontDisplay
	arrow.TextSize = 64
	arrow.TextColor3 = UIStyle.Palette.TitleGold
	arrow.TextStrokeColor3 = Color3.fromRGB(40, 24, 12)
	arrow.TextStrokeTransparency = 0
	arrow.Parent = gui

	-- "TALK" pill above the arrow.
	local pill = Instance.new("TextLabel")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 0)
	pill.Size = UDim2.fromOffset(70, 24)
	pill.BackgroundColor3 = UIStyle.Palette.AskFirst
	pill.BorderSizePixel = 0
	pill.Text = "TALK"
	pill.Font = UIStyle.FontDisplay
	pill.TextSize = 16
	pill.TextColor3 = Color3.fromRGB(60, 36, 8)
	pill.Parent = gui
	UIStyle.ApplyCorner(pill, UDim.new(0, 6))
	UIStyle.ApplyStroke(pill, Color3.fromRGB(120, 70, 20), 2)

	-- Bob loop on the arrow head.
	local bobInfo = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(arrow, bobInfo, { Position = UDim2.new(0.5, 0, 0, 16) }):Play()

	activeArrow = gui
end

local function clearBanner()
	if activeBanner then
		-- Tween out then destroy.
		local target = activeBanner
		TweenService:Create(target,
			TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -120) }):Play()
		task.delay(0.32, function()
			if target.Parent then target:Destroy() end
		end)
		activeBanner = nil
	end
end

local function showBanner(title: string, text: string, opts: { sticky: boolean?, durationSec: number? }?)
	clearBanner()
	local screen = tutorialScreen()
	local frame = UIStyle.MakePanel({
		Name = "PhishTutorialBanner",
		Size = UDim2.new(0, 480, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		BackgroundColor3 = UIStyle.Palette.Highlight,
		Parent = screen,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 6),
		Text = title,
		Font = UIStyle.FontDisplay,
		TextSize = UIStyle.TextSize.Heading,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 48),
		Position = UDim2.fromOffset(8, 34),
		Text = text,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		TextWrapped = true,
		Parent = frame,
	})
	TweenService:Create(frame,
		TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 110) }):Play()
	activeBanner = frame

	if opts and not opts.sticky then
		local dur = (opts and opts.durationSec) or 5
		local capture = frame
		task.delay(dur, function()
			if activeBanner == capture then
				clearBanner()
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Stage transitions
-- ---------------------------------------------------------------------------

local function gotoStage1()
	stage = 1
	-- Wait briefly for the angler tag to register on map load.
	local target: BasePart? = findNpcAdornee()
	if not target then
		task.wait(1.5)
		target = findNpcAdornee()
	end
	if target then
		showArrow(target)
	end
	showBanner("Get a fishing rod",
		"Walk up to the angler with the arrow and press E to grab your first rod.",
		{ sticky = true })
end

local function gotoStage2()
	if stage >= 2 then return end
	stage = 2
	clearArrow()
	showBanner("Cast your line",
		"Walk to the water. Hold F to charge a cast, aim at the water, and release.",
		{ sticky = true })
end

local function gotoStage3()
	if stage >= 3 then return end
	stage = 3
	showBanner("Spot the scam",
		"A card will pop up. Read it carefully — KEEP if it's a real message, CUT BAIT if it's a scam.",
		{ sticky = true })
end

local function gotoStage4()
	if stage >= 4 then return end
	stage = 4
	showBanner("Nice catch!",
		"Every fish you catch teaches you a phishing pattern. Keep fishing!",
		{ sticky = false, durationSec = 6 })
	-- Tutorial is done after this auto-dismisses; nothing else to do.
end

local function alreadyHasRod(character: Model): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ backpack, character }) do
		if container then
			if container:FindFirstChild(ROD_TOOL_NAME) then return true end
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Wire it up
-- ---------------------------------------------------------------------------

local function start(character: Model)
	-- Skip the rod-fetch stage entirely if they already have one (rejoined
	-- mid-session, etc.) and jump straight to the casting nudge.
	if alreadyHasRod(character) then
		gotoStage2()
	else
		gotoStage1()
	end
end

if player.Character then
	task.spawn(start, player.Character)
end
player.CharacterAdded:Connect(start)

RemoteService.OnClientEvent("RodGranted", function()
	gotoStage2()
end)

RemoteService.OnClientEvent("CastStarted", function()
	if sawCastFirst then return end
	sawCastFirst = true
	gotoStage3()
end)

RemoteService.OnClientEvent("DecisionResult", function()
	if sawDecisionFirst then return end
	sawDecisionFirst = true
	gotoStage4()
end)
