--!strict
-- Passive tycoon-style fish catchers. Players buy catchers, deploy them on
-- water tiles, and collect/sell the passive stash at the fish market.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CatcherCatalog = require(Modules:WaitForChild("CatcherCatalog"))
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local ScamCards = require(ServerStorage:WaitForChild("ScamCards"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local GearService = require(Services:WaitForChild("GearService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local CatcherService = {}

local MAX_DEPLOYED_PER_PLAYER = 3
local deployCounter = 0
local activeModelsByPlayer: { [Player]: { Model } } = {}

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

local function deployedCount(profile: DataService.Profile): number
	local count = 0
	for _ in pairs(profile.deployedCatchers) do
		count += 1
	end
	return count
end

local function deployedOfType(profile: DataService.Profile, catcherId: string): number
	local count = 0
	for _, deployment in pairs(profile.deployedCatchers) do
		if type(deployment) == "table" and deployment.catcherId == catcherId then
			count += 1
		end
	end
	return count
end

local function emitUpdate(player: Player, message: string?)
	local profile = DataService.Get(player)
	RemoteService.FireClient(player, "CatcherUpdated", {
		ownedCatchers = profile.ownedCatchers,
		deployedCatchers = profile.deployedCatchers,
		catcherInventory = profile.catcherInventory,
		catcherInventoryValue = profile.catcherInventoryValue,
		message = message,
	})
	RemoteService.FireClient(player, "HudUpdated", DataService.Snapshot(player))
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

local function buildCatcherModel(player: Player, catcher: CatcherCatalog.Catcher, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PassiveCatcher_" .. catcher.id .. "_" .. tostring(player.UserId)
	model.Parent = Workspace

	local baseColor = Color3.fromRGB(80, 120, 160)
	if catcher.id == "smart_trap" then baseColor = Color3.fromRGB(120, 190, 130) end
	if catcher.id == "deep_sea_scanner" then baseColor = Color3.fromRGB(120, 90, 210) end

	local base = mkPart("Base", model, {
		Size = Vector3.new(3, 0.35, 3),
		Color = baseColor,
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)),
	})
	mkPart("FloatA", model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		Color = Color3.fromRGB(255, 210, 90),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(pos + Vector3.new(-1.35, 0.85, -1.35)),
	})
	mkPart("FloatB", model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		Color = Color3.fromRGB(255, 210, 90),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(pos + Vector3.new(1.35, 0.85, 1.35)),
	})
	mkPart("Mast", model, {
		Size = Vector3.new(0.25, 2.6, 0.25),
		Color = Color3.fromRGB(80, 50, 35),
		Material = Enum.Material.Wood,
		CFrame = CFrame.new(pos + Vector3.new(0, 1.55, 0)),
	})

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(180, 46)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.Parent = base
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = catcher.name .. "\n" .. player.DisplayName
	label.Parent = gui

	model.PrimaryPart = base
	activeModelsByPlayer[player] = activeModelsByPlayer[player] or {}
	table.insert(activeModelsByPlayer[player], model)
	return model
end

local function sellValueFor(card: any, catcher: CatcherCatalog.Catcher, pos: Vector3): number
	local baseCoins = (card.reward and card.reward.coins) or PhishConstants.REWARD_CORRECT_COINS
	local diffBonus = math.max(0, (card.difficulty or 1) - 1) * PhishConstants.REWARD_DIFFICULTY_BONUS
	local value = (baseCoins + diffBonus) * catcher.sellValueMultiplier
	value += GearService.GetSellValueBonusAt(pos)
	value *= GearService.GetCashMultiplierAt(pos)
	return math.max(1, math.floor(value + 0.5))
end

local function startLoop(player: Player, deployId: string, catcher: CatcherCatalog.Catcher, pos: Vector3, waterDifficulty: number)
	task.spawn(function()
		while player.Parent do
			local profile = DataService.Get(player)
			local deployment = profile.deployedCatchers[deployId]
			if type(deployment) ~= "table" then return end

			local interval = catcher.catchIntervalSeconds * GearService.GetPassiveIntervalMultiplierAt(pos)
			task.wait(math.max(5, interval))

			profile = DataService.Get(player)
			deployment = profile.deployedCatchers[deployId]
			if type(deployment) ~= "table" then return end
			if (deployment.storedCount or 0) >= catcher.capacity then
				RemoteService.FireClient(player, "Notify", {
					kind = "Error",
					message = catcher.name .. " is full. Sell fish at the market.",
					duration = 3,
				})
				emitUpdate(player)
				continue
			end

			local card = ScamCards.PickForWaterDifficulty(waterDifficulty)
			local speciesId = card.species
			local value = sellValueFor(card, catcher, pos)
			profile.catcherInventory[speciesId] = (profile.catcherInventory[speciesId] or 0) + 1
			profile.catcherInventoryValue += value
			profile.foundSpecies[speciesId] = true
			deployment.storedCount = (deployment.storedCount or 0) + 1
			deployment.lastCatchSpecies = speciesId
			deployment.lastCatchValue = value

			RemoteService.FireClient(player, "Notify", {
				kind = "Success",
				message = string.format("%s caught a fish worth %d pearls.", catcher.name, value),
				duration = 3,
			})
			emitUpdate(player)
		end
	end)
end

local function deployCatcher(player: Player, payload: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "DeployCatcher", 0.4) end,
	})
	if not ok then return end
	if type(payload) ~= "table" or type(payload.catcherId) ~= "string" or typeof(payload.target) ~= "Vector3" then return end

	local catcher = CatcherCatalog.GetById(payload.catcherId)
	if not catcher then return end

	local profile = DataService.Get(player)
	if deployedCount(profile) >= MAX_DEPLOYED_PER_PLAYER then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "You can deploy up to 3 catchers.", duration = 3 })
		return
	end

	local available = (profile.ownedCatchers[catcher.id] or 0) - deployedOfType(profile, catcher.id)
	if available <= 0 then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Buy that catcher before deploying it.", duration = 3 })
		return
	end

	local tile = waterTileAt(payload.target)
	if not tile then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Deploy catchers on a water tile.", duration = 3 })
		return
	end

	local minTier = tile:GetAttribute("MinRodTier") or 1
	local waterDifficulty = tile:GetAttribute("Difficulty") or minTier
	if type(waterDifficulty) ~= "number" then waterDifficulty = minTier end
	waterDifficulty = math.clamp(math.floor(waterDifficulty), 1, 5)

	if (profile.rodTier or 1) < waterDifficulty then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Your rod tier is too low for this water.", duration = 3 })
		return
	end
	if waterDifficulty < catcher.minWaterTier then
		RemoteService.FireClient(player, "Notify", {
			kind = "Error",
			message = string.format("%s needs tier %d+ water.", catcher.name, catcher.minWaterTier),
			duration = 3,
		})
		return
	end

	deployCounter += 1
	local deployId = tostring(player.UserId) .. "_" .. tostring(deployCounter)
	local position = Vector3.new(payload.target.X, tile.Position.Y + tile.Size.Y / 2 + 0.15, payload.target.Z)
	local model = buildCatcherModel(player, catcher, position)
	profile.deployedCatchers[deployId] = {
		id = deployId,
		catcherId = catcher.id,
		name = catcher.name,
		position = { position.X, position.Y, position.Z },
		waterDifficulty = waterDifficulty,
		storedCount = 0,
		capacity = catcher.capacity,
	}
	model:SetAttribute("DeployId", deployId)

	emitUpdate(player, "deployed")
	RemoteService.FireClient(player, "Notify", {
		kind = "Success",
		message = "Deployed " .. catcher.name .. ".",
		duration = 3,
	})
	startLoop(player, deployId, catcher, position, waterDifficulty)
end

function CatcherService.Init()
	RemoteService.OnServerEvent("RequestDeployCatcher", deployCatcher)

	Players.PlayerRemoving:Connect(function(player)
		local models = activeModelsByPlayer[player]
		if models then
			for _, model in ipairs(models) do
				if model.Parent then model:Destroy() end
			end
		end
		activeModelsByPlayer[player] = nil
	end)
end

return CatcherService
