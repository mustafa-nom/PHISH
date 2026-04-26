--!strict
-- Shop UI. Opens when the player walks within range of any part tagged
-- PhishShopPrompt. Refreshes from server-pushed ShopUpdated events.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local NumberFormatter = require(Modules:WaitForChild("NumberFormatter"))
local RodRegistry = require(Modules:WaitForChild("RodRegistry"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local activeFrame: Frame? = nil
local catalog: any = nil
local nearShop = false

local function close()
	if activeFrame then activeFrame:Destroy() end
	activeFrame = nil
end

local function buildEntryRow(parent: Instance, entry, layoutOrder: number)
	local row = UIStyle.MakePanel({
		Size = UDim2.new(1, -8, 0, 70),
		BackgroundColor3 = entry.Owned and UIStyle.Palette.Panel or UIStyle.Palette.Background,
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(0.6, 0, 0, 26),
		Position = UDim2.new(0, 12, 0, 6),
		Text = entry.DisplayName,
		TextSize = UIStyle.TextSize.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(0.6, 0, 0, 22),
		Position = UDim2.new(0, 12, 0, 32),
		Text = entry.Description,
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	if entry.Owned then
		local equipped = catalog and catalog.EquippedRodId == entry.Payload.rodId
		local btn = UIStyle.MakeButton({
			Size = UDim2.new(0, 130, 0, 36),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Text = equipped and "Equipped" or "Equip",
			BackgroundColor3 = equipped and UIStyle.Palette.Highlight or UIStyle.Palette.Safe,
			TextSize = UIStyle.TextSize.Body,
			Parent = row,
		})
		btn.Activated:Connect(function()
			if not equipped then
				RemoteService.FireServer("RequestEquipRod", { rodId = entry.Payload.rodId })
			end
		end)
	else
		local btn = UIStyle.MakeButton({
			Size = UDim2.new(0, 130, 0, 36),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Text = ("Buy %s"):format(NumberFormatter.Comma(entry.Price)),
			BackgroundColor3 = UIStyle.Palette.Accent,
			TextSize = UIStyle.TextSize.Body,
			Parent = row,
		})
		btn.Activated:Connect(function()
			RemoteService.FireServer("RequestPurchase", { entryId = entry.Id })
		end)
	end
end

local function rebuild()
	close()
	if not catalog then return end
	local frame = UIStyle.MakePanel({
		Name = "ShopFrame",
		Size = UDim2.new(0, 520, 0, 420),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Parent = screen,
	})
	activeFrame = frame
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 8),
		Text = "Fisherman's Shop",
		TextSize = UIStyle.TextSize.Title,
		Parent = frame,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 44),
		Text = ("Pearls: %s"):format(NumberFormatter.Comma(catalog.Pearls)),
		TextSize = UIStyle.TextSize.Body,
		Parent = frame,
	})
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -100)
	scroll.Position = UDim2.new(0, 8, 0, 76)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- Always show the wooden rod entry as "owned" so the player knows their default.
	local woodRod = RodRegistry.GetById("wooden_rod")
	if woodRod then
		buildEntryRow(scroll, {
			Id = "rod_wooden_rod",
			DisplayName = woodRod.displayName,
			Description = woodRod.description,
			Price = 0,
			Owned = true,
			Payload = { rodId = "wooden_rod" },
		}, 0)
	end
	for i, entry in ipairs(catalog.Entries) do
		buildEntryRow(scroll, entry, i)
	end

	local closeBtn = UIStyle.MakeButton({
		Size = UDim2.new(0, 110, 0, 28),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Text = "Close",
		TextSize = UIStyle.TextSize.Caption,
		Parent = frame,
	})
	closeBtn.Activated:Connect(close)
end

RemoteService.OnClientEvent("ShopUpdated", function(payload)
	catalog = payload
	if activeFrame then rebuild() end
end)

local function inRange(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	for _, p in ipairs(CollectionService:GetTagged(Constants.TAGS.ShopPrompt)) do
		if p:IsA("BasePart") and (p.Position - root.Position).Magnitude < 12 then
			return true
		end
	end
	return false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E and nearShop then
		if activeFrame then close() return end
		if not catalog then
			task.spawn(function()
				local ok, snap = pcall(function()
					return RemoteService.InvokeServer("GetShopCatalog")
				end)
				if ok and snap then
					catalog = snap
					rebuild()
				end
			end)
		else
			rebuild()
		end
	end
end)

task.spawn(function()
	while true do
		nearShop = inRange()
		task.wait(0.5)
	end
end)
RunService.Heartbeat:Connect(function() end) -- keep loop alive
