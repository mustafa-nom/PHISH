--!strict
-- Fish market selling. Caught fish are Tools in the player's Backpack or
-- Character; selling destroys those tools and pays their stored SellValue.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PhishConstants = require(Modules:WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local FishModelService = require(Services:WaitForChild("FishModelService"))
local ScoringService = require(Services:WaitForChild("ScoringService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))

local SellService = {}

local function collectFishTools(player: Player): { Tool }
	local tools = {}
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if FishModelService.IsFishTool(child) then
					table.insert(tools, child :: Tool)
				end
			end
		end
	end
	return tools
end

local function sellAll(player: Player)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "SellFish", 0.8) end,
	})
	if not ok then return end

	local profile = DataService.Get(player)
	local stashCount = 0
	for _, count in pairs(profile.catcherInventory) do
		stashCount += count
	end

	local tools = collectFishTools(player)
	if #tools == 0 and stashCount == 0 then
		RemoteService.FireClient(player, "Notify", {
			kind = "Error",
			message = "You don't have any fish to sell yet.",
			duration = 3,
		})
		return
	end

	local total = 0
	local sold = 0
	for _, tool in ipairs(tools) do
		local value = tool:GetAttribute("SellValue")
		local speciesId = tool:GetAttribute("FishId")
		if type(value) == "number" and value > 0 then
			total += math.floor(value)
			sold += 1
			if type(speciesId) == "string" then
				profile.fishInventory[speciesId] = math.max(0, (profile.fishInventory[speciesId] or 0) - 1)
			end
			tool:Destroy()
		end
	end

	if stashCount > 0 then
		total += math.max(0, math.floor(profile.catcherInventoryValue or 0))
		sold += stashCount
		profile.catcherInventory = {}
		profile.catcherInventoryValue = 0
		for _, deployment in pairs(profile.deployedCatchers) do
			if type(deployment) == "table" then
				deployment.storedCount = 0
				deployment.lastCatchSpecies = nil
				deployment.lastCatchValue = nil
			end
		end
		RemoteService.FireClient(player, "CatcherUpdated", {
			ownedCatchers = profile.ownedCatchers,
			deployedCatchers = profile.deployedCatchers,
			catcherInventory = profile.catcherInventory,
			catcherInventoryValue = profile.catcherInventoryValue,
		})
	end

	if sold == 0 then return end
	profile.coins += total
	ScoringService.PushHud(player)
	RemoteService.FireClient(player, "SellResult", {
		soldCount = sold,
		coinsDelta = total,
		newCoins = profile.coins,
	})
	RemoteService.FireClient(player, "Notify", {
		kind = "Success",
		message = string.format("Sold %d fish for %d pearls.", sold, total),
		duration = 3,
	})
end

local function bindSellTrigger(part: Instance)
	if not part:IsA("BasePart") then return end
	if part:GetAttribute("ShopType") ~= "Sell" then return end
	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(player)
		sellAll(player)
	end)
end

function SellService.Init()
	RemoteService.OnServerEvent("RequestSellAllFish", sellAll)
	for _, trigger in ipairs(CollectionService:GetTagged(PhishConstants.Tags.ShopTrigger)) do
		bindSellTrigger(trigger)
	end
	CollectionService:GetInstanceAddedSignal(PhishConstants.Tags.ShopTrigger):Connect(bindSellTrigger)
end

return SellService
