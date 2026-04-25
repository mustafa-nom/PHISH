--!strict
-- Explorer-side decision card for the new Stranger Danger flow.
--
-- When the Explorer hits Inspect on an NPC, the SERVER sends them a payload
-- with ONLY the silhouette (no trait list). This card shows that silhouette
-- + three big buttons:
--   APPROACH    — commit to talking
--   ASK FIRST   — request one more cue from the Guide
--   AVOID       — back away
--
-- ASKFIRST cues stream in via NpcCueRevealed and pile up below the buttons,
-- so the Explorer can see the few details the Guide chose to share with
-- them. Each NPC has a max of 3 asks before the buddy "can't see more."
--
-- Card auto-clears on NpcActionResolved or after 12s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))
local StrangerDangerLogic = require(Modules:WaitForChild("StrangerDangerLogic"))

local UIBuilder = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local localPlayer = Players.LocalPlayer
local _ = localPlayer
local currentRole = RoleTypes.None
local card: Frame? = nil
local activeNpcId: string? = nil
local cuesContainer: Frame? = nil
local cueRows: { [string]: TextLabel } = {}
local rings: { [string]: BasePart } = {}

local function playSfx(name: string)
	local s = SoundService:FindFirstChild(name)
	if s and s:IsA("Sound") then
		local clone = s:Clone()
		clone.Parent = SoundService
		clone:Play()
		task.delay(2, function() clone:Destroy() end)
	end
end

local function getNpcModel(npcId: string): Model?
	for _, slot in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.PlayArenaSlot)) do
		local playArea = slot:FindFirstChild("PlayArea")
		if playArea then
			for _, level in ipairs(playArea:GetChildren()) do
				local model = level:FindFirstChild(npcId)
				if model and model:IsA("Model") then
					return model
				end
			end
		end
	end
	return nil
end

local function clearCard()
	if card and card.Parent then card:Destroy() end
	card = nil
	activeNpcId = nil
	cuesContainer = nil
	cueRows = {}
end

local function makeActionButton(parent: Frame, name: string, label: string, color: Color3, layout: number)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = label
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = UIStyle.FontBold
	btn.TextSize = 22
	btn.TextColor3 = Color3.fromRGB(28, 18, 8)
	btn.LayoutOrder = layout
	btn.Parent = parent
	UIStyle.ApplyCorner(btn, UDim.new(0, 12))
	UIStyle.ApplyStroke(btn, Color3.fromRGB(80, 50, 30), 2)
	return btn
end

local function showCard(npcId: string, archetype: string?, silhouette: any, revealedCues: { string }?)
	clearCard()
	activeNpcId = npcId
	local screen = UIBuilder.GetScreenGui()

	card = UIStyle.MakePanel({
		Name = "NpcActionCard",
		Size = UDim2.new(0, 360, 0, 460),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Parent = screen,
	})
	UIBuilder.PadLayout(card :: Frame, 12)

	-- accent strip on the left edge — colored by silhouette accent so the
	-- explorer can match the npc visually
	local accent = silhouette and silhouette.AccentColor
	local accentColor = accent and Color3.fromRGB(accent[1] or 200, accent[2] or 200, accent[3] or 200)
		or Color3.fromRGB(200, 200, 200)
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 6, 1, -16)
	stripe.Position = UDim2.new(0, -6, 0, 8)
	stripe.BackgroundColor3 = accentColor
	stripe.BorderSizePixel = 0
	stripe.Parent = card
	UIStyle.ApplyCorner(stripe, UDim.new(0, 3))

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Text = "WHAT YOU SEE",
		TextSize = UIStyle.TextSize.Caption,
		Font = UIStyle.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 80, 50),
	})
	title.Parent = card

	local headline = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0, 24),
		Text = (silhouette and silhouette.Headline) or "Someone in the park",
		TextSize = UIStyle.TextSize.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Font = UIStyle.Font,
	})
	headline.Parent = card

	local outline = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 86),
		Text = (silhouette and silhouette.Outline) or "",
		TextSize = UIStyle.TextSize.Caption,
		Font = UIStyle.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = accentColor,
	})
	outline.Parent = card

	-- cues that the Guide has shared (via AskFirst). starts hidden until at
	-- least one cue is revealed.
	local cuesPanel = Instance.new("Frame")
	cuesPanel.Name = "CuesPanel"
	cuesPanel.Size = UDim2.new(1, 0, 0, 110)
	cuesPanel.Position = UDim2.new(0, 0, 0, 116)
	cuesPanel.BackgroundColor3 = UIStyle.Palette.Panel
	cuesPanel.BorderSizePixel = 0
	cuesPanel.Parent = card
	UIStyle.ApplyCorner(cuesPanel, UDim.new(0, 10))
	local cuesPad = Instance.new("UIPadding")
	cuesPad.PaddingTop = UDim.new(0, 8)
	cuesPad.PaddingBottom = UDim.new(0, 8)
	cuesPad.PaddingLeft = UDim.new(0, 10)
	cuesPad.PaddingRight = UDim.new(0, 10)
	cuesPad.Parent = cuesPanel

	local cueHeader = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 18),
		Text = "Buddy says...",
		TextSize = UIStyle.TextSize.Caption,
		Font = UIStyle.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 80, 50),
	})
	cueHeader.LayoutOrder = 0
	cueHeader.Parent = cuesPanel

	local cueListHolder = Instance.new("Frame")
	cueListHolder.Size = UDim2.new(1, 0, 1, -22)
	cueListHolder.Position = UDim2.new(0, 0, 0, 22)
	cueListHolder.BackgroundTransparency = 1
	cueListHolder.Parent = cuesPanel

	local cueList = Instance.new("UIListLayout")
	cueList.SortOrder = Enum.SortOrder.LayoutOrder
	cueList.Padding = UDim.new(0, 4)
	cueList.Parent = cueListHolder
	cuesContainer = cueListHolder

	-- pre-populate with any cues the server already revealed (for replays)
	if revealedCues then
		for _, tag in ipairs(revealedCues) do
			local cue = StrangerDangerLogic.Cues[tag]
			if cue then
				local row = UIStyle.MakeLabel({
					Size = UDim2.new(1, 0, 0, 0),
					Text = "• " .. cue.ExplorerText,
					TextSize = 14,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				})
				row.AutomaticSize = Enum.AutomaticSize.Y
				row.LayoutOrder = #cueRows + 1
				row.Parent = cueListHolder
				cueRows[tag] = row
			end
		end
	end

	-- action buttons stacked at the bottom
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.Size = UDim2.new(1, 0, 0, 160)
	actions.Position = UDim2.new(0, 0, 1, -160)
	actions.BackgroundTransparency = 1
	actions.Parent = card

	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionsLayout.Padding = UDim.new(0, 8)
	actionsLayout.Parent = actions

	local approachBtn = makeActionButton(actions, "ApproachBtn", "APPROACH", UIStyle.Palette.Safe, 1)
	local askBtn = makeActionButton(actions, "AskBtn", "ASK BUDDY", UIStyle.Palette.AskFirst, 2)
	local avoidBtn = makeActionButton(actions, "AvoidBtn", "AVOID", UIStyle.Palette.Risky, 3)

	approachBtn.Activated:Connect(function()
		if not activeNpcId then return end
		playSfx("RoundStart")
		RemoteService.FireServer("RequestExplorerAction", activeNpcId, StrangerDangerLogic.Action.Approach)
	end)
	askBtn.Activated:Connect(function()
		if not activeNpcId then return end
		playSfx("ConfirmPair")
		RemoteService.FireServer("RequestExplorerAction", activeNpcId, StrangerDangerLogic.Action.AskFirst)
	end)
	avoidBtn.Activated:Connect(function()
		if not activeNpcId then return end
		playSfx("CorrectSort")
		RemoteService.FireServer("RequestExplorerAction", activeNpcId, StrangerDangerLogic.Action.Avoid)
	end)

	card:SetAttribute("BB_NpcId", npcId)
	task.delay(15, function()
		if card and card:GetAttribute("BB_NpcId") == npcId then
			clearCard()
		end
	end)
end

local function appendCueRow(tag: string)
	if not cuesContainer or cueRows[tag] then return end
	local cue = StrangerDangerLogic.Cues[tag]
	if not cue then return end
	local row = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 0),
		Text = "• " .. cue.ExplorerText,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	row.AutomaticSize = Enum.AutomaticSize.Y
	local count = 0
	for _ in pairs(cueRows) do count += 1 end
	row.LayoutOrder = count + 1
	row.Parent = cuesContainer
	cueRows[tag] = row
end

local function ringColorForMarker(marker: string?): Color3
	if marker == "Safe" then return UIStyle.Palette.Safe end
	if marker == "Risky" then return UIStyle.Palette.Risky end
	if marker == "AskFirst" then return UIStyle.Palette.AskFirst end
	return UIStyle.Palette.Highlight
end

local function clearRing(npcId: string)
	if rings[npcId] then
		rings[npcId]:Destroy()
		rings[npcId] = nil
	end
end

local function applyRing(npcId: string, marker: string)
	clearRing(npcId)
	if marker == "Clear" then return end
	local model = getNpcModel(npcId)
	if not model then return end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local ring = Instance.new("Part")
	ring.Name = "BB_AnnotationRing"
	ring.Anchored = false
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 8, 8)
	ring.Material = Enum.Material.Neon
	ring.Color = ringColorForMarker(marker)
	ring.Transparency = 0.2
	ring.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90)) + Vector3.new(0, -2.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring
	ring.Parent = model
	rings[npcId] = ring
end

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	currentRole = payload.Role or RoleTypes.None
end)

RemoteService.OnClientEvent("NpcDescriptionShown", function(payload)
	if currentRole ~= RoleTypes.Explorer then return end
	if payload.Audience ~= "Explorer" then return end
	showCard(payload.NpcId, payload.Archetype, payload.Silhouette, payload.RevealedCues)
end)

RemoteService.OnClientEvent("NpcCueRevealed", function(payload)
	if currentRole ~= RoleTypes.Explorer then return end
	if not card or activeNpcId ~= payload.NpcId then return end
	playSfx("ClueCollected")
	appendCueRow(payload.CueTag)
end)

RemoteService.OnClientEvent("NpcActionResolved", function(payload)
	if currentRole ~= RoleTypes.Explorer then return end
	if activeNpcId ~= payload.NpcId then return end
	if payload.Action == StrangerDangerLogic.Action.AskFirst then
		return
	end
	-- close the card on Approach or Avoid
	clearCard()
	if payload.Result == "RiskyConsequence" then
		playSfx("WrongSort")
	elseif payload.Result == "ClueGranted" then
		playSfx("ClueCollected")
	elseif payload.Result == "AvoidedSafely" then
		playSfx("CorrectSort")
	end
end)

RemoteService.OnClientEvent("NpcAnnotationUpdated", function(payload)
	applyRing(payload.NpcId, payload.Marker)
end)

RemoteService.OnClientEvent("LevelEnded", function(_payload)
	for npcId in pairs(rings) do clearRing(npcId) end
	clearCard()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	for npcId in pairs(rings) do clearRing(npcId) end
	clearCard()
end)
