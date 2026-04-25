--!strict
-- Top-level Guide-side coordinator. Tracks role + active level so the
-- per-area controllers (manual, annotation) can react.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))

-- This controller doesn't own UI directly; it just exposes shared role/level
-- state via global table so the manual + annotation controllers can read it
-- without a circular import.

local state = {
	Role = RoleTypes.None,
	RoundId = nil :: string?,
	LevelType = nil :: string?,
}

_G.BuddyBridge_GuideState = state

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	state.Role = payload.Role or RoleTypes.None
end)

RemoteService.OnClientEvent("RoundStarted", function(payload)
	state.RoundId = payload.RoundId
end)

RemoteService.OnClientEvent("LevelStarted", function(payload)
	if payload.RoundId == state.RoundId then
		state.LevelType = payload.LevelType
	end
end)

RemoteService.OnClientEvent("LevelEnded", function(payload)
	if payload.RoundId == state.RoundId then
		state.LevelType = nil
	end
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	state.Role = RoleTypes.None
	state.RoundId = nil
	state.LevelType = nil
end)
