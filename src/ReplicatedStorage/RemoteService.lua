--!strict
-- Single source for every RemoteEvent / RemoteFunction in the project.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local RemoteService = {}

RemoteService.Events = {
	-- Client -> Server
	"RequestPairFromCapsule",
	"RequestInvitePlayer",
	"RespondToInvite",
	"LeavePair",
	"SelectRole",
	"StartRound",
	"RequestInspectNpc",
	"RequestPickupItem",
	"RequestPlaceItemInLane",
	"RequestSetSlotBadge",
	"RequestSubmitAccusation",
	"RequestScanItem",
	"RequestHighlightItem",
	"RequestUnlockLane",
	"RequestDismissIntro",
	"ReturnToLobby",

	-- Server -> Client
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
	"OpenSlotPicker",
	"BoothStateUpdated",
	"ConveyorItemSpawned",
	"ConveyorItemRemoved",
	"ItemSortResult",
	"ItemFalloff",
	"GuideManualUpdated",
	"ExplorerFeedback",
	"ScoreUpdated",
	"ShowScoreScreen",
	"RewardGranted",
	"ProgressionUpdated",
	"Notify",
	"SetHudMode",
	"BeltStateUpdated",
	"ScannerOverlayUpdated",
	"HighlightUpdated",
	"LaneLockUpdated",
	"WaveStarted",
	"WaveEnded",
	"PixelPostIntro",
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
	local remote = folder:WaitForChild(name, 30)
	assert(remote and remote.ClassName == className, "RemoteService: missing remote " .. name)
	instances[name] = remote
	return remote
end

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

function RemoteService.FireClient(player: Player, name: string, ...)
	assert(RunService:IsServer(), "FireClient is server-only")
	RemoteService.GetEvent(name):FireClient(player, ...)
end

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
