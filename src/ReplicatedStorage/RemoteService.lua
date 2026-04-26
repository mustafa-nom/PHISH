--!strict
-- Single source for every RemoteEvent / RemoteFunction in the project.
-- Every other service or controller MUST go through this module — never
-- create remotes ad-hoc or look them up by path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local RemoteService = {}

-- Two flat lists — the canonical contract. Adding a remote means adding it
-- here. Type ("Event" | "Function") is implicit from the table.

RemoteService.Events = {
	-- Client → Server
	"RequestPairFromCapsule",
	"RequestInvitePlayer",
	"RespondToInvite",
	"LeavePair",
	"SelectRole",
	"StartRound",
	"RequestInspectNpc",
	"RequestTalkToNpc",
	"RequestExplorerAction",  -- Approach | AskFirst | Avoid (new 3-way decision)
	"RequestPickupItem",
	"RequestPlaceItemInLane",
	"RequestAnnotateNpc",     -- Stranger Danger only; SD redesign owns its removal
	"RequestScanItem",        -- Backpack Checkpoint Active Scanner Guide
	"RequestHighlightItem",   -- Backpack Checkpoint Active Scanner Guide
	"RequestUnlockLane",      -- Backpack Checkpoint Active Scanner Guide
	"RequestVeto",            -- Backpack Checkpoint Veto button
	"RequestDismissIntro",    -- Pixel Post intro slide dismiss
	"ReturnToLobby",

	-- Server → Client
	"InviteReceived",
	"CapsulePairReady",
	"CapsulePairCleared",
	"PairAssigned",
	"PairCleared",
	"RoleAssigned",
	"RoundStarted",
	"RoundEnded",
	"RoundStateUpdated",
	"LevelStarted",
	"LevelEnded",
	"NpcDescriptionShown",
	"NpcCueRevealed",         -- one cue revealed to Explorer after AskFirst
	"NpcActionResolved",      -- result of an Approach/AskFirst/Avoid action
	"NpcAnnotationUpdated",   -- Stranger Danger only; SD redesign owns its removal
	"ConveyorItemSpawned",
	"ConveyorItemRemoved",
	"ItemSortResult",
	"ItemFalloff",            -- item fell off belt edge — counts as a mistake
	"ClueCollected",
	"PuppyRevealed",
	"GuideManualUpdated",
	"ExplorerFeedback",
	"ScoreUpdated",
	"ShowScoreScreen",
	"RewardGranted",
	"ProgressionUpdated",
	"Notify",
	"SetHudMode",
	-- Backpack Checkpoint Active Scanner Guide
	"BeltStateUpdated",       -- multi-item belt snapshot to Guide HUD
	"ScannerOverlayUpdated",  -- Scan reveal payload (tags) to Guide HUD
	"HighlightUpdated",       -- ring color update visible to both players
	"LaneLockUpdated",        -- per-item lane lock state for Explorer
	"WaveStarted",
	"WaveEnded",
	"PixelPostIntro",         -- intro slide payload (title, body)
	"VetoActivated",          -- veto button pressed; belt frozen for N seconds
	"VetoEnded",              -- veto freeze expired; lanes re-armable
	"MiniBossStarted",        -- VIP bag arrived; belt halted
	"MiniBossInnerActivated", -- next inner item is now active
	"MiniBossEnded",          -- bag fully resolved or round-failed
	"TutorialPrompt",         -- first-time tutorial overlay payload
	"FieldManualUpdated",     -- Field Manual seen-set delta or snapshot
}

RemoteService.Functions = {
	"GetCurrentRoundState",
	"GetProgression",
}

local remoteFolder: Folder? = nil
local instances: { [string]: Instance } = {}

local function ensureFolder(): Folder
	if remoteFolder and remoteFolder.Parent then
		return remoteFolder
	end
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
	-- Client: wait for the folder.
	local folder = ReplicatedStorage:WaitForChild(Constants.REMOTE_FOLDER_NAME, 30)
	assert(folder and folder:IsA("Folder"), "RemoteService: missing remotes folder")
	remoteFolder = folder :: Folder
	return remoteFolder :: Folder
end

local function ensureRemote(name: string, className: string): Instance
	if instances[name] then
		return instances[name]
	end
	local folder = ensureFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, "RemoteService: remote " .. name .. " has wrong class")
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
	-- Client: wait for the remote.
	local remote = folder:WaitForChild(name, 30)
	assert(remote and remote.ClassName == className, "RemoteService: missing remote " .. name)
	instances[name] = remote
	return remote
end

-- Server: create every declared remote. Idempotent.
function RemoteService.Init()
	if not RunService:IsServer() then
		return
	end
	ensureFolder()
	for _, name in ipairs(RemoteService.Events) do
		ensureRemote(name, "RemoteEvent")
	end
	for _, name in ipairs(RemoteService.Functions) do
		ensureRemote(name, "RemoteFunction")
	end
end

function RemoteService.GetEvent(name: string): RemoteEvent
	return ensureRemote(name, "RemoteEvent") :: RemoteEvent
end

function RemoteService.GetFunction(name: string): RemoteFunction
	return ensureRemote(name, "RemoteFunction") :: RemoteFunction
end

-- Server-only: fire one client.
function RemoteService.FireClient(player: Player, name: string, ...)
	assert(RunService:IsServer(), "FireClient is server-only")
	local event = RemoteService.GetEvent(name)
	event:FireClient(player, ...)
end

-- Server-only: fire both members of a round (Explorer + Guide). This is the
-- preferred path for any round-state event so we never accidentally
-- broadcast to other duos.
function RemoteService.FirePair(round: any, name: string, ...)
	assert(RunService:IsServer(), "FirePair is server-only")
	local event = RemoteService.GetEvent(name)
	if round.Explorer and round.Explorer.Parent then
		event:FireClient(round.Explorer, ...)
	end
	if round.Guide and round.Guide.Parent then
		event:FireClient(round.Guide, ...)
	end
end

-- Server-only: connect a server-side handler.
function RemoteService.OnServerEvent(name: string, handler: (Player, ...any) -> ()): RBXScriptConnection
	assert(RunService:IsServer(), "OnServerEvent is server-only")
	local event = RemoteService.GetEvent(name)
	return event.OnServerEvent:Connect(handler)
end

function RemoteService.OnServerInvoke(name: string, handler: (Player, ...any) -> ...any)
	assert(RunService:IsServer(), "OnServerInvoke is server-only")
	local fn = RemoteService.GetFunction(name)
	fn.OnServerInvoke = handler
end

-- Client-only: connect a client-side handler.
function RemoteService.OnClientEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(RunService:IsClient(), "OnClientEvent is client-only")
	local event = RemoteService.GetEvent(name)
	return event.OnClientEvent:Connect(handler)
end

-- Client-only: fire to server.
function RemoteService.FireServer(name: string, ...)
	assert(RunService:IsClient(), "FireServer is client-only")
	local event = RemoteService.GetEvent(name)
	event:FireServer(...)
end

function RemoteService.InvokeServer(name: string, ...): any
	assert(RunService:IsClient(), "InvokeServer is client-only")
	local fn = RemoteService.GetFunction(name)
	return fn:InvokeServer(...)
end

return RemoteService
