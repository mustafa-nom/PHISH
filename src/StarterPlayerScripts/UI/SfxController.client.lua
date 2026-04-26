--!strict
-- Plays UI sounds in response to remote events. All sounds are loaded once
-- under SoundService for fast playback. Each remote event maps to a sound
-- with a sensible default volume from Modules/Sounds.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Sounds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Sounds"))

local soundCache: { [string]: Sound } = {}

local function buildSound(name: string, soundId: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = "Phish_" .. name
	sound.SoundId = soundId
	sound.Volume = Sounds.Volume[name] or 0.6
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	return sound
end

local function play(name: string)
	local sound = soundCache[name]
	if not sound then
		local id = (Sounds :: any)[name]
		if type(id) ~= "string" or id == "" then return end
		sound = buildSound(name, id)
		soundCache[name] = sound
	end
	-- Reset and play; cached Sound instances let multiple plays overlap via Clone.
	if sound.IsPlaying then
		local clone = sound:Clone()
		clone.Parent = SoundService
		clone:Play()
		clone.Stopped:Connect(function() clone:Destroy() end)
		task.delay(6, function() if clone and clone.Parent then clone:Destroy() end end)
	else
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Pre-warm the most-played sounds so the first cast doesn't stall.
for _, name in ipairs({ "Cast", "Splash", "Bite", "ReelTap", "Correct", "Wrong" }) do
	soundCache[name] = buildSound(name, (Sounds :: any)[name])
end

RemoteService.OnClientEvent("CastStarted", function()
	play("Cast")
end)

RemoteService.OnClientEvent("BiteOccurred", function()
	play("Splash")
	task.delay(0.15, function() play("Bite") end)
end)

RemoteService.OnClientEvent("ReelProgress", function()
	play("ReelTap")
end)

RemoteService.OnClientEvent("ReelFailed", function()
	play("ReelFail")
end)

RemoteService.OnClientEvent("ShowInspectionCard", function()
	play("CardOpen")
end)

RemoteService.OnClientEvent("DecisionResult", function(payload)
	if type(payload) ~= "table" then return end
	if payload.wasCorrect then
		play("Correct")
		if payload.species and payload.species ~= "PlainCarp" and payload.species ~= "HonestHerring" then
			task.delay(0.18, function() play("Confetti") end)
		end
	else
		play("Wrong")
	end
end)

RemoteService.OnClientEvent("PhishermanArrived", function()
	play("PhishermanArrived")
end)

RemoteService.OnClientEvent("SpeciesUnlocked", function()
	play("RareCatch")
end)

-- Local cast feedback — InspectionCardController already exists; mirror an
-- audio cue when the *player* fires RequestCast. We listen for the input
-- side-effect by hooking Notify when the cast guard fires "Walk to the dock".
-- This is intentionally a no-op for now since cast input is in another file;
-- if a CastFired remote is added later, hook it here.
