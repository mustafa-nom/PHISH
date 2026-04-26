--!strict
-- Deployable consumable gear. Gear creates temporary water-area effects such
-- as 2x sell value, passive catcher speed, or flat pearl bonuses.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GearCatalog = require(Modules:WaitForChild("GearCatalog"))
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local GearService = {}

type ActiveBoost = {
	owner: Player,
	gearId: string,
	position: Vector3,
	radius: number,
	expiresAt: number,
	model: Model,
}

local activeBoosts: { ActiveBoost } = {}

local function waterTileAt(target: Vector3): BasePart?
	local map = Workspace:FindFirstChild("PhishMap")
	local waterFolder = map and map:FindFirstChild("PhishWater")
	if not waterFolder then return nil end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { waterFolder }
	params.IgnoreWater = true

	local result = Workspace:Raycast(Vector3.new(target.X, target.Y + 80, target.Z), Vector3.new(0, -220, 0), params)
	if result and result.Instance and CollectionService:HasTag(result.Instance, PhishConstants.Tags.WaterZone) then
		return result.Instance
	end
	return nil
end

local function emitUpdate(player: Player)
	local profile = DataService.Get(player)
	RemoteService.FireClient(player, "GearUpdated", {
		ownedGear = profile.ownedGear,
	})
	RemoteService.FireClient(player, "HudUpdated", DataService.Snapshot(player))
end

local function consumeDeployableTool(player: Player, gearId: string)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if
					child:IsA("Tool")
					and child:GetAttribute("DeployableKind") == "Gear"
					and child:GetAttribute("DeployableId") == gearId
				then
					child:Destroy()
					RemoteService.FireClient(player, "DeployableUsed", { kind = "Gear", id = gearId })
					return
				end
			end
		end
	end
end

local function mkPart(name: string, parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function buildBoostModel(player: Player, gear: GearCatalog.Gear, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Gear_" .. gear.id .. "_" .. tostring(player.UserId)
	model.Parent = Workspace

	local color = Color3.fromRGB(255, 210, 80)
	if gear.passiveIntervalMultiplier then color = Color3.fromRGB(110, 220, 120) end
	if gear.sellValueBonus then color = Color3.fromRGB(120, 196, 240) end

	local ring = mkPart("Radius", model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(gear.radius * 2, 0.18, gear.radius * 2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.72,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)),
	})
	local bob = mkPart("Bob", model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Color = color,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(pos + Vector3.new(0, 1.8, 0)),
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = gear.radius
	light.Brightness = 1.4
	light.Parent = bob

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(180, 42)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.Parent = bob
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = gear.name
	label.Parent = gui

	model.PrimaryPart = ring
	return model
end

local function pruneExpired()
	local now = os.clock()
	local kept = {}
	for _, boost in ipairs(activeBoosts) do
		if boost.expiresAt > now and boost.owner.Parent then
			table.insert(kept, boost)
		else
			if boost.model.Parent then boost.model:Destroy() end
		end
	end
	activeBoosts = kept
end

local function deployGear(player: Player, payload: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "DeployGear", 0.4) end,
	})
	if not ok then return end
	if type(payload) ~= "table" or type(payload.gearId) ~= "string" or typeof(payload.target) ~= "Vector3" then return end

	local gear = GearCatalog.GetById(payload.gearId)
	if not gear then return end

	local profile = DataService.Get(player)
	if (profile.ownedGear[gear.id] or 0) <= 0 then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Buy that gear before deploying it.", duration = 3 })
		return
	end

	local tile = waterTileAt(payload.target)
	if not tile then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Deploy gear on a water tile.", duration = 3 })
		return
	end

	profile.ownedGear[gear.id] -= 1
	local position = Vector3.new(payload.target.X, tile.Position.Y + tile.Size.Y / 2 + 0.08, payload.target.Z)
	consumeDeployableTool(player, gear.id)
	local boost = {
		owner = player,
		gearId = gear.id,
		position = position,
		radius = gear.radius,
		expiresAt = os.clock() + gear.durationSeconds,
		model = buildBoostModel(player, gear, position),
	}
	table.insert(activeBoosts, boost)

	emitUpdate(player)
	RemoteService.FireClient(player, "Notify", {
		kind = "Success",
		message = string.format("Deployed %s for %d seconds.", gear.name, gear.durationSeconds),
		duration = 3,
	})
end

local function inRadius(boost: ActiveBoost, pos: Vector3): boolean
	local a = Vector3.new(boost.position.X, 0, boost.position.Z)
	local b = Vector3.new(pos.X, 0, pos.Z)
	return (a - b).Magnitude <= boost.radius
end

function GearService.GetCashMultiplierAt(pos: Vector3): number
	pruneExpired()
	local multiplier = 1
	for _, boost in ipairs(activeBoosts) do
		local gear = GearCatalog.GetById(boost.gearId)
		if gear and gear.cashMultiplier and inRadius(boost, pos) then
			multiplier = math.max(multiplier, gear.cashMultiplier)
		end
	end
	return multiplier
end

function GearService.GetPassiveIntervalMultiplierAt(pos: Vector3): number
	pruneExpired()
	local multiplier = 1
	for _, boost in ipairs(activeBoosts) do
		local gear = GearCatalog.GetById(boost.gearId)
		if gear and gear.passiveIntervalMultiplier and inRadius(boost, pos) then
			multiplier = math.min(multiplier, gear.passiveIntervalMultiplier)
		end
	end
	return multiplier
end

function GearService.GetSellValueBonusAt(pos: Vector3): number
	pruneExpired()
	local bonus = 0
	for _, boost in ipairs(activeBoosts) do
		local gear = GearCatalog.GetById(boost.gearId)
		if gear and gear.sellValueBonus and inRadius(boost, pos) then
			bonus += gear.sellValueBonus
		end
	end
	return bonus
end

function GearService.Init()
	RemoteService.OnServerEvent("RequestDeployGear", deployGear)

	Players.PlayerRemoving:Connect(function(player)
		for _, boost in ipairs(activeBoosts) do
			if boost.owner == player and boost.model.Parent then
				boost.model:Destroy()
			end
		end
		pruneExpired()
	end)

	task.spawn(function()
		while true do
			task.wait(10)
			pruneExpired()
		end
	end)
end

return GearService
