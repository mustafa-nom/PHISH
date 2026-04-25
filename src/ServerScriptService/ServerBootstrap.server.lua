--!strict
-- Server-side init. Requires every service in dependency order and calls
-- Init() once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

-- Create remotes first; everything else relies on them.
RemoteService.Init()

local ServicesFolder = script.Parent:WaitForChild("Services")

local function load(name: string)
	return require(ServicesFolder:WaitForChild(name))
end

local MatchService = load("MatchService")
local LobbyService = load("LobbyService")
local RoleService = load("RoleService")
local ScoringService = load("ScoringService")
local PlayAreaService = load("PlayAreaService")
local ScenarioService = load("ScenarioService")
local LevelService = load("LevelService")
local RoundService = load("RoundService")
local GuideControlService = load("GuideControlService")
local ScannerService = load("ScannerService")
local ExplorerInteractionService = load("ExplorerInteractionService")
local DataService = load("DataService")
local RewardService = load("RewardService")
local AnalyticsService = load("AnalyticsService")

MatchService.Init()
LobbyService.Init()
RoleService.Init()
ScoringService.Init()
PlayAreaService.Init()
ScenarioService.Init()
LevelService.Init()

-- Wire reward handler before round service starts dispatching.
RoundService.SetRewardHandler(function(round, finalScore)
	return RewardService.GrantRunRewards(round, finalScore)
end)

RoundService.Init()
GuideControlService.Init()
ScannerService.Init()
ExplorerInteractionService.Init()
DataService.Init()
RewardService.Init()
AnalyticsService.Init()

-- When a pair is created (capsule confirm or invite accept), kick off
-- role-select with the auto-assign timer.
MatchService.OnPairCreated(function(pair)
	RoleService.HandlePairAssigned(pair)
end)

print("[BuddyBridge] Server services initialized.")
