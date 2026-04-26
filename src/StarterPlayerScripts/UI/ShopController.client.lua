--!strict
-- Fisherman shop UI. Listens for ProximityPrompt.Triggered on parts tagged
-- PhishShopTrigger with attribute ShopType="Powerup". Renders one card per rod
-- in RodCatalog with a ViewportFrame preview of the rod model. BUY fires
-- RequestPurchaseRod; PurchaseResult updates the cards.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RodCatalog = require(Modules:WaitForChild("RodCatalog"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local IconFactory = require(Modules:WaitForChild("IconFactory"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer

local localState = { coins = 0, rodTier = 1 }

local cardRefs: { [string]: { panel: Frame, buyBtn: TextButton, priceFrame: Frame, priceLabel: TextLabel } } = {}
local activeShopGui: ScreenGui? = nil

local function findRodTemplate(rodId: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PhishRods")
	if not folder then return nil end
	local model = folder:FindFirstChild(rodId)
	if model and model:IsA("Model") then return model end
	return nil
end

-- Make a 3D preview of the rod inside a ViewportFrame. Spawns a clone of the
-- rod template, parents it to the viewport, sets up a Camera looking at it,
-- and slowly rotates the rod for visual interest.
local function buildRodPreview(rodId: string, parent: Instance): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "RodPreview"
	vf.Size = UDim2.fromScale(1, 0.55)
	vf.Position = UDim2.fromScale(0, 0)
	vf.BackgroundColor3 = Color3.fromRGB(28, 22, 18)
	vf.BorderSizePixel = 0
	vf.LightDirection = Vector3.new(-0.5, -1, -0.3)
	vf.Ambient = Color3.fromRGB(180, 150, 120)
	vf.LightColor = Color3.fromRGB(255, 230, 180)
	vf.Parent = parent
	UIStyle.ApplyCorner(vf, UDim.new(0, 12))

	local template = findRodTemplate(rodId)
	if not template then return vf end
	local clone = template:Clone()
	-- Anchor + reparent into the viewport. Viewport instances ignore physics.
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	clone.Parent = vf
	-- Centre rod on origin so the camera framing is consistent across rods.
	if clone.PrimaryPart then
		clone:PivotTo(CFrame.new(0, 0, 0))
	end

	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.CFrame = CFrame.new(Vector3.new(2.4, 1.2, 5), Vector3.new(0, 0.5, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam

	-- Slow rotation. Disconnects when the viewport is destroyed.
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
		refs.buyBtn.BackgroundColor3 = UIStyle.Palette.TextMuted
		refs.buyBtn.AutoButtonColor = false
		refs.priceFrame.Visible = false
	else
		refs.buyBtn.Text = "BUY"
		refs.buyBtn.BackgroundColor3 = affordable and UIStyle.Palette.Safe or UIStyle.Palette.TextMuted
		refs.buyBtn.AutoButtonColor = affordable
		refs.priceFrame.Visible = true
		refs.priceLabel.Text = tostring(rod.price)
	end
end

local function refreshAll()
	for _, r in ipairs(RodCatalog.Rods) do refreshCard(r) end
end

local function buildRodCard(parent: Instance, rod: RodCatalog.Rod): Frame
	local card = UIStyle.MakePanel({
		Name = rod.id,
		Size = UDim2.fromOffset(220, 320),
		BackgroundColor3 = UIStyle.Palette.Panel,
	})
	card.Parent = parent

	local viewport = buildRodPreview(rod.id, card)
	local _ = viewport

	local nameLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.new(0, 8, 0.55, 4),
		Text = rod.name,
		Font = UIStyle.FontBold, TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	local _ = nameLabel

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.new(0, 8, 0.55, 32),
		Text = string.format("Tier %d", rod.tier),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = card,
	})

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.new(0, 8, 0.55, 52),
		Text = rod.description,
		TextSize = UIStyle.TextSize.Caption,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})

	-- Price row: coin icon + numeric price. Hidden when the rod is owned.
	-- (We avoid emoji glyphs because Roblox's Cartoon font renders them as tofu.)
	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceRow"
	priceFrame.Size = UDim2.new(1, -16, 0, 22)
	priceFrame.Position = UDim2.new(0, 8, 1, -64)
	priceFrame.BackgroundTransparency = 1
	priceFrame.Parent = card
	local _, priceLabel = IconFactory.Pill(priceFrame, IconFactory.Coin(20),
		"", UIStyle.Palette.TextPrimary, UIStyle.TextSize.Body)

	local buyBtn = UIStyle.MakeButton({
		Size = UDim2.new(1, -16, 0, 38),
		Position = UDim2.new(0, 8, 1, -42),
		Text = "BUY",
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Safe,
		Parent = card,
	})
	buyBtn.MouseButton1Click:Connect(function()
		if not buyBtn.AutoButtonColor then return end
		buyBtn.Text = "..."
		RemoteService.FireServer("RequestPurchaseRod", { rodId = rod.id })
	end)

	cardRefs[rod.id] = { panel = card, buyBtn = buyBtn, priceFrame = priceFrame, priceLabel = priceLabel }
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

	-- Dim background.
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = shopGui

	local panel = UIStyle.MakePanel({
		Name = "ShopPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(980, 460),
		BackgroundColor3 = UIStyle.Palette.Background,
		Parent = shopGui,
	})

	UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 12),
		Text = "FISHERMAN'S WARES",
		Font = UIStyle.FontBold, TextSize = UIStyle.TextSize.Title,
		Parent = panel,
	})

	local closeBtn = UIStyle.MakeButton({
		Size = UDim2.fromOffset(40, 32),
		Position = UDim2.new(1, -52, 0, 12),
		Text = "X",
		BackgroundColor3 = UIStyle.Palette.Risky,
		Parent = panel,
	})
	closeBtn.MouseButton1Click:Connect(closeShop)

	-- Card row.
	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 70)
	row.Size = UDim2.new(1, -32, 0, 340)
	row.BackgroundTransparency = 1
	row.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	for i, rod in ipairs(RodCatalog.Rods) do
		local card = buildRodCard(row, rod)
		card.LayoutOrder = i
	end
end

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
