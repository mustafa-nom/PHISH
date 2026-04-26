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
}

local cardRefs: { [string]: CardRefs } = {}
local activeShopGui: ScreenGui? = nil

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

	-- Content area: leave room at top for the banner overlap and a bit
	-- of breathing room around the edges.
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 18, 0, 50)
	content.Size = UDim2.new(1, -36, 1, -68)
	content.Parent = panel

	-- Sort: lower tiers go to grid, top tier becomes hero.
	local rods = {}
	for _, r in ipairs(RodCatalog.Rods) do table.insert(rods, r) end
	table.sort(rods, function(a, b) return a.tier < b.tier end)

	local heroRod = rods[#rods]
	local gridRods = {}
	for i = 1, #rods - 1 do table.insert(gridRods, rods[i]) end

	-- Hero column on the right.
	local heroCol = Instance.new("Frame")
	heroCol.Name = "HeroCol"
	heroCol.AnchorPoint = Vector2.new(1, 0)
	heroCol.Position = UDim2.new(1, 0, 0, 0)
	heroCol.Size = UDim2.new(0, 240, 1, 0)
	heroCol.BackgroundTransparency = 1
	heroCol.Parent = content
	buildHeroCard(heroCol, heroRod)

	-- Left grid.
	local gridCol = Instance.new("Frame")
	gridCol.Name = "GridCol"
	gridCol.Size = UDim2.new(1, -260, 1, 0)
	gridCol.BackgroundTransparency = 1
	gridCol.Parent = content

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0, 14)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = gridCol

	for i, rod in ipairs(gridRods) do
		local card = buildRodCard(gridCol, rod)
		card.LayoutOrder = i
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Escape and activeShopGui then closeShop() end
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
