--!strict
-- Owns the rod Tool given to players, plus the display Models in
-- ReplicatedStorage.PhishRods that the shop ViewportFrames clone. Tier-aware:
-- when DataService.rodTier changes, RefreshRod rebuilds the player's tool to
-- match the new tier's visuals.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RodCatalog = require(Modules:WaitForChild("RodCatalog"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local RodService = {}

local ROD_TOOL_NAME = "PhishRod"
local TEMPLATES_FOLDER = "PhishRods"

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function boxBetween(a: Vector3, b: Vector3, thickness: number): (CFrame, Vector3)
	local midpoint = (a + b) * 0.5
	local direction = b - a
	return CFrame.lookAt(midpoint, b), Vector3.new(thickness, thickness, direction.Magnitude)
end

-- Build the visible rod parts onto a small invisible Handle. Used by both Tool
-- (in-hand) and Model (display) builders so the visuals stay in sync.
local function attachAnatomy(handle: Part, parent: Instance, spec: RodCatalog.Rod)
	local function add(name: string, props: { [string]: any }, localCFrame: CFrame): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do (p :: any)[k] = v end
		p.Parent = parent
		p.CFrame = handle.CFrame * localCFrame
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle; w.Part1 = p; w.Parent = handle
		return p
	end

	local function addSegment(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material): Part
		local localCFrame, size = boxBetween(a, b, thickness)
		return add(name, {
			Size = size,
			Color = color,
			Material = material,
		}, localCFrame)
	end

	local butt = Vector3.new(0, -0.58, 0.18)
	local gripTop = Vector3.new(0, 0.45, -0.16)
	local shaftMid = Vector3.new(0, 1.18, -0.78)
	local tipPos = Vector3.new(0, 3.25, -2.55)

	addSegment("GripWrap", butt, gripTop, 0.34, rgb(spec.wrapColor), Enum.Material.Fabric)

	add("ButtCap", {
		Size = Vector3.new(0.46, 0.16, 0.32), Color = rgb(spec.bandColor),
		Material = Enum.Material.Metal,
	}, CFrame.new(butt))

	addSegment("LowerShaft", gripTop, shaftMid, 0.18, rgb(spec.handleColor), Enum.Material.Wood)

	add("MidBand", {
		Size = Vector3.new(0.28, 0.28, 0.2), Color = rgb(spec.bandColor),
		Material = Enum.Material.Metal,
	}, CFrame.new(shaftMid))

	local reelCenter = Vector3.new(0.34, 0.0, 0.0)
	add("ReelHousing", {
		Size = Vector3.new(0.42, 0.42, 0.42), Color = rgb(spec.reelColor),
		Material = Enum.Material.Metal, Shape = Enum.PartType.Ball,
	}, CFrame.new(reelCenter))
	add("ReelDisc", {
		Size = Vector3.new(0.18, 0.54, 0.54), Color = rgb(spec.reelColor),
		Material = Enum.Material.Metal,
	}, CFrame.new(reelCenter + Vector3.new(0.18, 0, 0)))
	addSegment("ReelArm", reelCenter + Vector3.new(0.26, -0.1, 0), reelCenter + Vector3.new(0.44, -0.32, 0.06),
		0.08, rgb(spec.bandColor), Enum.Material.Metal)
	add("ReelKnob", {
		Size = Vector3.new(0.16, 0.16, 0.16), Color = rgb(spec.tipColor),
		Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball,
	}, CFrame.new(reelCenter + Vector3.new(0.46, -0.34, 0.06)))

	local upperMaterial = Enum.Material[spec.upperShaftMaterial] or Enum.Material.Wood
	addSegment("UpperShaft", shaftMid, tipPos, 0.1, rgb(spec.upperShaftColor), upperMaterial)

	local tip = add("Tip", {
		Size = Vector3.new(0.24, 0.24, 0.24), Color = rgb(spec.tipColor),
		Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
	}, CFrame.new(tipPos))
	local tipLight = Instance.new("PointLight")
	tipLight.Color = rgb(spec.tipColor)
	tipLight.Range = spec.tipGlowRange; tipLight.Brightness = 1.4
	tipLight.Parent = tip
end

local function buildHandle(name: string): Part
	local handle = Instance.new("Part")
	handle.Name = name
	handle.Size = Vector3.new(0.24, 0.24, 0.24)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	return handle
end

local function buildTool(spec: RodCatalog.Rod): Tool
	local tool = Instance.new("Tool")
	tool.Name = ROD_TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = spec.name
	tool.Grip = CFrame.new(0, -0.08, -0.08)

	local handle = buildHandle("Handle")
	handle.Parent = tool
	attachAnatomy(handle, tool, spec)

	tool:SetAttribute("PhishRod", true)
	tool:SetAttribute("RodId", spec.id)
	tool:SetAttribute("RodTier", spec.tier)
	CollectionService:AddTag(tool, ROD_TOOL_NAME)
	return tool
end

local function buildDisplayModel(spec: RodCatalog.Rod): Model
	local model = Instance.new("Model")
	model.Name = spec.id
	local handle = buildHandle("Handle")
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Parent = model
	model.PrimaryPart = handle
	attachAnatomy(handle, model, spec)
	model:SetAttribute("RodId", spec.id)
	model:SetAttribute("RodTier", spec.tier)
	return model
end

local function ensureTemplatesFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(TEMPLATES_FOLDER)
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = TEMPLATES_FOLDER
	folder.Parent = ReplicatedStorage
	return folder
end

local function buildAllTemplates()
	local folder = ensureTemplatesFolder()
	for _, spec in ipairs(RodCatalog.Rods) do
		local model = buildDisplayModel(spec)
		model.Parent = folder
	end
end

local function specForPlayer(player: Player): RodCatalog.Rod
	local profile = DataService.Get(player)
	local spec = RodCatalog.GetByTier(profile.rodTier or 1)
	return spec or RodCatalog.GetByTier(1) :: RodCatalog.Rod
end

-- Removes any existing rod the player has and gives them a fresh one matching
-- their current rodTier. Safe to call multiple times.
function RodService.RefreshRod(player: Player)
	local profile = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			local existing = container:FindFirstChild(ROD_TOOL_NAME)
			if existing then existing:Destroy() end
		end
	end
	if not backpack then return end
	local tool = buildTool(specForPlayer(player))
	tool.Parent = backpack
	profile.rodGiven = true
	RemoteService.FireClient(player, "RodGranted", {
		rodName = ROD_TOOL_NAME, rodId = tool:GetAttribute("RodId"), tier = tool:GetAttribute("RodTier"),
	})
end

local function giveRod(player: Player)
	local profile = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	-- If they already have the right rod, no-op. Otherwise refresh.
	local existing = backpack and backpack:FindFirstChild(ROD_TOOL_NAME)
		or (player.Character and player.Character:FindFirstChild(ROD_TOOL_NAME))
	if existing and existing:GetAttribute("RodTier") == profile.rodTier then return end
	RodService.RefreshRod(player)
end

local function bindRodPrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("PhishRodBound") == true then return end
	prompt:SetAttribute("PhishRodBound", true)
	prompt.Triggered:Connect(function(player)
		local ok, _ = RemoteValidation.RunChain({
			function() return RemoteValidation.RequirePlayer(player) end,
			function() return RemoteValidation.RequireRateLimit(player, "Rod", PhishConstants.RATE_LIMIT_ROD) end,
		})
		if not ok then return end
		giveRod(player)
	end)
end

local function bindNpcPrompt(npcModel: Instance)
	local prompt = npcModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then bindRodPrompt(prompt) end

	npcModel.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			bindRodPrompt(descendant)
		end
	end)
end

local function bindFallbackPrompts()
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt.ActionText == "Take a rod" then
			bindRodPrompt(prompt)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant)
		if not descendant:IsA("ProximityPrompt") or descendant.ActionText ~= "Take a rod" then return end
		bindRodPrompt(descendant)
	end)
end

function RodService.Init()
	buildAllTemplates()

	for _, npc in ipairs(CollectionService:GetTagged(PhishConstants.Tags.NpcAngler)) do
		bindNpcPrompt(npc)
	end
	CollectionService:GetInstanceAddedSignal(PhishConstants.Tags.NpcAngler):Connect(bindNpcPrompt)
	bindFallbackPrompts()

	RemoteService.OnServerEvent("RequestRod", function(player)
		local ok, _ = RemoteValidation.RunChain({
			function() return RemoteValidation.RequirePlayer(player) end,
			function() return RemoteValidation.RequireRateLimit(player, "Rod", PhishConstants.RATE_LIMIT_ROD) end,
		})
		if not ok then return end
		giveRod(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if DataService.Get(player).rodGiven then giveRod(player) end
		end)
	end)
end

return RodService
