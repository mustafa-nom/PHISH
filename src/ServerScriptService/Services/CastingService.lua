--!strict
-- Owns the per-player encounter registry and handles the cast remote.
-- Bite scheduling lives in BiteService; this module just transitions
-- Idle → Casting → Waiting and then delegates.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local ZoneTiers = require(Modules:WaitForChild("ZoneTiers"))
local RodRegistry = require(Modules:WaitForChild("RodRegistry"))
local FishEncounterTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishEncounterTypes"))
local PondStateModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PondState"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local Helpers = Services:WaitForChild("Helpers")
local RemoteValidation = require(Helpers:WaitForChild("RemoteValidation"))
local DataService = require(Services:WaitForChild("DataService"))
local PondService = require(Services:WaitForChild("PondService"))
local BobberService = require(Services:WaitForChild("BobberService"))
local IntroService = require(Services:WaitForChild("IntroService"))

local CastingService = {}

local activeEncounter: { [Player]: any } = {}
local lastUnderpoweredNudge: { [Player]: number } = {}

local biteScheduler: ((Player, any) -> ())? = nil

function CastingService.SetBiteScheduler(fn: (Player, any) -> ())
	biteScheduler = fn
end

function CastingService.GetEncounter(player: Player): any?
	return activeEncounter[player]
end

function CastingService.SetEncounter(player: Player, enc: any?)
	if enc then
		activeEncounter[player] = enc
	else
		activeEncounter[player] = nil
	end
end

local function nudgeUnderpowered(player: Player, requiredTier: number, equippedTier: number)
	local now = os.clock()
	local last = lastUnderpoweredNudge[player] or 0
	if (now - last) < Constants.UNDERPOWERED_NUDGE_COOLDOWN then return end
	lastUnderpoweredNudge[player] = now
	local zoneMeta = ZoneTiers.Get(requiredTier)
	RemoteService.FireClient(player, "Notify", {
		Kind = "Info",
		Title = "Stronger rod needed",
		Text = ("This water wants a Tier %d rod. You're casting Tier %d. Visit the fisherman."):format(
			requiredTier, equippedTier),
		ZoneName = zoneMeta and zoneMeta.displayName or "this zone",
	})
end

local function handleRequestCast(player: Player, payload: any)
	local ok, _ = RemoteValidation.RequirePlayer(player)
	if not ok then return end
	if not RemoteValidation.RequireRateLimit(player, "RequestCast", Constants.RATE_LIMIT_CAST) then return end

	local existing = activeEncounter[player]
	if existing and existing.state ~= FishEncounterTypes.States.Resolved
		and existing.state ~= FishEncounterTypes.States.Idle then
		-- Already in an encounter; ignore.
		return
	end

	local zoneInfo = PondService.ResolveZoneFor(player)
	local equippedRodId = DataService.GetData(player).EquippedRodId
	local rod = RodRegistry.GetById(equippedRodId)
	local equippedTier = rod and rod.tier or 1
	local zoneMeta = ZoneTiers.Get(zoneInfo.tier)
	local requiredTier = zoneMeta and zoneMeta.requiredRodTier or 1

	if equippedTier < requiredTier then
		nudgeUnderpowered(player, requiredTier, equippedTier)
		return
	end

	local enc = PondStateModule.New(player, zoneInfo.zoneId, zoneInfo.tier, equippedRodId)
	enc.state = FishEncounterTypes.States.Waiting
	-- Lucky-bobber roll: small chance the cast surfaces a glittery lure.
	enc.luckyBobber = math.random() < Constants.LUCKY_BOBBER_CHANCE
	activeEncounter[player] = enc

	-- Sanitize payload (chargePower used as cosmetic only).
	local chargePower = 0.5
	if typeof(payload) == "table" and typeof(payload.chargePower) == "number" then
		chargePower = math.clamp(payload.chargePower, 0, 1)
	end
	local _ = chargePower

	-- Diegetic bobber. Initial color is generic until bite resolves the cue.
	BobberService.SpawnFor(player, Color3.fromRGB(255, 220, 160), enc.luckyBobber)
	if enc.luckyBobber then
		RemoteService.FireClient(player, "LuckyBobberCue", {
			EncounterId = enc.encounterId,
			Multiplier = Constants.LUCKY_BOBBER_MULTIPLIER,
		})
	end

	if biteScheduler then
		biteScheduler(player, enc)
	end

	IntroService.MaybeNudgeFirstCast(player)
end

function CastingService.Init()
	RemoteService.OnServerEvent("RequestCast", handleRequestCast)
	Players.PlayerRemoving:Connect(function(player)
		activeEncounter[player] = nil
		lastUnderpoweredNudge[player] = nil
	end)
end

return CastingService
