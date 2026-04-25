--!strict
-- Round lifecycle: pair → reserved slot → built arena → both levels → score.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local RoundState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoundState"))

local Services = script.Parent
local MatchService = require(Services:WaitForChild("MatchService"))
local RoleService = require(Services:WaitForChild("RoleService"))
local PlayAreaService = require(Services:WaitForChild("PlayAreaService"))
local LevelService = require(Services:WaitForChild("LevelService"))
local ScoringService = require(Services:WaitForChild("ScoringService"))
local Helpers = Services:WaitForChild("Helpers")
local RoundContext = require(Helpers:WaitForChild("RoundContext"))

local RoundService = {}

local rewardServiceFn: ((any, any) -> any)? = nil

function RoundService.SetRewardHandler(fn)
	rewardServiceFn = fn
end

function RoundService.GetRoundForPlayer(player: Player)
	return RoundContext.GetRound(player)
end

local function startRoundForPair(pair)
	local explorer = RoleService.GetExplorer(pair.Id)
	local guide = RoleService.GetGuide(pair.Id)
	if not explorer or not guide then
		return
	end
	-- Reserve a slot
	local slot = PlayAreaService.ReserveSlot()
	if not slot then
		for _, p in ipairs(pair.Members) do
			RemoteService.FireClient(p, "Notify", {
				Kind = "Error",
				Text = "All play areas are busy. Try again in a moment.",
			})
		end
		return
	end
	local slotIndex = slot:GetAttribute("SlotIndex") or 0
	local round = RoundState.New(explorer, guide, pair.Id, slotIndex)
	RoundContext.Register(round)

	-- Build arena
	local ok = PlayAreaService.BuildArenaForRound(round)
	if not ok then
		PlayAreaService.ReleaseSlot(slot)
		RoundContext.Unregister(round)
		for _, p in ipairs(pair.Members) do
			RemoteService.FireClient(p, "Notify", {
				Kind = "Error",
				Text = "Couldn't set up the play area. Map might still be loading.",
			})
		end
		return
	end

	-- Send RoundStarted with booth resolution info so the Guide's
	-- GuideManualController can WaitForChild the booth's SurfaceGui.
	local boothModel = PlayAreaService.GetBoothForRound(round)
	local boothName = boothModel and boothModel.Name or Constants.DEFAULT_BOOTH_NAME
	RemoteService.FirePair(round, "RoundStarted", {
		RoundId = round.RoundId,
		PairId = round.PairId,
		SlotIndex = round.SlotIndex,
		BoothName = boothName,
		LevelSequence = round.LevelSequence,
		StartedAt = round.StartedAt,
	})

	-- Teleport
	PlayAreaService.TeleportGuideToBooth(round)

	-- Start first level
	LevelService.StartLevel(round, round.LevelSequence[1])
end

function RoundService.StartRoundForPlayer(player: Player)
	local pair = MatchService.GetPair(player)
	if not pair then return end
	if not RoleService.IsLocked(pair.Id) then
		-- Can only start once roles are locked
		RemoteService.FireClient(player, "Notify", {
			Kind = "Error",
			Text = "Pick your role before starting.",
		})
		return
	end
	-- Avoid double-start
	if RoundContext.GetRoundByPairId(pair.Id) then return end
	startRoundForPair(pair)
end

function RoundService.EndRound(round, reason: string?)
	if not round then return end
	if not round.IsActive then return end
	round.IsActive = false

	-- Compute final score and grant rewards before tearing down arena.
	local finalScore = ScoringService.CalculateFinalScore(round)
	finalScore.Reason = reason or "Completed"

	if rewardServiceFn then
		local rewardResult = rewardServiceFn(round, finalScore)
		if rewardResult then
			finalScore.Rewards = rewardResult
		end
	end

	RemoteService.FirePair(round, "ShowScoreScreen", finalScore)
	RemoteService.FirePair(round, "RoundEnded", {
		RoundId = round.RoundId,
		Reason = reason or "Completed",
		FinalScore = finalScore,
	})

	-- Disconnect tracked connections
	RoundState.DisconnectAll(round)

	-- Cleanup level state and play area
	LevelService.CleanupForRound(round)
	PlayAreaService.TeardownArenaForRound(round)

	RoundContext.Unregister(round)

	-- Reset role assignment for the pair so they can replay.
	RoleService.ResetPair(round.PairId)
end

function RoundService.Init()
	-- Wire LevelService → RoundService callback so completion of the last
	-- level finalizes the round.
	LevelService.SetRoundEnder(function(round, reason)
		RoundService.EndRound(round, reason or "Completed")
	end)

	-- Bind GetCurrentRoundState so any future client controller that wants
	-- a snapshot has a safe handler.
	RemoteService.OnServerInvoke("GetCurrentRoundState", function(player)
		local round = RoundContext.GetRound(player)
		if not round then return nil end
		return RoundState.SnapshotForClient(round)
	end)

	RemoteService.OnServerEvent("StartRound", function(player)
		RoundService.StartRoundForPlayer(player)
	end)

	RemoteService.OnServerEvent("ReturnToLobby", function(player)
		local round = RoundContext.GetRound(player)
		if round and round.IsActive then
			RoundService.EndRound(round, "Returned")
			return
		end
		-- Already ended; just clear pair so they can pair again.
		local pair = MatchService.GetPair(player)
		if pair then
			MatchService.RemovePairById(pair.Id)
			RoleService.ResetPair(pair.Id)
			for _, p in ipairs(pair.Members) do
				if p.Parent then
					RemoteService.FireClient(p, "PairCleared", { Reason = "Returned" })
				end
			end
		end
	end)

	-- Player disconnect mid-round: end the round for the surviving partner.
	Players.PlayerRemoving:Connect(function(player)
		local round = RoundContext.GetRound(player)
		if round and round.IsActive then
			RoundService.EndRound(round, "PartnerLeft")
		end
	end)
end

return RoundService
