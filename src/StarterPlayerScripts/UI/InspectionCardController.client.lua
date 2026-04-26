--!strict
-- Renders the inspection card on ShowInspectionCard. Two big buttons: KEEP
-- (legit) and CUT BAIT (phish). Submitting fires SubmitDecision; the card
-- stays up briefly after submit so the result panel can take over.
--
-- Layout is scale-based + anchored so the buttons stay glued to the bottom
-- edge of the card on any screen aspect ratio. Body content scrolls if the
-- email is longer than the visible area.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()
local guiParent = screen.Parent  -- PlayerGui — the card lives here, not in PhishUI

-- Hide Satchel's hotbar while the inspection card is up so its slots
-- can't overlap KEEP / CUT BAIT and intercept clicks. The CoreGui
-- Backpack is permanently disabled by Satchel; toggling it would just
-- re-enable the default hotbar on top of Satchel.
local function setBackpackHidden(hidden: boolean)
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local sg = pg and pg:FindFirstChild("BackpackGui")
	if sg and sg:IsA("ScreenGui") then
		sg.Enabled = not hidden
	end
end

local function clearOld()
	local old = guiParent and guiParent:FindFirstChild("PhishInspectionCard")
	if old then old:Destroy() end
end

local function colorAvatar(color: Color3?): Color3
	return color or Color3.fromRGB(120, 120, 120)
end

local function avatarImage(sender: any): string?
	if type(sender) ~= "table" or type(sender.avatarImage) ~= "string" or sender.avatarImage == "" then
		return nil
	end
	return sender.avatarImage
end

local CARD_WIDTH_FRACTION = 0.46     -- of screen width
local CARD_HEIGHT_FRACTION = 0.78    -- of screen height
local CARD_MIN_WIDTH = 460
local CARD_MIN_HEIGHT = 460

local function renderCard(card: any)
	clearOld()
	if type(card) ~= "table" then return end

	-- Use a dedicated ScreenGui above the regular HUD so nothing can cover it.
	local cardGui = Instance.new("ScreenGui")
	cardGui.Name = "PhishInspectionCard"
	cardGui.ResetOnSpawn = false
	cardGui.IgnoreGuiInset = true
	cardGui.DisplayOrder = 50
	cardGui.Parent = screen.Parent
	setBackpackHidden(true)

	local panel = UIStyle.MakePanel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(CARD_WIDTH_FRACTION, CARD_HEIGHT_FRACTION),
		BackgroundColor3 = UIStyle.Palette.Background,
	})
	-- Clamp to a sensible minimum so the card stays usable on small screens.
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
	sizeConstraint.MaxSize = Vector2.new(640, 720)
	sizeConstraint.Parent = panel
	panel.Parent = cardGui

	local flagMode = false
	local selectedFlags: { [string]: boolean } = {}
	local flagTargets: { [string]: GuiObject } = {}
	local flagHitboxes: { TextButton } = {}
	local flagToggle: TextButton? = nil
	local flagTip: TextLabel? = nil

	local function selectedFlagCount(): number
		local count = 0
		for _, selected in pairs(selectedFlags) do
			if selected then count += 1 end
		end
		return count
	end

	local function selectedFlagList(): { string }
		local flags = {}
		for elementId, selected in pairs(selectedFlags) do
			if selected then table.insert(flags, elementId) end
		end
		table.sort(flags)
		return flags
	end

	local function refreshFlagMarker(elementId: string)
		local target = flagTargets[elementId]
		if not target then return end

		local existingMarker = target:FindFirstChild("FlagMarker")
		local existingStroke = target:FindFirstChild("FlagStroke")
		if not selectedFlags[elementId] then
			if existingMarker then existingMarker:Destroy() end
			if existingStroke then existingStroke:Destroy() end
			return
		end

		if not existingStroke then
			local stroke = Instance.new("UIStroke")
			stroke.Name = "FlagStroke"
			stroke.Color = UIStyle.Palette.Risky
			stroke.Thickness = 3
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = target
		end

		if not existingMarker then
			local marker = Instance.new("TextLabel")
			marker.Name = "FlagMarker"
			marker.AnchorPoint = Vector2.new(1, 0)
			marker.Position = UDim2.new(1, -4, 0, 4)
			marker.Size = UDim2.fromOffset(58, 18)
			marker.BackgroundColor3 = UIStyle.Palette.Risky
			marker.BorderSizePixel = 0
			marker.Font = UIStyle.FontBold
			marker.Text = "FLAG"
			marker.TextSize = 12
			marker.TextColor3 = Color3.new(1, 1, 1)
			marker.ZIndex = target.ZIndex + 2
			marker.Parent = target
			UIStyle.ApplyCorner(marker, UDim.new(0, 6))
		end
	end

	local function updateFlagControls()
		local count = selectedFlagCount()
		if flagToggle then
			flagToggle.Text = flagMode and ("FLAGS ON\n%d SET"):format(count) or "RED\nFLAGS"
			flagToggle.BackgroundColor3 = flagMode and UIStyle.Palette.Risky or UIStyle.Palette.Accent
		end
		if flagTip then
			flagTip.Visible = flagMode
		end
		for _, hitbox in ipairs(flagHitboxes) do
			hitbox.Visible = flagMode
		end
	end

	local function addFlagTarget(target: GuiObject, elementId: string)
		flagTargets[elementId] = target
		target.Active = true

		local hitbox = Instance.new("TextButton")
		hitbox.Name = "FlagHitbox"
		hitbox.Size = UDim2.fromScale(1, 1)
		hitbox.BackgroundTransparency = 1
		hitbox.BorderSizePixel = 0
		hitbox.Text = ""
		hitbox.AutoButtonColor = false
		hitbox.Visible = false
		hitbox.ZIndex = target.ZIndex + 3
		hitbox.Parent = target
		table.insert(flagHitboxes, hitbox)

		hitbox.MouseButton1Click:Connect(function()
			if not flagMode then return end
			selectedFlags[elementId] = not selectedFlags[elementId] or nil
			refreshFlagMarker(elementId)
			updateFlagControls()
		end)
	end

	local flagRail = Instance.new("Frame")
	flagRail.Name = "FlagRail"
	flagRail.AnchorPoint = Vector2.new(0, 0.5)
	flagRail.Position = UDim2.new(1, 12, 0.5, 0)
	flagRail.Size = UDim2.fromOffset(124, 190)
	flagRail.BackgroundTransparency = 1
	flagRail.Parent = panel

	local flagToggleButton = UIStyle.MakeButton({
		Name = "FlagToggle",
		Size = UDim2.fromOffset(112, 68),
		Position = UDim2.fromOffset(6, 0),
		Text = "RED\nFLAGS",
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = UIStyle.Palette.Accent,
		Parent = flagRail,
	})
	flagToggle = flagToggleButton
	flagToggleButton.TextWrapped = true
	flagToggleButton.MouseButton1Click:Connect(function()
		flagMode = not flagMode
		updateFlagControls()
	end)

	local flagTipLabel = UIStyle.MakeLabel({
		Name = "FlagTip",
		Size = UDim2.new(1, 0, 0, 104),
		Position = UDim2.fromOffset(0, 80),
		Text = "Tap suspicious sender, subject, body, or link spots. Tap again to remove a flag.",
		TextSize = UIStyle.TextSize.Caption,
		TextWrapped = true,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = flagRail,
	})
	flagTip = flagTipLabel
	flagTipLabel.Visible = false

	-- Header row: avatar + sender name + sender address.
	local senderRow = Instance.new("Frame")
	senderRow.Name = "Sender"
	senderRow.Size = UDim2.new(1, -32, 0, 56)
	senderRow.Position = UDim2.fromOffset(16, 12)
	senderRow.BackgroundTransparency = 1
	senderRow.Parent = panel

	local avatar = Instance.new("Frame")
	avatar.Size = UDim2.fromOffset(48, 48)
	avatar.Position = UDim2.fromOffset(0, 4)
	avatar.BackgroundColor3 = colorAvatar(card.sender and card.sender.avatarColor)
	avatar.BorderSizePixel = 0
	avatar.ClipsDescendants = true
	avatar.Parent = senderRow
	UIStyle.ApplyCorner(avatar, UDim.new(1, 0))

	local image = avatarImage(card.sender)
	if image then
		local avatarIcon = Instance.new("ImageLabel")
		avatarIcon.Name = "AvatarImage"
		avatarIcon.Size = UDim2.fromScale(1, 1)
		avatarIcon.BackgroundTransparency = 1
		avatarIcon.Image = image
		avatarIcon.ScaleType = Enum.ScaleType.Crop
		avatarIcon.Parent = avatar
		UIStyle.ApplyCorner(avatarIcon, UDim.new(1, 0))
	end

	local senderName = UIStyle.MakeLabel({
		Size = UDim2.new(1, -64, 0, 24),
		Position = UDim2.fromOffset(64, 0),
		Text = (card.sender and card.sender.name) or "(unknown)",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	senderName.Parent = senderRow

	local senderAddr = UIStyle.MakeLabel({
		Size = UDim2.new(1, -64, 0, 18),
		Position = UDim2.fromOffset(64, 26),
		Text = (card.sender and card.sender.address) or "",
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	senderAddr.Parent = senderRow
	addFlagTarget(senderAddr, "sender.address")

	-- Subject below the header.
	local subjectLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, -32, 0, 32),
		Position = UDim2.fromOffset(16, 76),
		Text = card.subject or "",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	subjectLabel.Parent = panel
	addFlagTarget(subjectLabel, "subject")

	-- Scrollable body + links. Bottom is reserved for the decision buttons
	-- via the AnchorPoint trick below.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "BodyScroll"
	scroll.AnchorPoint = Vector2.new(0, 0)
	scroll.Position = UDim2.new(0, 16, 0, 116)
	scroll.Size = UDim2.new(1, -32, 1, -116 - 96)   -- leave 96px at bottom for buttons
	scroll.BackgroundColor3 = UIStyle.Palette.Panel
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	UIStyle.ApplyCorner(scroll, UDim.new(0, 12))

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = scroll

	local bodyLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 0),     -- height grows with AutomaticSize
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = card.body or "",
		Font = Enum.Font.RobotoMono,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LayoutOrder = 1,
	})
	bodyLabel.Parent = scroll
	addFlagTarget(bodyLabel, "body")

	if card.links and #card.links > 0 then
		for i, link in ipairs(card.links) do
			local linkPanel = UIStyle.MakePanel({
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = UIStyle.Palette.Highlight,
				LayoutOrder = 1 + i,
			})
			linkPanel.Parent = scroll
			local linkLabel = UIStyle.MakeLabel({
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				Text = string.format("link: %s  →  %s", link.displayText or "(link)", link.trueUrl or ""),
				TextSize = UIStyle.TextSize.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = false,
			})
			linkLabel.Parent = linkPanel
			addFlagTarget(linkPanel, string.format("links[%d]", i))
		end
	end

	-- Decision buttons — anchored to the bottom edge of the card so they're
	-- always visible regardless of body length.
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.AnchorPoint = Vector2.new(0.5, 1)
	buttonRow.Position = UDim2.new(0.5, 0, 1, -16)
	buttonRow.Size = UDim2.new(1, -32, 0, 64)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = panel

	local function submit(decision: string, btn: TextButton, twin: TextButton)
		btn.Active = false
		btn.AutoButtonColor = false
		btn.Text = "..."
		twin.Active = false
		RemoteService.FireServer("SubmitDecision", { decision = decision, flags = selectedFlagList() })
	end

	local keepBtn = UIStyle.MakeButton({
		Name = "KeepBtn",
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.fromScale(0, 0),
		Text = "KEEP",
		TextSize = UIStyle.TextSize.Title,
		BackgroundColor3 = UIStyle.Palette.Safe,
	})
	keepBtn.Parent = buttonRow

	local cutBtn = UIStyle.MakeButton({
		Name = "CutBtn",
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.new(0.5, 8, 0, 0),
		Text = "CUT BAIT",
		TextSize = UIStyle.TextSize.Title,
		BackgroundColor3 = UIStyle.Palette.Risky,
	})
	cutBtn.Parent = buttonRow

	keepBtn.MouseButton1Click:Connect(function() submit("KEEP", keepBtn, cutBtn) end)
	cutBtn.MouseButton1Click:Connect(function() submit("CUT_BAIT", cutBtn, keepBtn) end)

	print("[PHISH] Inspection card opened:", card.cardId or "(no id)")
end

RemoteService.OnClientEvent("ShowInspectionCard", renderCard)

-- When result lands, the result panel takes over; clear the card so the
-- screen isn't double-stacked, and bring the rod hotbar back so the player
-- can cast again.
RemoteService.OnClientEvent("DecisionResult", function()
	task.delay(0.2, function()
		clearOld()
		setBackpackHidden(false)
	end)
end)

-- Defensive: if the player respawns mid-inspection, restore the hotbar so
-- they aren't stuck without a rod tray.
local localPlayer = Players.LocalPlayer
localPlayer.CharacterAdded:Connect(function()
	setBackpackHidden(false)
end)
