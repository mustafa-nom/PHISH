--!strict
-- Persistent player profiles backed by Roblox DataStoreService. Schema
-- mirrors PlayerData in docs/PHISH_PRD.md §10. All DataStore calls are
-- pcall-wrapped so a Studio session without "Enable Studio Access to
-- API Services" still functions in-memory (no persistence, but no
-- crashes either).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Progression = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Progression"))

local PROFILE_STORE_NAME = "PhishProfileV1"
local AUTOSAVE_INTERVAL = 90               -- seconds
local SCHEMA_VERSION = 1
local DEBUG = true

-- Fail-soft: if DataStoreService:GetDataStore errors (rare; unsupported
-- environment), fall back to a stub so the rest of the file behaves.
local profileStore: GlobalDataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(PROFILE_STORE_NAME)
	end)
	if ok then profileStore = store else warn("[PHISH][DataService] No DataStore: " .. tostring(store)) end
end

export type Profile = {
	coins: number,
	xp: number,
	totalCatches: number,
	correctCatches: number,
	role: string,                                 -- "Angler" | "CoastGuard" | "HarborMaster"
	unlockedSpecies: { [string]: number },        -- speciesId -> catch count
	foundSpecies: { [string]: boolean },          -- speciesId -> encountered at least once
	fishInventory: { [string]: number },          -- speciesId -> unsold fish count
	ownedCatchers: { [string]: number },          -- catcherId -> purchased count
	deployedCatchers: { [string]: any },           -- deployId -> deployment metadata
	catcherInventory: { [string]: number },        -- speciesId -> passive stash count
	catcherInventoryValue: number,                 -- total sell value of passive stash
	ownedGear: { [string]: number },               -- gearId -> consumable count
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
		fishInventory = {},
		ownedCatchers = {},
		deployedCatchers = {},
		catcherInventory = {},
		catcherInventoryValue = 0,
		ownedGear = {},
		civicXP = 0,
		rodGiven = false,
		rodTier = 1,                       -- starter rod
		tutorialFlags = {},
	}
end

-- Defensively merge a saved profile with the latest defaults. Any field
-- added after this player last played gets filled from newProfile()
-- without clobbering their existing data.
local function migrateProfile(saved: { [string]: any }): Profile
	local p = newProfile()
	for k, v in pairs(saved) do
		if k ~= "schemaVersion" and (p :: any)[k] ~= nil then
			(p :: any)[k] = v
		end
	end
	return p
end

local function profileKey(player: Player): string
	return string.format("u_%d", player.UserId)
end

-- Load with retry + pcall. Returns the profile (saved or default) and a
-- bool indicating whether a save actually came back from the store.
local function loadProfile(player: Player): (Profile, boolean)
	if not profileStore then return newProfile(), false end
	local store = profileStore
	for attempt = 1, 3 do
		local ok, data = pcall(function() return store:GetAsync(profileKey(player)) end)
		if ok then
			if type(data) == "table" then
				return migrateProfile(data), true
			end
			return newProfile(), false  -- key didn't exist yet
		end
		if DEBUG then
			warn(string.format("[PHISH][DataService] load attempt %d for %s failed: %s",
				attempt, player.Name, tostring(data)))
		end
		task.wait(0.5 * attempt)
	end
	return newProfile(), false
end

-- Save with UpdateAsync so we don't blow away a newer write from another
-- server instance (rare but possible if a player teleports between places).
local function saveProfile(player: Player, profile: Profile): boolean
	if not profileStore then return false end
	local store = profileStore
	local payload = table.clone(profile :: any) :: { [string]: any }
	payload.schemaVersion = SCHEMA_VERSION
	payload.lastSaved = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(profileKey(player), function() return payload end)
	end)
	if not ok and DEBUG then
		warn(string.format("[PHISH][DataService] save for %s failed: %s",
			player.Name, tostring(err)))
	end
	return ok
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
	local levelInfo = Progression.GetLevelInfo(p.xp)
	return {
		coins = p.coins,
		xp = p.xp,
		level = levelInfo.level,
		xpIntoLevel = levelInfo.xpIntoLevel,
		xpForNextLevel = levelInfo.xpForNextLevel,
		levelProgress = levelInfo.progress,
		isMaxLevel = levelInfo.isMaxLevel,
		boatSkin = {
			id = levelInfo.boatSkin.id,
			name = levelInfo.boatSkin.name,
			minLevel = levelInfo.boatSkin.minLevel,
		},
		unlockedBoatSkins = Progression.GetUnlockedBoatSkins(levelInfo.level),
		totalCatches = p.totalCatches,
		correctCatches = p.correctCatches,
		accuracy = accuracy,
		role = p.role,
		unlockedSpecies = p.unlockedSpecies,
		foundSpecies = p.foundSpecies,
		fishInventory = p.fishInventory,
		ownedCatchers = p.ownedCatchers,
		deployedCatchers = p.deployedCatchers,
		catcherInventory = p.catcherInventory,
		catcherInventoryValue = p.catcherInventoryValue,
		ownedGear = p.ownedGear,
		civicXP = p.civicXP,
		rodTier = p.rodTier,
	}
end

-- Force-save a player's current profile. Other services can call this
-- after high-value events (purchase, mastery) so progress survives a
-- crash, not just normal logout.
function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile then return false end
	return saveProfile(player, profile)
end

-- Listeners other services subscribe to. Used by LeaderboardService to
-- mirror profiles into its OrderedDataStore on save.
local saveCallbacks: { (Player, Profile) -> () } = {}
function DataService.OnSaved(callback: (Player, Profile) -> ())
	table.insert(saveCallbacks, callback)
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		local profile, fromStore = loadProfile(player)
		profiles[player] = profile
		if DEBUG then
			print(string.format("[PHISH][DataService] %s loaded (fromStore=%s, coins=%d, correctCatches=%d)",
				player.Name, tostring(fromStore), profile.coins, profile.correctCatches))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			saveProfile(player, profile)
			for _, cb in ipairs(saveCallbacks) do
				pcall(cb, player, profile)
			end
		end
		profiles[player] = nil
	end)

	-- Periodic autosave for crash safety. Skip if the player just left
	-- (profile already cleared).
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in pairs(profiles) do
				if player.Parent == Players then
					saveProfile(player, profile)
					for _, cb in ipairs(saveCallbacks) do
						pcall(cb, player, profile)
					end
				end
			end
		end
	end)

	-- Game shutdown: flush every active profile before the server dies.
	-- BindToClose is given ~30s by Roblox, but only if you don't return
	-- immediately. Save in parallel and wait for the slowest to finish.
	game:BindToClose(function()
		local pending = 0
		for player, profile in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile)
				for _, cb in ipairs(saveCallbacks) do
					pcall(cb, player, profile)
				end
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	RemoteService.OnServerInvoke("GetPlayerSnapshot", function(player)
		return DataService.Snapshot(player)
	end)
end

return DataService
