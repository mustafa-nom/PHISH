--!strict
-- Fisherman shop UI. Listens for ProximityPrompt.Triggered on parts tagged
-- PhishShopTrigger with attribute ShopType="Powerup". Renders a row of
-- CardSlot tiles for tier 1-3 rods + a tall HeroSlot on the right for the
-- top-tier rod. BUY fires RequestPurchaseRod; PurchaseResult updates state.

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
	tierLabel: TextLabel,
	statusLabel: TextLabel?,
}

local cardRefs: { [string]: CardRefs } = {}
local activeShopGui: ScreenGui? = nil
local activeRender: (() -> ())? = nil
local pendingDeploy: { kind: string, id: string }? = nil
local closeShop: () -> ()

local function findRodTemplate(rodId: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PhishRods")
	if not folder then return nil end
	local model = folder:FindFirstChild(rodId)
	if model and model:IsA("Model") then return model end
	return nil
end

-- Build a 3D preview of the rod inside a ViewportFrame.
local function buildRodPreview(rodId: string, parent: Instance, size: UDim2): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "RodPreview"
	vf.Size = size
	vf.AnchorPoint = Vector2.new(0.5, 0)
	vf.Position = UDim2.new(0.5, 0, 0, 8)
	vf.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
	vf.BorderSizePixel = 0
	vf.LightDirection = Vector3.new(-0.5, -1, -0.3)
	vf.Ambient = Color3.fromRGB(150, 130, 110)
	vf.LightColor = Color3.fromRGB(255, 230, 180)
	vf.Parent = parent
	UIStyle.ApplyCorner(vf, UDim.new(0, 10))
	UIStyle.ApplyStroke(vf, UIStyle.Palette.SlotStroke, 1)
	UIStyle.ApplyGradient(vf,
		Color3.fromRGB(40, 32, 50),
		Color3.fromRGB(14, 10, 18),
		90
	)

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
		refs.buyBtn.BackgroundColor3 = Color3.fromRGB(80, 110, 80)
		refs.buyBtn.TextColor3 = Color3.fromRGB(220, 245, 220)
		refs.buyBtn.AutoButtonColor = false
		refs.priceFrame.Visible = false
		refs.stroke.Color = UIStyle.Palette.Safe
		refs.stroke.Thickness = 2
		refs.stroke.Transparency = 0.15
	else
		refs.buyBtn.Text = "BUY"
		refs.buyBtn.BackgroundColor3 = affordable and UIStyle.Palette.Safe
			or Color3.fromRGB(70, 60, 70)
		refs.buyBtn.TextColor3 = affordable and Color3.fromRGB(20, 30, 20)
			or UIStyle.Palette.TextMuted
		refs.buyBtn.AutoButtonColor = affordable
		refs.priceFrame.Visible = true
		refs.priceLabel.Text = tostring(rod.price)
		refs.stroke.Color = UIStyle.Palette.SlotStroke
		refs.stroke.Thickness = 1
		refs.stroke.Transparency = 0
	end
end

local function refreshAll()
	for _, r in ipairs(RodCatalog.Rods) do refreshCard(r) end
	if activeRender then activeRender() end
end

-- Build a standard slot (used for tier 1-3 rods).
local function buildRodCard(parent: Instance, rod: RodCatalog.Rod): Frame
	local card = UIStyle.CardSlot({
		Name = rod.id,
		Size = UDim2.new(1 / 3, -8, 1, 0),
	})
	card.Parent = parent
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- Tier header in gold ("[Tier 1]" style)
	local tierLabel = UIStyle.MakeLabel({
		Name = "TierLabel",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 8),
		Text = string.format("[Tier %d]", rod.tier),
		Font = UIStyle.FontDisplay,
		TextSize = UIStyle.TextSize.Heading,
		TextColor3 = UIStyle.Palette.TitleGold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})

	-- Rod 3D preview (centered upper portion).
	buildRodPreview(rod.id, card, UDim2.new(1, -24, 0.45, 0))
	-- Move preview down below tier label.
	local preview = card:FindFirstChild("RodPreview") :: ViewportFrame
	preview.Position = UDim2.new(0.5, 0, 0, 36)

	-- Name
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0.55, 6),
		Text = rod.name,
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextPrimary,
		Parent = card,
	})

	-- Description
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 0.55, 30),
		Text = rod.description,
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})

	-- Price row
	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceRow"
	priceFrame.Size = UDim2.new(1, -16, 0, 22)
	priceFrame.Position = UDim2.new(0, 8, 1, -64)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	local _, priceLabel = IconFactory.Pill(priceFrame, IconFactory.Coin(18),
		"", UIStyle.Palette.TextPrimary, UIStyle.TextSize.Body)
	priceLabel.TextColor3 = UIStyle.Palette.TitleGold
	priceLabel.Font = UIStyle.FontBold

	-- BUY button
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
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseRod", { rodId = rod.id })
	end)

	cardRefs[rod.id] = {
		panel = card, stroke = stroke, buyBtn = buyBtn,
		priceFrame = priceFrame, priceLabel = priceLabel,
		tierLabel = tierLabel,
	}
	refreshCard(rod)
	return card
end

-- Build the tall featured/hero slot for the top-tier rod.
local function buildHeroCard(parent: Instance, rod: RodCatalog.Rod): Frame
	local card = UIStyle.HeroSlot({
		Name = rod.id .. "_Hero",
		Size = UDim2.fromScale(1, 1),
	})
	card.Parent = parent
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- Tier label
	local tierLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 12),
		Text = string.format("[Tier %d]", rod.tier),
		Font = UIStyle.FontDisplay,
		TextSize = 26,
		TextColor3 = UIStyle.Palette.TitleGoldHero,
		Parent = card,
	})
	UIStyle.ApplyStroke(tierLabel, Color3.fromRGB(80, 40, 10), 1)

	-- Larger rod preview
	buildRodPreview(rod.id, card, UDim2.new(1, -32, 0, 220))
	local preview = card:FindFirstChild("RodPreview") :: ViewportFrame
	preview.Position = UDim2.new(0.5, 0, 0, 48)

	-- Big name
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 280),
		Text = string.upper(rod.name),
		Font = UIStyle.FontDisplay,
		TextSize = 26,
		TextColor3 = UIStyle.Palette.TitleGoldHero,
		Parent = card,
	})

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.new(0, 12, 0, 318),
		Text = rod.description,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextPrimary,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})

	-- Price
	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceRow"
	priceFrame.Size = UDim2.new(1, -24, 0, 28)
	priceFrame.Position = UDim2.new(0, 12, 1, -82)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	local _, priceLabel = IconFactory.Pill(priceFrame, IconFactory.Coin(22),
		"", UIStyle.Palette.TextPrimary, UIStyle.TextSize.Heading)
	priceLabel.TextColor3 = UIStyle.Palette.TitleGoldHero
	priceLabel.Font = UIStyle.FontBold

	local buyBtn = UIStyle.MakeButton({
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0, 12, 1, -50),
		Text = "BUY",
		Font = UIStyle.FontDisplay,
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Legendary,
		TextColor3 = Color3.fromRGB(50, 28, 8),
		Parent = card,
	})
	UIStyle.ApplyStroke(buyBtn, Color3.fromRGB(120, 70, 20), 2)
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseRod", { rodId = rod.id })
	end)

	cardRefs[rod.id] = {
		panel = card, stroke = stroke, buyBtn = buyBtn,
		priceFrame = priceFrame, priceLabel = priceLabel,
		tierLabel = tierLabel,
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
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = shopGui
	dim.MouseButton1Click:Connect(closeShop)

	-- Main panel
	local panel = UIStyle.MakePanel({
		Name = "ShopPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.74),
		BackgroundColor3 = UIStyle.Palette.Panel,
		Parent = shopGui,
	})
	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MinSize = Vector2.new(720, 460)
	panelConstraint.MaxSize = Vector2.new(960, 560)
	panelConstraint.Parent = panel

	-- Cream banner title sticking up from the panel top edge.
	UIStyle.BannerTitle({
		Width = 360,
		Height = 56,
		Position = UDim2.new(0.5, 0, 0, -28),
		Text = "FISHERMAN'S WARES",
		TextSize = 26,
		Parent = panel,
	})

	-- Close button — circle, top right.
	local closeBtn = UIStyle.MakeButton({
		Name = "CloseBtn",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -12, 0, 12),
		Text = "X",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Risky,
		TextColor3 = Color3.fromRGB(255, 245, 240),
		Parent = panel,
	})
	UIStyle.ApplyCorner(closeBtn, UDim.new(1, 0))
	UIStyle.ApplyStroke(closeBtn, Color3.fromRGB(140, 50, 50), 2)
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

-- Esc closes the shop too.
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

-- Bind ProximityPrompt.Triggered on every shop trigger tagged Powerup.
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

-- Track local coins / rodTier from HUD updates so card affordability stays current.
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

-- React to purchase results.
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
