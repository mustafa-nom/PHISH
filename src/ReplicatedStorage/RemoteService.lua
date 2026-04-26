--!strict
-- Single source for every RemoteEvent / RemoteFunction in PHISH!. Other
-- services and controllers MUST go through this module — never create
-- remotes ad-hoc or look them up by path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local RemoteService = {}

RemoteService.Events = {
	-- Client → Server
	"RequestCast",
	"RequestVerify",
	"RequestReel",
	"RequestCutLine",
	"RequestReport",
	"RequestRelease",
	"RequestReelInput",
	"RequestPlaceFishInAquarium",
	"RequestSellFish",
	"RequestSellAll",
	"RequestPurchase",
	"RequestEquipRod",
	"RequestBoatInput",
	"RequestEnterBoat",
	"RequestExitBoat",

	-- Server → Client
	"ShowIntroSlide",
	"TutorialNudge",
	"BiteOccurred",
	"FieldGuideEntryUnlocked",
	"ReelMinigameStarted",
	"ReelMinigameTick",
	"ReelMinigameResolved",
	"BobberSpawned",
	"BobberDip",
	"BobberDespawned",
	"StreakUpdated",
	"RareCatchAnnouncement",
	"TitleUnlocked",
	"LuckyBobberCue",
	"CatchResolved",
	"JournalUpdated",
	"AquariumUpdated",
	"XpGranted",
	"PearlsGranted",
	"InventoryUpdated",
	"ZoneEntered",
	"ZoneLeft",
	"BoatStateUpdated",
	"Notify",
	"ShopUpdated",
}

RemoteService.Functions = {
	"GetSnapshot",
	"GetShopCatalog",
	"GetSellQuote",
}

local remoteFolder: Folder? = nil
local instances: { [string]: Instance } = {}

local function ensureFolder(): Folder
	if remoteFolder and remoteFolder.Parent then
		return remoteFolder :: Folder
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
	local event = RemoteService.GetEvent(name)
	event:FireClient(player, ...)
end

function RemoteService.FireAllClients(name: string, ...)
	assert(RunService:IsServer(), "FireAllClients is server-only")
	local event = RemoteService.GetEvent(name)
	event:FireAllClients(...)
end

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

function RemoteService.OnClientEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(RunService:IsClient(), "OnClientEvent is client-only")
	local event = RemoteService.GetEvent(name)
	return event.OnClientEvent:Connect(handler)
end

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
