--!strict
-- Server-side init for PHISH!. Requires every service in dependency order
-- and prints a tag-count diagnostics report so the team can spot missing
-- map handoffs at boot.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

RemoteService.Init()

local ServicesFolder = script.Parent:WaitForChild("Services")

local function load(name: string)
	return require(ServicesFolder:WaitForChild(name))
end

local DataService = load("DataService")
local IntroService = load("IntroService")
local PondService = load("PondService")
local BobberService = load("BobberService")
local StreakService = load("StreakService")
local AnnouncementService = load("AnnouncementService")
local ReelMinigameService = load("ReelMinigameService")
local CastingService = load("CastingService")
local BiteService = load("BiteService")
local FieldGuideService = load("FieldGuideService")
local JournalService = load("JournalService")
local AquariumService = load("AquariumService")
local RewardService = load("RewardService")
local CatchResolutionService = load("CatchResolutionService")
local ShopService = load("ShopService")
local SellService = load("SellService")
local RowboatService = load("RowboatService")

DataService.Init()
IntroService.Init()
PondService.Init()
BobberService.Init()
StreakService.Init()
AnnouncementService.Init()
ReelMinigameService.Init()
CastingService.Init()
BiteService.Init()
FieldGuideService.Init()
JournalService.Init()
AquariumService.Init()
RewardService.Init()
CatchResolutionService.Init()
ShopService.Init()
SellService.Init()
RowboatService.Init()

local function diag()
	local lines = { "[PHISH!] Map diagnostics:" }
	for label, tag in pairs(Constants.TAGS) do
		local n = #CollectionService:GetTagged(tag)
		table.insert(lines, ("  %s (%s): %d"):format(label, tag, n))
	end
	print(table.concat(lines, "\n"))
end

task.delay(1, diag)
print("[PHISH!] Server services initialized.")
