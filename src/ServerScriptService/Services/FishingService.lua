--!strict
-- Cast → Bite → Reel pipeline. Holds per-player state so DecisionService can
-- only resolve when the player is actually inspecting a card.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))
local SignalTracker = require(Helpers:WaitForChild("SignalTracker"))

export type State = "Idle" | "Waiting" | "Biting" | "Reeling" | "Inspecting"

local FishingService = {}

local stateByPlayer: { [Player]: State } = {}
local reelCountByPlayer: { [Player]: number } = {}
local timerThreadByPlayer: { [Player]: thread } = {}

local function setState(player: Player, s: State)
	stateByPlayer[player] = s
end

function FishingService.GetState(player: Player): State
	return stateByPlayer[player] or "Idle"
end

function FishingService.SetIdle(player: Player)
	setState(player, "Idle")
	reelCountByPlayer[player] = 0
	local t = timerThreadByPlayer[player]
	if t then task.cancel(t); timerThreadByPlayer[player] = nil end
end

local function nearestCastZone(player: Player): (BasePart?, number)
	local char = player.Character
	if not char then return nil, math.huge end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil, math.huge end
	local best, bestDist = nil :: BasePart?, math.huge
	for _, zone in ipairs(CollectionService:GetTagged(PhishConstants.Tags.CastZone)) do
		if zone:IsA("BasePart") then
			local d = (zone.Position - root.Position).Magnitude
			if d < bestDist then best = zone; bestDist = d end
		end
	end
	return best, bestDist
end

local function scheduleBite(player: Player)
	local wait_ = math.random() * (PhishConstants.BITE_MAX_WAIT_SECONDS - PhishConstants.BITE_MIN_WAIT_SECONDS)
		+ PhishConstants.BITE_MIN_WAIT_SECONDS
	timerThreadByPlayer[player] = task.delay(wait_, function()
		if FishingService.GetState(player) ~= "Waiting" then return end
		setState(player, "Biting")
		RemoteService.FireClient(player, "BiteOccurred", {
			tapsRequired = PhishConstants.REEL_TAPS_REQUIRED,
			windowSeconds = PhishConstants.REEL_WINDOW_SECONDS,
		})
		-- Window for the player to start reeling. If they don't, fish escapes.
		timerThreadByPlayer[player] = task.delay(PhishConstants.BITE_TIMEOUT_SECONDS, function()
			if FishingService.GetState(player) == "Biting" then
				FishingService.SetIdle(player)
				RemoteService.FireClient(player, "ReelFailed", { reason = "BiteTimeout" })
			end
		end)
	end)
end

local function startReel(player: Player)
	setState(player, "Reeling")
	reelCountByPlayer[player] = 0
	local t = timerThreadByPlayer[player]
	if t then task.cancel(t) end
	timerThreadByPlayer[player] = task.delay(PhishConstants.REEL_WINDOW_SECONDS, function()
		if FishingService.GetState(player) == "Reeling" then
			FishingService.SetIdle(player)
			RemoteService.FireClient(player, "ReelFailed", { reason = "ReelTimeout" })
		end
	end)
end

local function onCast(player: Player)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "Cast", PhishConstants.RATE_LIMIT_CAST) end,
	})
	if not ok then return end
	if FishingService.GetState(player) ~= "Idle" then return end
	local zone, dist = nearestCastZone(player)
	if not zone or dist > 24 then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Walk to the dock to cast." })
		return
	end
	setState(player, "Waiting")
	RemoteService.FireClient(player, "CastStarted", { aim = zone.Position })
	scheduleBite(player)
end

local function onReelTap(player: Player)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "ReelTap", PhishConstants.RATE_LIMIT_REEL_TAP) end,
	})
	if not ok then return end
	local s = FishingService.GetState(player)
	if s == "Biting" then
		startReel(player)
		s = "Reeling"
	end
	if s ~= "Reeling" then return end
	local n = (reelCountByPlayer[player] or 0) + 1
	reelCountByPlayer[player] = n
	RemoteService.FireClient(player, "ReelProgress", { count = n, required = PhishConstants.REEL_TAPS_REQUIRED })
	if n >= PhishConstants.REEL_TAPS_REQUIRED then
		setState(player, "Inspecting")
		local card = CardService.PickAndArm(player)
		RemoteService.FireClient(player, "ShowInspectionCard", CardService.ToPublic(card))
		local t = timerThreadByPlayer[player]
		if t then task.cancel(t); timerThreadByPlayer[player] = nil end
		-- First-card nudge: teach the player what to look at.
		if DataService.MarkTutorial(player, "FirstInspection") then
			task.delay(0.6, function()
				if not player.Parent then return end
				RemoteService.FireClient(player, "TutorialNudge", {
					title = "Read it like a real email",
					text = "Check the sender's address AND the link's true URL — scams usually fake one but rarely both.",
					durationSec = 7,
				})
			end)
		end
	end
end

function FishingService.Init()
	RemoteService.OnServerEvent("RequestCast", onCast)
	RemoteService.OnServerEvent("RequestReelTap", onReelTap)

	Players.PlayerRemoving:Connect(function(player)
		FishingService.SetIdle(player)
		stateByPlayer[player] = nil
		reelCountByPlayer[player] = nil
		SignalTracker.Cleanup(player)
		CardService.Clear(player)
	end)
end

return FishingService
