--!strict
-- PHISH server init. Creates remotes, then requires + initializes every
-- service in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

RemoteService.Init()

local ServicesFolder = script.Parent:WaitForChild("Services")
local function load(name: string) return require(ServicesFolder:WaitForChild(name)) end

local DataService = load("DataService")
local LevelService = load("LevelService")
local ScoringService = load("ScoringService")
local PhishDexService = load("PhishDexService")
local FishModelService = load("FishModelService")
local CardService = load("CardService")
local GearService = load("GearService")
local CatcherService = load("CatcherService")
local FishingService = load("FishingService")
local DecisionService = load("DecisionService")
local RodService = load("RodService")
local ShopService = load("ShopService")
local SellService = load("SellService")
local RoleService = load("RoleService")
local BossService = load("BossService")
local LeaderboardService = load("LeaderboardService")
local AnalyticsService = load("AnalyticsService")
local MapIntegrityService = load("MapIntegrityService")

DataService.Init()
LevelService.Init()
ScoringService.Init()
PhishDexService.Init()
FishModelService.Init()
CardService.Init()
GearService.Init()
CatcherService.Init()
FishingService.Init()
DecisionService.Init()
RodService.Init()
ShopService.Init()
SellService.Init()
RoleService.Init()
BossService.Init()
LeaderboardService.Init()
AnalyticsService.Init()
MapIntegrityService.Init()

print("[PHISH] Server services initialized.")
