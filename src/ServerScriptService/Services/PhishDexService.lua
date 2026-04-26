--!strict
-- Tracks species unlocks per player. Fires SpeciesUnlocked when a species
-- crosses the catchesToUnlock threshold for the first time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishDex = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishDex"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local PhishDexService = {}

function PhishDexService.Init()
	-- Whole dex (with unlock counts) for the client dex screen.
	RemoteService.OnServerInvoke("GetPhishDex", function(player)
		local profile = DataService.Get(player)
		local out = {}
		for _, s in ipairs(PhishDex.Species) do
			local count = profile.unlockedSpecies[s.id] or 0
			local found = profile.foundSpecies[s.id] == true or count > 0
			local unlocked = count >= s.catchesToUnlock
			table.insert(out, {
				id = s.id,
				displayName = s.displayName,
				rarity = s.rarity,
				isLegit = s.isLegit,
				count = count,
				catchesToUnlock = s.catchesToUnlock,
				found = found,
				unlocked = unlocked,
				description = found and s.description or nil,
				realPatternName = found and s.realPatternName or nil,
				realWorldInfo = unlocked and s.realWorldInfo or nil,
				redFlags = unlocked and s.redFlags or nil,
				defenseStrategy = unlocked and s.defenseStrategy or nil,
			})
		end
		return out
	end)
end

function PhishDexService.RecordFound(player: Player, speciesId: string)
	local species = PhishDex.Get(speciesId)
	if not species then return end

	local profile = DataService.Get(player)
	profile.foundSpecies[speciesId] = true
end

-- Called after a correct catch. `speciesId` matches a PhishDex.Species.id.
function PhishDexService.RecordCatch(player: Player, speciesId: string)
	local species = PhishDex.Get(speciesId)
	if not species then return end

	local profile = DataService.Get(player)
	profile.foundSpecies[speciesId] = true
	local prev = profile.unlockedSpecies[speciesId] or 0
	local next_ = prev + 1
	profile.unlockedSpecies[speciesId] = next_

	if prev < species.catchesToUnlock and next_ >= species.catchesToUnlock then
		RemoteService.FireClient(player, "SpeciesUnlocked", {
			id = species.id,
			displayName = species.displayName,
			realPatternName = species.realPatternName,
			realWorldInfo = species.realWorldInfo,
			defenseStrategy = species.defenseStrategy,
		})
	end
end

return PhishDexService
