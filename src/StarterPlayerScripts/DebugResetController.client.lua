--!strict
-- Dev shortcut: pressing the `[` key fires RequestResetProfile, which
-- the server handles by wiping the player's DataStore profile and
-- kicking them so the next rejoin starts fresh. No confirmation
-- prompt — this is intended for hackathon iteration, not production.
-- Filters out keystrokes that came from a focused TextBox / chat input.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftBracket then
		RemoteService.FireServer("RequestResetProfile")
	end
end)
