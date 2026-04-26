--!strict
-- First-run tutorial. Walks a new player through the four core moments:
--   1. Find the angler NPC and grab a rod
--   2. Equip the rod and click on the water to cast
--   3. Decide on the card that pops up
--   4. Closing nudge — keep fishing, every catch teaches you a phish pattern
--
-- Stage 1 places a bobbing 3D arrow over the angler AND draws a Beam from
-- the player's HumanoidRootPart to the angler so you can see the path.
-- Subsequent stages are sticky banner text only.
--
-- The banner sits top-right (out of the play area), can be minimized to
-- a small "?" chip, and renders on a high-DisplayOrder ScreenGui so it
-- always overlays other UIs.
--
-- Stage advances by listening to existing remotes — RodGranted ->
-- CastStarted -> DecisionResult. No new server events.

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
local activeChip: TextButton? = nil
local activeBeam: Beam? = nil
local beamPlayerAttachment: Attachment? = nil
local beamTargetAttachment: Attachment? = nil
local sawCastFirst = false
local sawDecisionFirst = false
local minimized = false

-- Banner content for the currently shown stage (so re-expand can rebuild it).
local currentTitle = ""
local currentText = ""

-- ---------------------------------------------------------------------------
-- ScreenGui — high DisplayOrder so the tutorial overlays everything else.
-- ---------------------------------------------------------------------------

local function tutorialScreen(): ScreenGui
	local existing = playerGui:FindFirstChild("PhishTutorialGui")
	if existing and existing:IsA("ScreenGui") then return existing end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhishTutorialGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000  -- above shop / dex / catch popup / HUD
	gui.Parent = playerGui
	return gui
end

-- ---------------------------------------------------------------------------
-- Beam path to target. Two Attachments + one Beam parented to the player
-- HRP attachment. Updated on stage transitions.
-- ---------------------------------------------------------------------------

local function getRoot(): BasePart?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function ensurePlayerAttachment(): Attachment?
	local root = getRoot()
	if not root then return nil end
	if beamPlayerAttachment and beamPlayerAttachment.Parent == root then
		return beamPlayerAttachment
	end
	if beamPlayerAttachment then beamPlayerAttachment:Destroy() end
	local att = Instance.new("Attachment")
	att.Name = "PhishTutorialAtt"
	att.Position = Vector3.new(0, 1.5, 0)
	att.Parent = root
	beamPlayerAttachment = att
	return att
end

local function clearBeam()
	if activeBeam then activeBeam:Destroy(); activeBeam = nil end
	if beamTargetAttachment then beamTargetAttachment:Destroy(); beamTargetAttachment = nil end
end

local function showBeamTo(target: BasePart)
	clearBeam()
	local fromAtt = ensurePlayerAttachment()
	if not fromAtt then return end

	local toAtt = Instance.new("Attachment")
	toAtt.Name = "PhishTutorialTargetAtt"
	toAtt.Position = Vector3.new(0, 2, 0)
	toAtt.Parent = target
	beamTargetAttachment = toAtt

	local beam = Instance.new("Beam")
	beam.Name = "PhishTutorialBeam"
	beam.Attachment0 = fromAtt
	beam.Attachment1 = toAtt
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.LightInfluence = 0
	beam.Width0 = 1.4
	beam.Width1 = 1.4
	beam.Segments = 16
	beam.Color = ColorSequence.new(UIStyle.Palette.AskFirst)
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureLength = 6
	beam.TextureSpeed = 2.5
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	beam.Parent = fromAtt
	activeBeam = beam
end

-- ---------------------------------------------------------------------------
-- 3D arrow above the target (companion to the beam).
-- ---------------------------------------------------------------------------

local function findNpcAdornee(): BasePart?
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
	if activeArrow then activeArrow:Destroy(); activeArrow = nil end
end

local function showArrow(target: BasePart, label: string)
	clearArrow()
	local gui = Instance.new("BillboardGui")
	gui.Name = "PhishTutorialArrow"
	gui.Adornee = target
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(80, 110)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.Parent = target

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

	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 0)
	pill.Size = UDim2.fromOffset(80, 24)
	pill.BackgroundColor3 = UIStyle.Palette.AskFirst
	pill.BorderSizePixel = 0
	pill.Text = label
	pill.Font = UIStyle.FontDisplay
	pill.TextSize = 14
	pill.TextColor3 = Color3.fromRGB(60, 36, 8)
	pill.Parent = gui
	UIStyle.ApplyCorner(pill, UDim.new(0, 6))
	UIStyle.ApplyStroke(pill, Color3.fromRGB(120, 70, 20), 2)

	local bobInfo = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(arrow, bobInfo, { Position = UDim2.new(0.5, 0, 0, 16) }):Play()

	activeArrow = gui
end

-- ---------------------------------------------------------------------------
-- Banner + minimize chip. Lives top-right out of the play area.
-- ---------------------------------------------------------------------------

local STAGE_LABELS = { "1", "2", "3", "4", "5" }

local function clearBanner()
	if activeBanner then activeBanner:Destroy(); activeBanner = nil end
end

local function clearChip()
	if activeChip then activeChip:Destroy(); activeChip = nil end
end

local showBanner: (string, string, { sticky: boolean?, durationSec: number? }?) -> ()
local showChip: () -> ()
local expand: () -> ()

showChip = function()
	clearChip()
	clearBanner()
	local screen = tutorialScreen()
	local chip = Instance.new("TextButton")
	chip.Name = "PhishTutorialChip"
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, -16, 0, 56)
	chip.Size = UDim2.fromOffset(48, 48)
	chip.BackgroundColor3 = UIStyle.Palette.AskFirst
	chip.BorderSizePixel = 0
	chip.AutoButtonColor = true
	chip.Text = "?"
	chip.Font = UIStyle.FontDisplay
	chip.TextSize = 28
	chip.TextColor3 = Color3.fromRGB(60, 36, 8)
	chip.Parent = screen
	UIStyle.ApplyCorner(chip, UDim.new(1, 0))
	UIStyle.ApplyStroke(chip, Color3.fromRGB(120, 70, 20), 2)

	-- Stage badge in the corner.
	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -4)
	badge.Size = UDim2.fromOffset(20, 20)
	badge.BackgroundColor3 = UIStyle.Palette.Risky
	badge.BorderSizePixel = 0
	badge.Text = STAGE_LABELS[stage] or tostring(stage)
	badge.Font = UIStyle.FontDisplay
	badge.TextSize = 14
	badge.TextColor3 = Color3.fromRGB(255, 245, 240)
	badge.Parent = chip
	UIStyle.ApplyCorner(badge, UDim.new(1, 0))

	chip.MouseButton1Click:Connect(function()
		minimized = false
		expand()
	end)
	activeChip = chip
end

expand = function()
	clearChip()
	if currentTitle == "" then return end
	showBanner(currentTitle, currentText, { sticky = true })
end

showBanner = function(title, text, opts)
	currentTitle = title
	currentText = text
	if minimized then
		showChip()
		return
	end
	clearBanner()
	clearChip()
	local screen = tutorialScreen()
	-- Top-right placement, out of the play area but still in view.
	local frame = UIStyle.MakePanel({
		Name = "PhishTutorialBanner",
		Size = UDim2.new(0, 340, 0, 124),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 16 + 340, 0, 56),  -- start off-screen right
		BackgroundColor3 = UIStyle.Palette.Highlight,
		Parent = screen,
	})
	-- Stage pill on the top-left.
	local stagePill = Instance.new("TextLabel")
	stagePill.Name = "Stage"
	stagePill.Position = UDim2.fromOffset(8, 8)
	stagePill.Size = UDim2.fromOffset(72, 22)
	stagePill.BackgroundColor3 = UIStyle.Palette.AskFirst
	stagePill.BorderSizePixel = 0
	stagePill.Text = string.format("STEP %s/5", STAGE_LABELS[stage] or tostring(stage))
	stagePill.Font = UIStyle.FontDisplay
	stagePill.TextSize = 12
	stagePill.TextColor3 = Color3.fromRGB(60, 36, 8)
	stagePill.Parent = frame
	UIStyle.ApplyCorner(stagePill, UDim.new(0, 6))

	-- Minimize "−" button top-right.
	local minBtn = Instance.new("TextButton")
	minBtn.Name = "Minimize"
	minBtn.AnchorPoint = Vector2.new(1, 0)
	minBtn.Position = UDim2.new(1, -8, 0, 8)
	minBtn.Size = UDim2.fromOffset(24, 22)
	minBtn.BackgroundColor3 = Color3.fromRGB(60, 44, 28)
	minBtn.BorderSizePixel = 0
	minBtn.AutoButtonColor = true
	minBtn.Text = "−"
	minBtn.Font = UIStyle.FontDisplay
	minBtn.TextSize = 22
	minBtn.TextColor3 = Color3.fromRGB(255, 245, 220)
	minBtn.Parent = frame
	UIStyle.ApplyCorner(minBtn, UDim.new(0, 4))
	minBtn.MouseButton1Click:Connect(function()
		minimized = true
		showChip()
	end)

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 36),
		Text = title,
		Font = UIStyle.FontDisplay,
		TextSize = UIStyle.TextSize.Heading,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 56),
		Position = UDim2.fromOffset(8, 62),
		Text = text,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})

	-- Slide in from the right.
	TweenService:Create(frame,
		TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -16, 0, 56) }):Play()
	activeBanner = frame

	if opts and not opts.sticky then
		local dur = (opts and opts.durationSec) or 5
		local capture = frame
		task.delay(dur, function()
			if activeBanner == capture then clearBanner() end
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
		showArrow(target, "TALK")
		showBeamTo(target)
	end
	showBanner("Get a fishing rod",
		"Walk up to the angler (follow the gold trail) and press E to grab your first rod.",
		{ sticky = true })
end

local function gotoStage2()
	if stage >= 2 then return end
	stage = 2
	clearArrow()
	clearBeam()
	showBanner("Cast your line",
		"Press 1 to equip your rod. Aim at the water and click to cast a line.",
		{ sticky = true })
end

local function gotoStage3()
	if stage >= 3 then return end
	stage = 3
	showBanner("Spot the scam",
		"A card just appeared. Read it carefully — KEEP if it's a real message, CUT BAIT if it's a scam.",
		{ sticky = true })
end

local function tutorialDone()
	clearBanner()
	clearChip()
	clearArrow()
	clearBeam()
	currentTitle = ""
	currentText = ""
end

-- Stage 5: walk back to the angler and sell. Repaints the beam + arrow.
local function gotoStage5()
	if stage >= 5 then return end
	stage = 5
	local target: BasePart? = findNpcAdornee()
	if target then
		showArrow(target, "SELL")
		showBeamTo(target)
	end
	showBanner("Sell your fish",
		"Walk back to the angler and press E to sell. Pearls let you upgrade your gear.",
		{ sticky = true })
end

-- Stage 4 splits on whether a fish actually got added:
--   correct catch -> brief celebration, then stage 5 (sell)
--   wrong call -> "every catch teaches you" + auto-dismiss
local function gotoStage4(fishAdded: boolean?)
	if stage >= 4 then return end
	stage = 4
	if fishAdded then
		showBanner("Nice catch!",
			"You've got a fish. Now sell it at the angler for pearls.",
			{ sticky = true })
		task.delay(2.0, function()
			if stage == 4 then gotoStage5() end
		end)
	else
		showBanner("Keep fishing!",
			"Every catch teaches you a phishing pattern. Cast again to try another.",
			{ sticky = true })
		task.delay(6, tutorialDone)
	end
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

local function start(character: Model)
	if alreadyHasRod(character) then
		gotoStage2()
	else
		gotoStage1()
	end
end

if player.Character then
	task.spawn(start, player.Character)
end
player.CharacterAdded:Connect(function(character)
	-- Beam attachment lives on the HRP, which is recreated each spawn.
	beamPlayerAttachment = nil
	clearBeam()
	start(character)
end)

RemoteService.OnClientEvent("RodGranted", function() gotoStage2() end)

RemoteService.OnClientEvent("CastStarted", function()
	if sawCastFirst then return end
	sawCastFirst = true
	gotoStage3()
end)

RemoteService.OnClientEvent("DecisionResult", function(payload)
	if sawDecisionFirst then return end
	sawDecisionFirst = true
	local fishAdded = type(payload) == "table" and payload.fishAddedToInventory == true
	gotoStage4(fishAdded)
end)

-- Player sold their first fish: tutorial complete.
RemoteService.OnClientEvent("SellResult", function(payload)
	if stage < 5 then return end
	if type(payload) ~= "table" or (payload.soldCount or 0) <= 0 then return end
	clearArrow()
	clearBeam()
	showBanner("Way to go!",
		"That's your first pearls. Keep fishing — the more phish you spot, the smarter you get.",
		{ sticky = true })
	task.delay(5, tutorialDone)
end)
