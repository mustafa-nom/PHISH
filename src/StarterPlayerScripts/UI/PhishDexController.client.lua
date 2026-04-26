--!strict
-- Fish Index screen. Toggle with the on-screen INDEX button or "P". Displays
-- species the player has found, with unseen entries kept as silhouettes.
-- Server-authoritative: fetches via GetPhishDex on each open.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()
local fishTemplates = ReplicatedStorage:WaitForChild("PhishFishTemplates")

local function clearOld()
	local old = screen:FindFirstChild("PhishDex")
	if old then old:Destroy() end
end

local function rarityColor(rarity: string?): Color3
	if rarity == "Rare" then return Color3.fromRGB(120, 200, 255) end
	if rarity == "Uncommon" then return Color3.fromRGB(130, 210, 130) end
	if rarity == "Epic" then return Color3.fromRGB(220, 130, 250) end
	if rarity == "Legendary" then return Color3.fromRGB(255, 200, 80) end
	return UIStyle.Palette.AskFirst
end

local function buildFishPreview(speciesId: string, found: boolean, parent: Instance): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "FishPreview"
	vf.AnchorPoint = Vector2.new(0.5, 0)
	vf.Position = UDim2.new(0.5, 0, 0, 8)
	vf.Size = UDim2.fromOffset(96, 56)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(190, 180, 160)
	vf.LightColor = Color3.fromRGB(255, 245, 220)
	vf.LightDirection = Vector3.new(-0.4, -1, -0.25)
	vf.Parent = parent

	local template = fishTemplates:FindFirstChild(speciesId)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.Color = found and part.Color or Color3.fromRGB(70, 70, 70)
				part.Transparency = found and part.Transparency or 0.25
			elseif not found and part:IsA("PointLight") then
				part.Enabled = false
			end
		end
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-20), 0))
		clone.Parent = vf
	end

	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.CFrame = CFrame.new(Vector3.new(0, 0.4, 8), Vector3.new(0, 0.1, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

local open: () -> ()

local function toggle()
	if screen:FindFirstChild("PhishDex") then
		clearOld()
	else
		open()
	end
end

open = function()
	clearOld()
	local entries = nil
	local ok = pcall(function() entries = RemoteService.InvokeServer("GetPhishDex") end)
	if not ok or type(entries) ~= "table" then return end

	local panel = UIStyle.MakePanel({
		Name = "PhishDex",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 540),
		BackgroundColor3 = UIStyle.Palette.Background,
	})
	panel.Parent = screen

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -96, 0, 42),
		Position = UDim2.fromOffset(16, 8),
		Text = "FISH INDEX",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	local foundCount = 0
	for _, e in ipairs(entries) do
		if e.found then foundCount += 1 end
	end
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -112, 0, 22),
		Position = UDim2.fromOffset(16, 48),
		Text = string.format("%d / %d fish found", foundCount, #entries),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	local closeBtn = UIStyle.MakeButton({
		Size = UDim2.fromOffset(40, 32),
		Position = UDim2.new(1, -52, 0, 12),
		Text = "X",
		BackgroundColor3 = UIStyle.Palette.Risky,
	})
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(clearOld)

	local gridFrame = Instance.new("ScrollingFrame")
	gridFrame.Name = "TileGrid"
	gridFrame.Size = UDim2.new(1, -32, 1, -88)
	gridFrame.Position = UDim2.fromOffset(16, 76)
	gridFrame.BackgroundTransparency = 1
	gridFrame.CanvasSize = UDim2.fromOffset(0, 0)
	gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridFrame.ScrollBarThickness = 6
	gridFrame.Parent = panel

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingBottom = UDim.new(0, 8)
	gridPadding.Parent = gridFrame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 150)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	for _, e in ipairs(entries) do
		local found = e.found == true
		local mastered = e.unlocked == true
		local tile = UIStyle.MakePanel({
			Name = tostring(e.id or "FishTile"),
			Size = UDim2.fromOffset(150, 150),
			BackgroundColor3 = found and UIStyle.Palette.Panel or UIStyle.Palette.Background,
		})
		tile.Parent = gridFrame

		local previewBack = Instance.new("Frame")
		previewBack.Name = "PreviewBack"
		previewBack.AnchorPoint = Vector2.new(0.5, 0)
		previewBack.Position = UDim2.new(0.5, 0, 0, 8)
		previewBack.Size = UDim2.fromOffset(106, 62)
		previewBack.BackgroundColor3 = found and rarityColor(e.rarity) or UIStyle.Palette.TextMuted
		previewBack.BackgroundTransparency = found and 0.15 or 0.35
		previewBack.BorderSizePixel = 0
		previewBack.Parent = tile
		UIStyle.ApplyCorner(previewBack, UDim.new(0, 12))
		buildFishPreview(tostring(e.id or ""), found, tile)

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 38),
			Position = UDim2.fromOffset(8, 72),
			Text = found and e.displayName or "Unknown fish",
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Body,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Parent = tile,
		})

		local status = mastered and "Mastered" or (found and "Found" or "Not found")
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.fromOffset(8, 112),
			Text = string.format("%s | %s", e.rarity or "Common", status),
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = UIStyle.Palette.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Parent = tile,
		})

		UIStyle.MakeLabel({
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.fromOffset(8, 130),
			Text = string.format("%d / %d", e.count or 0, e.catchesToUnlock or 3),
			TextSize = UIStyle.TextSize.Caption,
			TextColor3 = mastered and UIStyle.Palette.Safe or UIStyle.Palette.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})
	end
end

local indexBtn = UIStyle.MakeButton({
	Name = "FishIndexButton",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(116, 38),
	Position = UDim2.new(1, -16, 0, 58),
	Text = "INDEX",
	TextSize = UIStyle.TextSize.Body,
	BackgroundColor3 = UIStyle.Palette.AskFirst,
	Parent = screen,
})
indexBtn.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggle()
	end
end)
