--!strict
-- Owns the once-per-session cold-open slide and the first-cast tutorial
-- nudge. Both gated through DataService.HasSeenTutorial.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local IntroService = {}

local INTRO_KEY = "PhishIntroSlide"
local FIRST_CAST_KEY = "PhishFirstCast"

local function showIntro(player: Player)
	if DataService.HasSeenTutorial(player, INTRO_KEY) then return end
	RemoteService.FireClient(player, "ShowIntroSlide", {
		Lines = {
			"You grew up safe.",
			"Someone watched out for you.",
			"Now you're the watchout.",
		},
		FrameLines = {
			{ left = "Internet", right = "Ocean" },
			{ left = "Scams",    right = "Fish" },
			{ left = "You",      right = "Angler" },
		},
		ButtonText = "Cast a line",
		AutoDismissSec = 8,
	})
	DataService.MarkTutorialSeen(player, INTRO_KEY)
end

function IntroService.MaybeNudgeFirstCast(player: Player)
	if DataService.HasSeenTutorial(player, FIRST_CAST_KEY) then return end
	RemoteService.FireClient(player, "TutorialNudge", {
		Title = "Watch the bobber",
		Text = "When it dips, you've got a bite. Decide fast: Verify, Reel, Cut, Report, or Release.",
		DurationSec = 7,
	})
	DataService.MarkTutorialSeen(player, FIRST_CAST_KEY)
end

function IntroService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		if player.Parent then showIntro(player) end
	end)
end

return IntroService
