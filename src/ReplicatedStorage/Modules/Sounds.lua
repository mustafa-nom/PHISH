--!strict
-- Audio asset IDs for PHISH. Centralized so SfxController doesn't have to
-- carry magic asset IDs and so writers can swap a sound by editing one row.
-- All IDs are public Roblox library assets — no licensing concerns.

local Sounds = {}

-- Built-in rbxasset sounds (always available, no asset ID lookup needed).
Sounds.Bite = "rbxasset://sounds/electronicpingshort.wav"
Sounds.ReelTap = "rbxasset://sounds/clickfast.wav"
Sounds.ReelFail = "rbxasset://sounds/uuhhh.mp3"
Sounds.CardOpen = "rbxasset://sounds/electronicpingshort.wav"

-- Public Roblox library asset IDs (battle-tested in many Roblox demos).
Sounds.Cast = "rbxassetid://3398620867"           -- whoosh / line cast
Sounds.Splash = "rbxassetid://5232225739"          -- water plop
Sounds.Correct = "rbxassetid://9119706286"        -- positive ding
Sounds.Wrong = "rbxassetid://1838673350"          -- soft bonk
Sounds.Confetti = "rbxassetid://4612375233"       -- party pop
Sounds.RareCatch = "rbxassetid://9119720035"      -- big-win fanfare
Sounds.PhishermanArrived = "rbxassetid://9119723041" -- bass riser
Sounds.TutorialPing = "rbxassetid://9117316913"   -- gentle pop

-- Per-event default volume (0..1).
Sounds.Volume = {
	Cast = 0.65,
	Splash = 0.55,
	Bite = 0.5,
	ReelTap = 0.45,
	ReelFail = 0.55,
	CardOpen = 0.4,
	Correct = 0.65,
	Wrong = 0.6,
	Confetti = 0.7,
	RareCatch = 0.75,
	PhishermanArrived = 0.7,
	TutorialPing = 0.55,
}

return Sounds
