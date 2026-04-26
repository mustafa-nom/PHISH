--!strict
-- Validates rod purchases. Server is authoritative on coins + rodTier; the
-- client only fires RequestPurchaseRod with a rodId. Server checks the catalog,
-- the player's coins, and that the rod is actually an upgrade, then deducts
-- the cost and refreshes the player's in-hand rod.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local CatcherCatalog = require(Modules:WaitForChild("CatcherCatalog"))
local GearCatalog = require(Modules:WaitForChild("GearCatalog"))
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RodCatalog = require(Modules:WaitForChild("RodCatalog"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local RodService = require(Services:WaitForChild("RodService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local ShopService = {}

local function buildDeployableTool(kind: string, id: string, displayName: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = displayName
	tool.ToolTip = "Equip, aim at water, then click to deploy."
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("DeployableKind", kind)
	tool:SetAttribute("DeployableId", id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 0.8, 0.8)
	handle.Shape = Enum.PartType.Ball
	handle.Material = Enum.Material.Neon
	handle.Color = kind == "Catcher" and Color3.fromRGB(80, 170, 220) or Color3.fromRGB(255, 205, 80)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

local function giveDeployableTool(player: Player, kind: string, id: string, displayName: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	buildDeployableTool(kind, id, displayName).Parent = backpack
end

local function reply(player: Player, ok: boolean, message: string, rodId: string?)
	local profile = DataService.Get(player)
	RemoteService.FireClient(player, "PurchaseResult", {
		ok = ok, message = message, rodId = rodId,
		newCoins = profile.coins, newRodTier = profile.rodTier,
	})
end

local function onPurchase(player: Player, payload: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "Purchase", 0.5) end,
	})
	if not ok then return end

	if type(payload) ~= "table" or type(payload.rodId) ~= "string" then
		return reply(player, false, "Bad request.")
	end

	local rod = RodCatalog.GetById(payload.rodId)
	if not rod then return reply(player, false, "That rod doesn't exist.", payload.rodId) end

	local profile = DataService.Get(player)
	if rod.tier <= (profile.rodTier or 1) then
		return reply(player, false, "You already have this rod or better.", rod.id)
	end
	if profile.coins < rod.price then
		return reply(player, false, string.format("Not enough pearls — need %d.", rod.price), rod.id)
	end

	profile.coins -= rod.price
	profile.rodTier = rod.tier
	RodService.RefreshRod(player)

	-- Push HUD so coin counter + rod tier refresh immediately.
	RemoteService.FireClient(player, "HudUpdated", DataService.Snapshot(player))
	reply(player, true, string.format("Purchased %s!", rod.name), rod.id)
end

local function onPurchaseCatcher(player: Player, payload: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "PurchaseCatcher", 0.5) end,
	})
	if not ok then return end
	if type(payload) ~= "table" or type(payload.catcherId) ~= "string" then
		return reply(player, false, "Bad request.")
	end

	local catcher = CatcherCatalog.GetById(payload.catcherId)
	if not catcher then return reply(player, false, "That catcher doesn't exist.", payload.catcherId) end

	local profile = DataService.Get(player)
	if profile.coins < catcher.price then
		return reply(player, false, string.format("Not enough pearls — need %d.", catcher.price), catcher.id)
	end

	profile.coins -= catcher.price
	profile.ownedCatchers[catcher.id] = (profile.ownedCatchers[catcher.id] or 0) + 1
	giveDeployableTool(player, "Catcher", catcher.id, catcher.name)
	RemoteService.FireClient(player, "HudUpdated", DataService.Snapshot(player))
	RemoteService.FireClient(player, "CatcherUpdated", {
		ownedCatchers = profile.ownedCatchers,
		deployedCatchers = profile.deployedCatchers,
		catcherInventory = profile.catcherInventory,
		catcherInventoryValue = profile.catcherInventoryValue,
	})
	reply(player, true, string.format("Purchased %s!", catcher.name), catcher.id)
end

local function onPurchaseGear(player: Player, payload: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "PurchaseGear", 0.5) end,
	})
	if not ok then return end
	if type(payload) ~= "table" or type(payload.gearId) ~= "string" then
		return reply(player, false, "Bad request.")
	end

	local gear = GearCatalog.GetById(payload.gearId)
	if not gear then return reply(player, false, "That gear doesn't exist.", payload.gearId) end

	local profile = DataService.Get(player)
	if profile.coins < gear.price then
		return reply(player, false, string.format("Not enough pearls — need %d.", gear.price), gear.id)
	end

	profile.coins -= gear.price
	profile.ownedGear[gear.id] = (profile.ownedGear[gear.id] or 0) + 1
	giveDeployableTool(player, "Gear", gear.id, gear.name)
	RemoteService.FireClient(player, "HudUpdated", DataService.Snapshot(player))
	RemoteService.FireClient(player, "GearUpdated", { ownedGear = profile.ownedGear })
	reply(player, true, string.format("Purchased %s!", gear.name), gear.id)
end

function ShopService.Init()
	-- Suppress "unused" warning on the constants import; future shop tunings
	-- (rate limits, restock timers) will pull from there.
	local _ = PhishConstants
	RemoteService.OnServerEvent("RequestPurchaseRod", onPurchase)
	RemoteService.OnServerEvent("RequestPurchaseCatcher", onPurchaseCatcher)
	RemoteService.OnServerEvent("RequestPurchaseGear", onPurchaseGear)
end

return ShopService
