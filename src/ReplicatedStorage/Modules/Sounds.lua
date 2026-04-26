--!strict
-- Audio asset IDs for PHISH. Centralized so SfxController doesn't have to
-- carry magic asset IDs and so writers can swap a sound by editing one row.
--
-- We intentionally use only built-in `rbxasset://` paths that ship with
-- every Roblox client — no asset-ID lookups, no licensing, no "Asset type
-- does not match requested type" load failures. If a row has an empty
-- string, SfxController treats that event as silent (graceful no-op).
-- Drop in real `rbxassetid://...` ids when art passes them.

local Sounds = {}

-- Verified working built-in paths (Roblox dropped bell.wav and a few others
-- so we route everything that previously used bell.wav through snap.mp3).
Sounds.Cast       = "rbxasset://sounds/swordlunge.wav"
Sounds.Splash     = "rbxasset://sounds/impact_water.mp3"
Sounds.Bite       = "rbxasset://sounds/electronicpingshort.wav"
Sounds.ReelTap    = "rbxasset://sounds/clickfast.wav"
Sounds.ReelFail   = "rbxasset://sounds/uuhhh.mp3"
Sounds.CardOpen   = "rbxasset://sounds/electronicpingshort.wav"
Sounds.Correct    = "rbxasset://sounds/snap.mp3"
Sounds.Wrong      = "rbxasset://sounds/bass.wav"
Sounds.Confetti   = "rbxasset://sounds/snap.mp3"
Sounds.RareCatch  = "rbxasset://sounds/snap.mp3"
Sounds.PhishermanArrived = "rbxasset://sounds/bass.wav"
Sounds.TutorialPing = "rbxasset://sounds/electronicpingshort.wav"

Sounds.Volume = {
	Cast = 0.55,
	Splash = 0.55,
	Bite = 0.5,
	ReelTap = 0.4,
	ReelFail = 0.55,
	CardOpen = 0.4,
	Correct = 0.65,
	Wrong = 0.55,
	Confetti = 0.6,
	RareCatch = 0.75,
	PhishermanArrived = 0.65,
	TutorialPing = 0.5,
}

return Sounds
