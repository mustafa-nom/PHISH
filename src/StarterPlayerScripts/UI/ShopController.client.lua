--!strict
-- Fisherman shop UI. Listens for ProximityPrompt.Triggered on parts tagged
-- PhishShopTrigger with attribute ShopType="Powerup". Renders a row of
-- CardSlot tiles for tier 1-3 rods + a tall HeroSlot on the right for the
-- top-tier rod. The hero gets a colored radial glow behind its preview;
-- standard cards do not (matching the reference daily-reward UI).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CatcherCatalog = require(Modules:WaitForChild("CatcherCatalog"))
local GearCatalog = require(Modules:WaitForChild("GearCatalog"))
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RodCatalog = require(Modules:WaitForChild("RodCatalog"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local IconFactory = require(Modules:WaitForChild("IconFactory"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local localState = {
	coins = 0,
	rodTier = 1,
	ownedCatchers = {},
	deployedCatchers = {},
	ownedGear = {},
}

type CardRefs = {
	panel: Frame,
	stroke: UIStroke,
	buyBtn: TextButton,
	priceFrame: Frame,
	priceLabel: TextLabel,
}

local cardRefs: { [string]: CardRefs } = {}
local activeShopGui: ScreenGui? = nil
local activeRender: (() -> ())? = nil
local pendingDeploy: { kind: string, id: string }? = nil
local closeShop: () -> ()

-- Hero glow color per tier (used on the featured rod only).
local function tierGlowColor(tier: number): Color3
	if tier == 1 then return Color3.fromRGB(200, 140, 70) end
	if tier == 2 then return Color3.fromRGB(140, 220, 110) end
	if tier == 3 then return Color3.fromRGB(120, 180, 240) end
	if tier == 4 then return Color3.fromRGB(220, 80, 200) end
	return UIStyle.Palette.Legendary
end

local function findRodTemplate(rodId: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PhishRods")
	if not folder then return nil end
	local model = folder:FindFirstChild(rodId)
	if model and model:IsA("Model") then return model end
	return nil
end

-- Transparent ViewportFrame containing the rotating rod model. The
-- viewport is transparent so the dark card slot reads behind it.
local function buildRodPreview(rodId: string, parent: Instance, size: UDim2, position: UDim2): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "RodPreview"
	vf.Size = size
	vf.AnchorPoint = Vector2.new(0.5, 0.5)
	vf.Position = position
	vf.BackgroundTransparency = 1
	vf.BorderSizePixel = 0
	vf.LightDirection = Vector3.new(-0.5, -1, -0.3)
	vf.Ambient = Color3.fromRGB(170, 150, 130)
	vf.LightColor = Color3.fromRGB(255, 240, 200)
	vf.ZIndex = 5
	vf.Parent = parent

	local template = findRodTemplate(rodId)
	if not template then return vf end
	local clone = template:Clone()
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	clone.Parent = vf
	if clone.PrimaryPart then
		clone:PivotTo(CFrame.new(0, 0, 0))
	end

	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.CFrame = CFrame.new(Vector3.new(2.4, 1.2, 5), Vector3.new(0, 0.5, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam

	local startTime = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not vf.Parent then conn:Disconnect(); return end
		if not clone.PrimaryPart then return end
		local angle = (os.clock() - startTime) * 0.6
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, 0))
	end)
	return vf
end

local function refreshCard(rod: RodCatalog.Rod)
	local refs = cardRefs[rod.id]
	if not refs then return end
	local owned = rod.tier <= localState.rodTier
	local affordable = localState.coins >= rod.price
	if owned then
		refs.buyBtn.Text = "OWNED"
		refs.buyBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 54)
		refs.buyBtn.TextColor3 = Color3.fromRGB(220, 245, 220)
		refs.buyBtn.AutoButtonColor = false
		refs.priceFrame.Visible = false
		UIStyle.SetSelected(refs.panel, true)
	else
		refs.buyBtn.Text = "BUY"
		refs.buyBtn.BackgroundColor3 = affordable and UIStyle.Palette.Safe
			or Color3.fromRGB(50, 42, 50)
		refs.buyBtn.TextColor3 = affordable and Color3.fromRGB(20, 30, 20)
			or UIStyle.Palette.TextMuted
		refs.buyBtn.AutoButtonColor = affordable
		refs.priceFrame.Visible = true
		refs.priceLabel.Text = tostring(rod.price)
		UIStyle.SetSelected(refs.panel, false)
	end
end

local function refreshAll()
	for _, r in ipairs(RodCatalog.Rods) do refreshCard(r) end
	if activeRender then activeRender() end
end

-- Build a standard slot (tier 1-3 rods).
local function buildRodCard(parent: Instance, rod: RodCatalog.Rod): Frame
	local card = UIStyle.CardSlot({
		Name = rod.id,
		Size = UDim2.new(1 / 3, -8, 1, 0),
	})
	card.Parent = parent
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- Tier header in gold ("[Tier 1]"), top of card.
	UIStyle.MakeLabel({
		Name = "TierLabel",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 12),
		Text = string.format("[Tier %d]", rod.tier),
		Font = UIStyle.FontDisplay,
		TextSize = UIStyle.TextSize.Heading,
		TextColor3 = UIStyle.Palette.TitleGold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})

	-- Rod 3D preview, large, centered, sitting directly on the dark slot.
	buildRodPreview(rod.id, card,
		UDim2.fromOffset(150, 130),
		UDim2.new(0.5, 0, 0, 120))

	-- Rod name (cream/white).
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.new(0, 6, 1, -78),
		Text = rod.name,
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextPrimary,
		Parent = card,
	})

	-- Price row
	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceRow"
	priceFrame.Size = UDim2.new(1, -16, 0, 20)
	priceFrame.Position = UDim2.new(0, 8, 1, -56)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	local _, priceLabel = IconFactory.Pill(priceFrame, IconFactory.Coin(16),
		"", UIStyle.Palette.TitleGold, UIStyle.TextSize.Body)
	priceLabel.Font = UIStyle.FontBold

	-- BUY button — flat green, no extra gradient.
	local buyBtn = UIStyle.MakeButton({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 1, -36),
		Text = "BUY",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = UIStyle.Palette.Safe,
		TextColor3 = Color3.fromRGB(20, 30, 20),
		Parent = card,
	})
	UIStyle.ApplyStroke(buyBtn, Color3.fromRGB(20, 36, 24), 1)
	UIStyle.BindHover(buyBtn, 1.03)
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseRod", { rodId = rod.id })
	end)

	cardRefs[rod.id] = {
		panel = card, stroke = stroke, buyBtn = buyBtn,
		priceFrame = priceFrame, priceLabel = priceLabel,
	}
	refreshCard(rod)
	return card
end

-- Build the tall featured/hero slot for the top-tier rod. Has the radial
-- HeroGlow behind the rod preview (this is the only card with one).
local function buildHeroCard(parent: Instance, rod: RodCatalog.Rod): Frame
	local card = UIStyle.HeroSlot({
		Name = rod.id .. "_Hero",
		Size = UDim2.fromScale(1, 1),
	})
	card.Parent = parent
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- Tier label — gold like the reference's "[Day 7]".
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.fromOffset(8, 18),
		Text = string.format("[Tier %d]", rod.tier),
		Font = UIStyle.FontDisplay,
		TextSize = 28,
		TextColor3 = UIStyle.Palette.TitleGoldHero,
		Parent = card,
	})

	-- Radial colored glow behind the centerpiece.
	UIStyle.HeroGlow({
		Size = UDim2.fromOffset(180, 180),
		Position = UDim2.new(0.5, 0, 0, 160),
		Color = tierGlowColor(rod.tier),
		Parent = card,
	})
	-- Rod preview on top of the glow.
	buildRodPreview(rod.id, card,
		UDim2.fromOffset(170, 170),
		UDim2.new(0.5, 0, 0, 160))

	-- Big name, gold ("ASTRAL ROD" style).
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 264),
		Text = string.upper(rod.name),
		Font = UIStyle.FontDisplay,
		TextSize = 26,
		TextColor3 = UIStyle.Palette.TitleGoldHero,
		Parent = card,
	})

	-- Price row
	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceRow"
	priceFrame.Size = UDim2.new(1, -24, 0, 26)
	priceFrame.Position = UDim2.new(0, 12, 1, -78)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	local _, priceLabel = IconFactory.Pill(priceFrame, IconFactory.Coin(20),
		"", UIStyle.Palette.TitleGoldHero, UIStyle.TextSize.Heading)
	priceLabel.Font = UIStyle.FontBold

	-- "Claim"-style flat button (recessed dark, rounded).
	local buyBtn = UIStyle.MakeButton({
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0, 12, 1, -50),
		Text = "BUY",
		Font = UIStyle.FontDisplay,
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = Color3.fromRGB(40, 32, 44),
		TextColor3 = UIStyle.Palette.TextPrimary,
		Parent = card,
	})
	UIStyle.ApplyStroke(buyBtn, UIStyle.Palette.SlotStroke, 2)
	UIStyle.BindHover(buyBtn, 1.03)
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseRod", { rodId = rod.id })
	end)

	cardRefs[rod.id] = {
		panel = card, stroke = stroke, buyBtn = buyBtn,
		priceFrame = priceFrame, priceLabel = priceLabel,
	}
	refreshCard(rod)
	return card
end

local function deployedCatcherCount(catcherId: string): number
	local count = 0
	for _, deployment in pairs(localState.deployedCatchers :: any) do
		if type(deployment) == "table" and deployment.catcherId == catcherId then
			count += 1
		end
	end
	return count
end

local function makeSimplePreview(parent: Instance, color: Color3, labelText: string)
	local preview = Instance.new("Frame")
	preview.Size = UDim2.fromScale(1, 0.36)
	preview.BackgroundColor3 = color
	preview.BorderSizePixel = 0
	preview.Parent = parent
	UIStyle.ApplyCorner(preview, UDim.new(0, 12))

	UIStyle.MakeLabel({
		Size = UDim2.fromScale(1, 1),
		Text = labelText,
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Title,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = preview,
	})
end

local function buildCatcherCard(parent: Instance, catcher: CatcherCatalog.Catcher): Frame
	local card = UIStyle.MakePanel({
		Name = catcher.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIStyle.Palette.Panel,
		Parent = parent,
	})
	makeSimplePreview(card, Color3.fromRGB(80, 140, 180), "CATCHER")

	local owned = (localState.ownedCatchers :: any)[catcher.id] or 0
	local deployed = deployedCatcherCount(catcher.id)
	local available = math.max(0, owned - deployed)

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0.38, 4),
		Text = catcher.name,
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		Parent = card,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 52),
		Position = UDim2.new(0, 8, 0.38, 30),
		Text = catcher.description,
		TextWrapped = true,
		TextSize = UIStyle.TextSize.Caption,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 8, 1, -88),
		Text = string.format("Owned %d | Ready %d | Cap %d", owned, available, catcher.capacity),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = card,
	})

	local priceFrame = Instance.new("Frame")
	priceFrame.Size = UDim2.new(0.48, -10, 0, 26)
	priceFrame.Position = UDim2.new(0, 8, 1, -62)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	IconFactory.Pill(priceFrame, IconFactory.Coin(18), tostring(catcher.price), UIStyle.Palette.TextPrimary, UIStyle.TextSize.Body)

	local buyBtn = UIStyle.MakeButton({
		Size = UDim2.new(0.48, -8, 0, 30),
		Position = UDim2.new(0, 8, 1, -34),
		Text = "BUY",
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = (localState.coins >= catcher.price) and UIStyle.Palette.Safe or UIStyle.Palette.TextMuted,
		Parent = card,
	})
	buyBtn.AutoButtonColor = localState.coins >= catcher.price
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseCatcher", { catcherId = catcher.id })
	end)

	local deployBtn = UIStyle.MakeButton({
		Size = UDim2.new(0.48, -8, 0, 30),
		Position = UDim2.new(0.52, 0, 1, -34),
		Text = "DEPLOY",
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = available > 0 and UIStyle.Palette.Highlight or UIStyle.Palette.TextMuted,
		Parent = card,
	})
	deployBtn.AutoButtonColor = available > 0
	deployBtn.MouseButton1Click:Connect(function()
		if not deployBtn.AutoButtonColor then return end
		pendingDeploy = { kind = "Catcher", id = catcher.id }
		closeShop()
		UIBuilder.Toast("Click a water tile to deploy " .. catcher.name .. ".", 4, "Success")
	end)
	return card
end

local function buildGearCard(parent: Instance, gear: GearCatalog.Gear): Frame
	local card = UIStyle.MakePanel({
		Name = gear.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIStyle.Palette.Panel,
		Parent = parent,
	})
	makeSimplePreview(card, Color3.fromRGB(240, 178, 80), "GEAR")

	local owned = (localState.ownedGear :: any)[gear.id] or 0
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0.38, 4),
		Text = gear.name,
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		Parent = card,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 52),
		Position = UDim2.new(0, 8, 0.38, 30),
		Text = gear.description,
		TextWrapped = true,
		TextSize = UIStyle.TextSize.Caption,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 8, 1, -88),
		Text = string.format("Owned %d | Radius %d | %ds", owned, gear.radius, gear.durationSeconds),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = card,
	})

	local priceFrame = Instance.new("Frame")
	priceFrame.Size = UDim2.new(0.48, -10, 0, 26)
	priceFrame.Position = UDim2.new(0, 8, 1, -62)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	IconFactory.Pill(priceFrame, IconFactory.Coin(18), tostring(gear.price), UIStyle.Palette.TextPrimary, UIStyle.TextSize.Body)

	local buyBtn = UIStyle.MakeButton({
		Size = UDim2.new(0.48, -8, 0, 30),
		Position = UDim2.new(0, 8, 1, -34),
		Text = "BUY",
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = (localState.coins >= gear.price) and UIStyle.Palette.Safe or UIStyle.Palette.TextMuted,
		Parent = card,
	})
	buyBtn.AutoButtonColor = localState.coins >= gear.price
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseGear", { gearId = gear.id })
	end)

	local deployBtn = UIStyle.MakeButton({
		Size = UDim2.new(0.48, -8, 0, 30),
		Position = UDim2.new(0.52, 0, 1, -34),
		Text = "DEPLOY",
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = owned > 0 and UIStyle.Palette.Highlight or UIStyle.Palette.TextMuted,
		Parent = card,
	})
	deployBtn.AutoButtonColor = owned > 0
	deployBtn.MouseButton1Click:Connect(function()
		if not deployBtn.AutoButtonColor then return end
		pendingDeploy = { kind = "Gear", id = gear.id }
		closeShop()
		UIBuilder.Toast("Click a water tile to deploy " .. gear.name .. ".", 4, "Success")
	end)
	return card
end

closeShop = function()
	if activeShopGui then activeShopGui:Destroy(); activeShopGui = nil end
	cardRefs = {}
	activeRender = nil
end

local function openShop()
	closeShop()
	local screen = UIBuilder.GetScreenGui()
	local shopGui = Instance.new("ScreenGui")
	shopGui.Name = "PhishShopGui"
	shopGui.ResetOnSpawn = false
	shopGui.IgnoreGuiInset = true
	shopGui.DisplayOrder = 30
	shopGui.Parent = screen.Parent
	activeShopGui = shopGui

	-- Dim background. Click outside the panel to close.
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = shopGui
	dim.MouseButton1Click:Connect(closeShop)

	-- Main panel — semi-transparent dark glass.
	local panel = UIStyle.MakePanel({
		Name = "ShopPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(880, 500),
		BackgroundColor3 = UIStyle.Palette.Panel,
		Parent = shopGui,
	})

	-- Banner title — rectangular cream/orange, overhangs the top edge.
	UIStyle.BannerTitle({
		Width = 380,
		Height = 64,
		Position = UDim2.new(0.5, 0, 0, -34),
		Text = "Fisherman's Wares",
		TextSize = 30,
		Parent = panel,
	})

	-- Close button — small dark, top-right corner.
	local closeBtn = UIStyle.MakeButton({
		Name = "CloseBtn",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -12, 0, 12),
		Text = "X",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = Color3.fromRGB(40, 30, 40),
		TextColor3 = UIStyle.Palette.TextPrimary,
		Parent = panel,
	})
	UIStyle.ApplyStroke(closeBtn, UIStyle.Palette.SlotStroke, 2)
	UIStyle.BindHover(closeBtn, 1.06)
	closeBtn.MouseButton1Click:Connect(closeShop)

	local currentTab = "Rods"
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.Size = UDim2.new(1, -120, 0, 34)
	tabRow.Position = UDim2.fromOffset(16, 62)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRow

	-- Content area. Rods use the polished hero layout; catchers and gear use
	-- a scrollable grid inside this frame.
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 16, 0, 104)
	content.Size = UDim2.new(1, -32, 1, -124)
	content.Parent = panel

	-- Sort: lower tiers go to grid, top tier becomes hero.
	local rods = {}
	for _, r in ipairs(RodCatalog.Rods) do table.insert(rods, r) end
	table.sort(rods, function(a, b) return a.tier < b.tier end)

	local tabButtons: { [string]: TextButton } = {}
	local function clearContent()
		cardRefs = {}
		for _, child in ipairs(content:GetChildren()) do
			child:Destroy()
		end
	end

	local function renderRods()
		local heroRod = rods[#rods]
		local gridRods = {}
		for i = 1, #rods - 1 do table.insert(gridRods, rods[i]) end

		local heroCol = Instance.new("Frame")
		heroCol.Name = "HeroCol"
		heroCol.AnchorPoint = Vector2.new(1, 0)
		heroCol.Position = UDim2.new(1, 0, 0, 0)
		heroCol.Size = UDim2.new(0, 260, 1, 0)
		heroCol.BackgroundTransparency = 1
		heroCol.Parent = content
		buildHeroCard(heroCol, heroRod)

		local gridCol = Instance.new("Frame")
		gridCol.Name = "GridCol"
		gridCol.Size = UDim2.new(1, -276, 1, 0)
		gridCol.BackgroundTransparency = 1
		gridCol.Parent = content

		local listLayout = Instance.new("UIListLayout")
		listLayout.FillDirection = Enum.FillDirection.Horizontal
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.Padding = UDim.new(0, 12)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = gridCol

		for i, rod in ipairs(gridRods) do
			local card = buildRodCard(gridCol, rod)
			card.LayoutOrder = i
		end
	end

	local function renderGrid()
		local row = Instance.new("ScrollingFrame")
		row.Name = "Cards"
		row.Size = UDim2.fromScale(1, 1)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.ScrollBarThickness = 6
		row.ScrollBarImageColor3 = UIStyle.Palette.PanelStroke
		row.ScrollingDirection = Enum.ScrollingDirection.Y
		row.AutomaticCanvasSize = Enum.AutomaticSize.Y
		row.CanvasSize = UDim2.new(0, 0, 0, 0)
		row.Parent = content

		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(200, 280)
		grid.CellPadding = UDim2.fromOffset(12, 12)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.VerticalAlignment = Enum.VerticalAlignment.Top
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = row

		if currentTab == "Catchers" then
			for i, catcher in ipairs(CatcherCatalog.Catchers) do
				local card = buildCatcherCard(row, catcher)
				card.LayoutOrder = i
			end
		else
			for i, gear in ipairs(GearCatalog.Gear) do
				local card = buildGearCard(row, gear)
				card.LayoutOrder = i
			end
		end
	end

	local function renderTab()
		clearContent()
		for name, button in pairs(tabButtons) do
			button.BackgroundColor3 = (name == currentTab) and UIStyle.Palette.AskFirst or UIStyle.Palette.Panel
		end
		if currentTab == "Rods" then
			renderRods()
		else
			renderGrid()
		end
	end

	for i, name in ipairs({ "Rods", "Catchers", "Gear" }) do
		local tab = UIStyle.MakeButton({
			Name = name .. "Tab",
			Size = UDim2.fromOffset(112, 30),
			Text = name,
			TextSize = UIStyle.TextSize.Body,
			BackgroundColor3 = (name == currentTab) and UIStyle.Palette.AskFirst or UIStyle.Palette.Panel,
			Parent = tabRow,
		})
		tab.LayoutOrder = i
		tabButtons[name] = tab
		tab.MouseButton1Click:Connect(function()
			currentTab = name
			renderTab()
		end)
	end
	activeRender = renderTab
	renderTab()
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if pendingDeploy and input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = mouse.Hit.Position
		if pendingDeploy.kind == "Catcher" then
			RemoteService.FireServer("RequestDeployCatcher", { catcherId = pendingDeploy.id, target = target })
		else
			RemoteService.FireServer("RequestDeployGear", { gearId = pendingDeploy.id, target = target })
		end
		pendingDeploy = nil
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and activeShopGui then closeShop() end
	if input.KeyCode == Enum.KeyCode.Escape and pendingDeploy then
		pendingDeploy = nil
		UIBuilder.Toast("Deployment cancelled.", 2, "Error")
	end
end)

local function bindTrigger(part: Instance)
	if not part:IsA("BasePart") then return end
	if part:GetAttribute("ShopType") ~= "Powerup" then return end
	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(p)
		if p ~= player then return end
		openShop()
	end)
end

for _, t in ipairs(CollectionService:GetTagged(PhishConstants.Tags.ShopTrigger)) do
	bindTrigger(t)
end
CollectionService:GetInstanceAddedSignal(PhishConstants.Tags.ShopTrigger):Connect(bindTrigger)

local function applySnapshot(snap: any)
	if type(snap) ~= "table" then return end
	if snap.coins ~= nil then localState.coins = snap.coins end
	if snap.rodTier ~= nil then localState.rodTier = snap.rodTier end
	if snap.ownedCatchers ~= nil then localState.ownedCatchers = snap.ownedCatchers end
	if snap.deployedCatchers ~= nil then localState.deployedCatchers = snap.deployedCatchers end
	if snap.ownedGear ~= nil then localState.ownedGear = snap.ownedGear end
	if activeShopGui then refreshAll() end
end
RemoteService.OnClientEvent("HudUpdated", applySnapshot)
task.spawn(function()
	local ok, snap = pcall(function() return RemoteService.InvokeServer("GetPlayerSnapshot") end)
	if ok then applySnapshot(snap) end
end)

RemoteService.OnClientEvent("PurchaseResult", function(payload)
	if type(payload) ~= "table" then return end
	if payload.newCoins ~= nil then localState.coins = payload.newCoins end
	if payload.newRodTier ~= nil then localState.rodTier = payload.newRodTier end
	if activeShopGui then refreshAll() end
	UIBuilder.Toast(payload.message or "", 3, payload.ok and "Success" or "Error")
end)

RemoteService.OnClientEvent("CatcherUpdated", function(payload)
	if type(payload) ~= "table" then return end
	if payload.ownedCatchers ~= nil then localState.ownedCatchers = payload.ownedCatchers end
	if payload.deployedCatchers ~= nil then localState.deployedCatchers = payload.deployedCatchers end
	if activeShopGui then refreshAll() end
end)

RemoteService.OnClientEvent("GearUpdated", function(payload)
	if type(payload) ~= "table" then return end
	if payload.ownedGear ~= nil then localState.ownedGear = payload.ownedGear end
	if activeShopGui then refreshAll() end
end)
