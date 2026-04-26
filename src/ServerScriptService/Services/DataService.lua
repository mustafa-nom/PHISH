--!strict
-- Session-only player data store. MVP scope per CLAUDE.md "Data Model".

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local DataService = {}

export type PlayerData = {
	TrustSeeds: number,
	BestTime: number?,
	BestRank: string?,
	TotalRuns: number,
	PerfectRuns: number,
	TreehouseLevel: number,
	-- Sub-tabled so we can gate Guide tutorial separately from Explorer
	-- tutorial separately from any future tutorials. Old single-bool callers
	-- should be updated to use `HasSeenTutorial.<key>` keys.
	HasSeenTutorial: { [string]: boolean },
	-- BackpackCheckpoint Field Manual session meta-progression: the set of
	-- item keys this player has personally seen since they joined the
	-- server. Pre-seeded into the manual at round start and updated as new
	-- items spawn (per addendum #28).
	EncounteredItems: { [string]: boolean },
	Cosmetics: { string },
	EquippedCosmetic: string?,
}

local data: { [Player]: PlayerData } = {}

local function defaults(): PlayerData
	return {
		TrustSeeds = 0,
		BestTime = nil,
		BestRank = nil,
		TotalRuns = 0,
		PerfectRuns = 0,
		TreehouseLevel = 1,
		HasSeenTutorial = {},
		EncounteredItems = {},
		Cosmetics = {},
		EquippedCosmetic = nil,
	}
end

function DataService.GetData(player: Player): PlayerData
	if not data[player] then
		data[player] = defaults()
	end
	return data[player]
end

function DataService.UpdateData(player: Player, patch: { [string]: any }): PlayerData
	local current = DataService.GetData(player)
	for k, v in pairs(patch) do
		(current :: any)[k] = v
	end
	RemoteService.FireClient(player, "ProgressionUpdated", current)
	return current
end

function DataService.GrantSeeds(player: Player, amount: number): PlayerData
	local current = DataService.GetData(player)
	current.TrustSeeds += amount
	-- Treehouse stages: 1, 2, 4, 8, 16 seeds
	local stages = { 0, 2, 4, 8, 16, 32 }
	for level, threshold in ipairs(stages) do
		if current.TrustSeeds >= threshold then
			current.TreehouseLevel = level
		end
	end
	RemoteService.FireClient(player, "ProgressionUpdated", current)
	return current
end

-- Returns true if this is the first time the player has encountered this
-- item key (so callers can flag a "new!" badge). Idempotent on repeats.
function DataService.MarkItemEncountered(player: Player, itemKey: string): boolean
	local current = DataService.GetData(player)
	if current.EncounteredItems[itemKey] then
		return false
	end
	current.EncounteredItems[itemKey] = true
	return true
end

function DataService.GetEncounteredItems(player: Player): { [string]: boolean }
	local current = DataService.GetData(player)
	return current.EncounteredItems
end

-- Tutorial gating helpers. `key` is something like "BackpackCheckpointGuide".
function DataService.HasSeenTutorialKey(player: Player, key: string): boolean
	local current = DataService.GetData(player)
	return current.HasSeenTutorial[key] == true
end

function DataService.MarkTutorialSeen(player: Player, key: string)
	local current = DataService.GetData(player)
	current.HasSeenTutorial[key] = true
end

function DataService.NoteRunCompleted(player: Player, finalScore)
	local current = DataService.GetData(player)
	current.TotalRuns += 1
	if finalScore.PerfectLevels and finalScore.PerfectLevels >= 2 then
		current.PerfectRuns += 1
	end
	if finalScore.Rank == "Perfect" then
		current.BestRank = "Perfect"
	elseif current.BestRank == nil
		or (finalScore.Rank == "Gold" and current.BestRank ~= "Perfect")
		or (finalScore.Rank == "Silver" and current.BestRank == "Bronze") then
		current.BestRank = finalScore.Rank
	end
	if finalScore.Elapsed and (current.BestTime == nil or finalScore.Elapsed < current.BestTime) then
		current.BestTime = finalScore.Elapsed
	end
	RemoteService.FireClient(player, "ProgressionUpdated", current)
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		data[player] = defaults()
		task.wait(1)
		if player.Parent then
			RemoteService.FireClient(player, "ProgressionUpdated", data[player])
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		data[player] = nil
	end)

	RemoteService.OnServerInvoke("GetProgression", function(player)
		return DataService.GetData(player)
	end)
end

return DataService
