--!strict
-- Single source for every RemoteEvent / RemoteFunction in PHISH. Every
-- service or controller MUST go through this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local RemoteService = {}

RemoteService.Events = {
	-- Client → Server
	"RequestRod",            -- player taps NPC ProximityPrompt to receive rod tool
	"RequestCast",           -- player throws lure ({ aimPos = Vector3 })
	"RequestReelTap",        -- player taps during reel mini-game
	"SubmitDecision",        -- KEEP / CUT_BAIT ({ decision = "KEEP" | "CUT_BAIT", flags = { elementId } })
	"RequestVerdict",        -- legacy verdict prompt compatibility
	"RequestOpenPhishDex",   -- player opens dex screen
	"RequestPurchaseRod",    -- shop purchase ({ rodId = string })
	"RequestPurchaseCatcher", -- shop purchase ({ catcherId = string })
	"RequestDeployCatcher",  -- deploy owned catcher ({ catcherId = string, target = Vector3 })
	"RequestPurchaseGear",   -- shop purchase ({ gearId = string })
	"RequestDeployGear",     -- deploy owned gear ({ gearId = string, target = Vector3 })
	"RequestSellAllFish",    -- sell every caught fish tool in backpack/character
	"RequestDebugCoins",     -- test shortcut: grant coins while iterating locally

	-- Server → Client
	"RodGranted",            -- ack that rod is in player's backpack
	"CastStarted",           -- server accepted the cast; client plays SFX/visuals
	"TutorialNudge",         -- one-shot hints: { title, text, durationSec }
	"BiteOccurred",          -- bite has happened, start reel mini-game (payload: { tapsRequired, windowSeconds })
	"ReelProgress",          -- per-tap progress update
	"ReelFailed",            -- player ran out of taps / time, fish escaped
	"ShowInspectionCard",    -- card data minus isLegit/species/redFlags (see DecisionService)
	"DecisionResult",        -- decision outcome + species + flags + rewards
	"VerdictPromptReady",    -- legacy verdict prompt compatibility
	"CatchResolved",         -- legacy result compatibility
	"LineSnapped",           -- legacy line failure compatibility
	"HudUpdated",            -- coins / accuracy / role / xp
	"SpeciesUnlocked",       -- toast: new dex entry unlocked
	"PhishermanArrived",     -- boss event start
	"PhishermanDefeated",    -- boss event end
	"LeaderboardUpdated",    -- snapshot for Board of Fame
	"PurchaseResult",        -- { ok, message, rodId, newCoins, newRodTier }
	"CatcherUpdated",        -- passive catcher ownership/deployment/stash changed
	"GearUpdated",           -- gear ownership/deployment changed
	"SellResult",            -- { soldCount, coinsDelta, newCoins }
	"Notify",                -- generic toast
}

RemoteService.Functions = {
	"GetPlayerSnapshot",     -- coins, accuracy, role, unlockedSpecies — for HUD/dex on join
	"GetPhishDex",           -- whole dex (for client-side dex UI)
}

local remoteFolder: Folder? = nil
local instances: { [string]: Instance } = {}

local function ensureFolder(): Folder
	if remoteFolder and remoteFolder.Parent then return remoteFolder end
	local existing = ReplicatedStorage:FindFirstChild(Constants.REMOTE_FOLDER_NAME)
	if existing then
		remoteFolder = existing :: Folder
		return remoteFolder :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = Constants.REMOTE_FOLDER_NAME
		folder.Parent = ReplicatedStorage
		remoteFolder = folder
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(Constants.REMOTE_FOLDER_NAME, 30)
	assert(folder and folder:IsA("Folder"), "RemoteService: missing remotes folder")
	remoteFolder = folder :: Folder
	return remoteFolder :: Folder
end

local function ensureRemote(name: string, className: string): Instance
	if instances[name] then return instances[name] end
	local folder = ensureFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, "RemoteService: " .. name .. " has wrong class")
		instances[name] = existing
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		instances[name] = remote
		return remote
	end
	local remote = folder:WaitForChild(name, 30)
	assert(remote and remote.ClassName == className, "RemoteService: missing " .. name)
	instances[name] = remote
	return remote
end

function RemoteService.Init()
	if not RunService:IsServer() then return end
	ensureFolder()
	for _, name in ipairs(RemoteService.Events) do ensureRemote(name, "RemoteEvent") end
	for _, name in ipairs(RemoteService.Functions) do ensureRemote(name, "RemoteFunction") end
end

function RemoteService.GetEvent(name: string): RemoteEvent
	return ensureRemote(name, "RemoteEvent") :: RemoteEvent
end

function RemoteService.GetFunction(name: string): RemoteFunction
	return ensureRemote(name, "RemoteFunction") :: RemoteFunction
end

function RemoteService.FireClient(player: Player, name: string, ...)
	assert(RunService:IsServer(), "FireClient is server-only")
	RemoteService.GetEvent(name):FireClient(player, ...)
end

function RemoteService.FireAllClients(name: string, ...)
	assert(RunService:IsServer(), "FireAllClients is server-only")
	RemoteService.GetEvent(name):FireAllClients(...)
end

function RemoteService.OnServerEvent(name: string, handler: (Player, ...any) -> ()): RBXScriptConnection
	assert(RunService:IsServer(), "OnServerEvent is server-only")
	return RemoteService.GetEvent(name).OnServerEvent:Connect(handler)
end

function RemoteService.OnServerInvoke(name: string, handler: (Player, ...any) -> ...any)
	assert(RunService:IsServer(), "OnServerInvoke is server-only")
	RemoteService.GetFunction(name).OnServerInvoke = handler
end

function RemoteService.OnClientEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(RunService:IsClient(), "OnClientEvent is client-only")
	return RemoteService.GetEvent(name).OnClientEvent:Connect(handler)
end

function RemoteService.FireServer(name: string, ...)
	assert(RunService:IsClient(), "FireServer is client-only")
	RemoteService.GetEvent(name):FireServer(...)
end

function RemoteService.InvokeServer(name: string, ...): any
	assert(RunService:IsClient(), "InvokeServer is client-only")
	return RemoteService.GetFunction(name):InvokeServer(...)
end

return RemoteService
