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
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RodCatalog = require(Modules:WaitForChild("RodCatalog"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local IconFactory = require(Modules:WaitForChild("IconFactory"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer

local localState = { coins = 0, rodTier = 1 }

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

local function closeShop()
	if activeShopGui then activeShopGui:Destroy(); activeShopGui = nil end
	cardRefs = {}
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

	-- Content area: left grid (3 cards) + right hero column.
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 16, 0, 56)
	content.Size = UDim2.new(1, -32, 1, -76)
	content.Parent = panel

	-- Sort: lower tiers go to grid, top tier becomes hero.
	local rods = {}
	for _, r in ipairs(RodCatalog.Rods) do table.insert(rods, r) end
	table.sort(rods, function(a, b) return a.tier < b.tier end)

	local heroRod = rods[#rods]
	local gridRods = {}
	for i = 1, #rods - 1 do table.insert(gridRods, rods[i]) end

	-- Hero column on the right
	local heroCol = Instance.new("Frame")
	heroCol.Name = "HeroCol"
	heroCol.AnchorPoint = Vector2.new(1, 0)
	heroCol.Position = UDim2.new(1, 0, 0, 0)
	heroCol.Size = UDim2.new(0, 260, 1, 0)
	heroCol.BackgroundTransparency = 1
	heroCol.Parent = content
	buildHeroCard(heroCol, heroRod)

	-- Left grid
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

-- Esc closes the shop too.
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Escape and activeShopGui then closeShop() end
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
