--!strict
-- In-memory player profiles. MVP — no DataStore. Profiles drop on player leave.
-- Schema mirrors PlayerData in docs/PHISH_PRD.md §10.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

export type Profile = {
	coins: number,
	xp: number,
	totalCatches: number,
	correctCatches: number,
	role: string,                                 -- "Angler" | "CoastGuard" | "HarborMaster"
	unlockedSpecies: { [string]: number },        -- speciesId -> catch count
	foundSpecies: { [string]: boolean },          -- speciesId -> encountered at least once
	civicXP: number,
	rodGiven: boolean,
	rodTier: number,                              -- 1..4; gates which water tiles you can fish
	tutorialFlags: { [string]: boolean },          -- one-shot UI hints already shown
}

local DataService = {}

local profiles: { [Player]: Profile } = {}

local function newProfile(): Profile
	return {
		coins = 0,
		xp = 0,
		totalCatches = 0,
		correctCatches = 0,
		role = "Angler",
		unlockedSpecies = {},
		foundSpecies = {},
		civicXP = 0,
		rodGiven = false,
		rodTier = 1,                       -- starter rod
		tutorialFlags = {},
	}
end

-- Bump the player's rod tier (1..4). Useful for testing — call from the
-- Studio Server Command Bar:
--   require(game.ServerScriptService.Services.DataService).SetRodTier(game.Players.YourName, 4)
function DataService.SetRodTier(player: Player, tier: number)
	local profile = DataService.Get(player)
	profile.rodTier = math.clamp(math.floor(tier), 1, 4)
end

function DataService.MarkTutorial(player: Player, key: string): boolean
	local profile = DataService.Get(player)
	if profile.tutorialFlags[key] then return false end
	profile.tutorialFlags[key] = true
	return true
end

function DataService.HasSeenTutorial(player: Player, key: string): boolean
	return DataService.Get(player).tutorialFlags[key] == true
end

function DataService.Get(player: Player): Profile
	local p = profiles[player]
	if not p then
		p = newProfile()
		profiles[player] = p
	end
	return p
end

function DataService.Snapshot(player: Player): { [string]: any }
	local p = DataService.Get(player)
	local accuracy = 0
	if p.totalCatches > 0 then accuracy = p.correctCatches / p.totalCatches end
	return {
		coins = p.coins,
		xp = p.xp,
		totalCatches = p.totalCatches,
		correctCatches = p.correctCatches,
		accuracy = accuracy,
		role = p.role,
		unlockedSpecies = p.unlockedSpecies,
		foundSpecies = p.foundSpecies,
		civicXP = p.civicXP,
		rodTier = p.rodTier,
	}
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		profiles[player] = newProfile()
	end)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	RemoteService.OnServerInvoke("GetPlayerSnapshot", function(player)
		return DataService.Snapshot(player)
	end)
end

return DataService
