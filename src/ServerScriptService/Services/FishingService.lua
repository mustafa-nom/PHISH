--!strict
-- Cast → Bite → Reel pipeline. Holds per-player state so DecisionService can
-- only resolve when the player is actually inspecting a card.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Workspace = game:GetService("Workspace")

local Services = script.Parent
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))
local SignalTracker = require(Helpers:WaitForChild("SignalTracker"))

local TIER_NAMES = { "Beginner", "Intermediate", "Expert", "Legendary" }

export type State = "Idle" | "Waiting" | "Biting" | "Reeling" | "Inspecting"

local FishingService = {}

local stateByPlayer: { [Player]: State } = {}
local reelCountByPlayer: { [Player]: number } = {}
local timerThreadByPlayer: { [Player]: thread } = {}
local waterDifficultyByPlayer: { [Player]: number } = {}

local function setState(player: Player, s: State)
	stateByPlayer[player] = s
end

function FishingService.GetState(player: Player): State
	return stateByPlayer[player] or "Idle"
end

function FishingService.SetIdle(player: Player)
	setState(player, "Idle")
	reelCountByPlayer[player] = 0
	waterDifficultyByPlayer[player] = nil
	local t = timerThreadByPlayer[player]
	if t then task.cancel(t); timerThreadByPlayer[player] = nil end
end

-- Find the water tile sitting at this aim position. Casts a short ray straight
-- down through the water folder so we only ever match PhishWater tiles (not
-- boats, NPCs, etc.). Returns the tile or nil if the click wasn't on water.
local function tileAt(aim: Vector3): BasePart?
	local map = Workspace:FindFirstChild("PhishMap")
	local waterFolder = map and map:FindFirstChild("PhishWater")
	if not waterFolder then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { waterFolder }
	params.IgnoreWater = true
	local origin = Vector3.new(aim.X, aim.Y + 60, aim.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -200, 0), params)
	if result and result.Instance and CollectionService:HasTag(result.Instance, PhishConstants.Tags.WaterZone) then
		return result.Instance
	end
	return nil
end

local function scheduleBite(player: Player)
	local wait_ = math.random() * (PhishConstants.BITE_MAX_WAIT_SECONDS - PhishConstants.BITE_MIN_WAIT_SECONDS)
		+ PhishConstants.BITE_MIN_WAIT_SECONDS
	timerThreadByPlayer[player] = task.delay(wait_, function()
		if FishingService.GetState(player) ~= "Waiting" then return end
		setState(player, "Biting")
		-- Client shows green "Reel it in" button; one RequestReelTap (by default) lands the card
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

local function onCast(player: Player, clientAim: any)
	local ok, _ = RemoteValidation.RunChain({
		function() return RemoteValidation.RequirePlayer(player) end,
		function() return RemoteValidation.RequireRateLimit(player, "Cast", PhishConstants.RATE_LIMIT_CAST) end,
	})
	if not ok then return end
	if FishingService.GetState(player) ~= "Idle" then return end

	-- Cast input must include a Vector3 aim (the client's mouse target).
	if typeof(clientAim) ~= "Vector3" then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Aim at the water and click to cast." })
		return
	end

	-- Validate the click landed on a water tile.
	local tile = tileAt(clientAim)
	if not tile then
		RemoteService.FireClient(player, "Notify", { kind = "Error", message = "Aim at the water — that spot isn't fishable." })
		return
	end

	-- Validate the player's rod is strong enough for this water's tier.
	local minTier = tile:GetAttribute("MinRodTier") or 1
	local profile = DataService.Get(player)
	local rodTier = profile.rodTier or 1
	if rodTier < minTier then
		local need = TIER_NAMES[minTier] or ("tier " .. tostring(minTier))
		RemoteService.FireClient(player, "Notify", {
			kind = "Error",
			message = string.format("This is %s water — you need a stronger rod.", need),
		})
		return
	end

	-- Snap the landing Y to the water surface (tile top is roughly y = 0.5).
	local landing = Vector3.new(clientAim.X, 0.5, clientAim.Z)
	local waterDifficulty = tile:GetAttribute("Difficulty") or minTier
	if type(waterDifficulty) ~= "number" then waterDifficulty = minTier end
	waterDifficultyByPlayer[player] = math.clamp(math.floor(waterDifficulty), 1, 5)
	setState(player, "Waiting")
	RemoteService.FireClient(player, "CastStarted", {
		aim = landing,
		biome = tile:GetAttribute("Biome"),
		difficulty = waterDifficultyByPlayer[player],
	})
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
		local card = CardService.PickAndArm(player, waterDifficultyByPlayer[player])
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
