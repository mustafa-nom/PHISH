--!strict
-- Placement UX for deployable shop tools. Catchers and gear are purchased as
-- Tools; equipping one shows a translucent placement ghost over water, and
-- clicking sends the server-authoritative deploy request.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CatcherCatalog = require(Modules:WaitForChild("CatcherCatalog"))
local GearCatalog = require(Modules:WaitForChild("GearCatalog"))
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UI"):WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local equippedTool: Tool? = nil
local ghost: Model? = nil
local canPlace = false

local function destroyGhost()
	if ghost then ghost:Destroy() end
	ghost = nil
	canPlace = false
end

local function ghostPart(parent: Instance, name: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 0.45
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function buildCatcherGhost(id: string): Model
	local model = Instance.new("Model")
	model.Name = "CatcherPlacementGhost"
	local color = Color3.fromRGB(80, 170, 220)
	if id == "smart_trap" then color = Color3.fromRGB(120, 220, 140) end
	if id == "deep_sea_scanner" then color = Color3.fromRGB(150, 100, 240) end
	local base = ghostPart(model, "Base", {
		Size = Vector3.new(3, 0.35, 3),
		Color = color,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(),
	})
	ghostPart(model, "Mast", {
		Size = Vector3.new(0.25, 2.2, 0.25),
		Color = color,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(0, 1.2, 0),
	})
	model.PrimaryPart = base
	return model
end

local function buildGearGhost(id: string): Model
	local gear = GearCatalog.GetById(id)
	local radius = gear and gear.radius or 12
	local model = Instance.new("Model")
	model.Name = "GearPlacementGhost"
	local color = Color3.fromRGB(255, 210, 80)
	if gear and gear.passiveIntervalMultiplier then color = Color3.fromRGB(110, 220, 120) end
	if gear and gear.sellValueBonus then color = Color3.fromRGB(120, 196, 240) end
	local ring = ghostPart(model, "Radius", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(radius * 2, 0.12, radius * 2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.75,
		CFrame = CFrame.new(),
	})
	ghostPart(model, "Bob", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Color = color,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(0, 1.6, 0),
	})
	model.PrimaryPart = ring
	return model
end

local function setGhostValid(valid: boolean)
	local model = ghost
	if not model then return end
	local color = valid and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 80, 80)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = color
		end
	end
end

local function isWaterTarget(target: Instance?): boolean
	return target ~= nil and CollectionService:HasTag(target, PhishConstants.Tags.WaterZone)
end

local function equipTool(tool: Tool)
	local kind = tool:GetAttribute("DeployableKind")
	local id = tool:GetAttribute("DeployableId")
	if kind ~= "Catcher" and kind ~= "Gear" then return end
	if type(id) ~= "string" then return end

	equippedTool = tool
	destroyGhost()
	ghost = kind == "Catcher" and buildCatcherGhost(id) or buildGearGhost(id)
	ghost.Parent = workspace

	local displayName = tool.Name
	if kind == "Catcher" then
		local catcher = CatcherCatalog.GetById(id)
		if catcher then displayName = catcher.name end
	else
		local gear = GearCatalog.GetById(id)
		if gear then displayName = gear.name end
	end
	UIBuilder.Toast("Aim " .. displayName .. " at water, then click to place.", 4, "Success")
end

local function unequipTool(tool: Tool)
	if equippedTool ~= tool then return end
	equippedTool = nil
	destroyGhost()
end

local function bindTool(tool: Tool)
	if tool:GetAttribute("DeployPlacementBound") == true then return end
	tool:SetAttribute("DeployPlacementBound", true)
	tool.Equipped:Connect(function() equipTool(tool) end)
	tool.Unequipped:Connect(function() unequipTool(tool) end)
	tool.Activated:Connect(function()
		local current = equippedTool
		if current ~= tool or not canPlace then return end
		local kind = current:GetAttribute("DeployableKind")
		local id = current:GetAttribute("DeployableId")
		if type(id) ~= "string" then return end
		if kind == "Catcher" then
			RemoteService.FireServer("RequestDeployCatcher", { catcherId = id, target = mouse.Hit.Position })
		elseif kind == "Gear" then
			RemoteService.FireServer("RequestDeployGear", { gearId = id, target = mouse.Hit.Position })
		end
	end)
end

local function bindContainer(container: Instance?)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then bindTool(child) end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then bindTool(child) end
	end)
end

local function bindCharacter(character: Model)
	bindContainer(character)
end

bindContainer(player:WaitForChild("Backpack"))
if player.Character then bindCharacter(player.Character) end
player.CharacterAdded:Connect(bindCharacter)

RunService.RenderStepped:Connect(function()
	local model = ghost
	local tool = equippedTool
	if not model or not model.PrimaryPart or not tool then return end
	local target = mouse.Target
	canPlace = isWaterTarget(target)
	local pos = mouse.Hit.Position
	if target and target:IsA("BasePart") then
		pos = Vector3.new(pos.X, target.Position.Y + target.Size.Y / 2 + 0.2, pos.Z)
	end
	model:PivotTo(CFrame.new(pos))
	setGhostValid(canPlace)
end)

RemoteService.OnClientEvent("DeployableUsed", function()
	equippedTool = nil
	destroyGhost()
end)
