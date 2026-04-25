--!strict
-- Tracks RBXScriptConnections against a Round's lifetime. Every server
-- service should route its connections through this so EndRound can reliably
-- clean up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoundState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoundState"))

type Round = RoundState.Round

local SignalTracker = {}

-- Connect `signal:Connect(handler)` and register the resulting connection
-- against the round so it disconnects on round end.
function SignalTracker.Track(round: Round, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(handler)
	RoundState.AddConnection(round, connection)
	return connection
end

-- Track an already-existing connection.
function SignalTracker.Adopt(round: Round, connection: RBXScriptConnection)
	RoundState.AddConnection(round, connection)
end

return SignalTracker
