--!strict
-- Canonical validation chain for every remote handler. Every server
-- interaction service runs the relevant subset of these before applying
-- gameplay logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))

local Helpers = script.Parent
local RoundContext = require(Helpers:WaitForChild("RoundContext"))

local RemoteValidation = {}

local serverLimiter = RateLimiter.GetServer()

function RemoteValidation.RequirePlayer(player: Player?): (boolean, string?)
	if not player or not player.Parent then
		return false, "NoPlayer"
	end
	return true, nil
end

function RemoteValidation.RequireRound(player: Player): (boolean, string?, any?)
	local round = RoundContext.GetRound(player)
	if not round or not round.IsActive then
		return false, "NoRound", nil
	end
	return true, nil, round
end

function RemoteValidation.RequireRole(player: Player, role: string): (boolean, string?)
	if RoundContext.GetRole(player) ~= role then
		return false, "WrongRole"
	end
	return true, nil
end

function RemoteValidation.RequireExplorer(player: Player): (boolean, string?)
	return RemoteValidation.RequireRole(player, RoleTypes.Explorer)
end

function RemoteValidation.RequireGuide(player: Player): (boolean, string?)
	return RemoteValidation.RequireRole(player, RoleTypes.Guide)
end

function RemoteValidation.RequireLevelType(round: any, levelType: string): (boolean, string?)
	if RoundContext.GetActiveLevelType(round) ~= levelType then
		return false, "WrongLevel"
	end
	return true, nil
end

function RemoteValidation.RequireProximity(player: Player, target: BasePart?, maxStuds: number): (boolean, string?)
	if not target then
		return false, "TargetMissing"
	end
	local character = player.Character
	if not character then
		return false, "NoCharacter"
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "NoRoot"
	end
	local distance = (root.Position - target.Position).Magnitude
	if distance > maxStuds then
		return false, "TooFar"
	end
	return true, nil
end

function RemoteValidation.RequireRateLimit(player: Player, key: string, windowSeconds: number): (boolean, string?)
	if serverLimiter:Check(player, key, windowSeconds) then
		return true, nil
	end
	return false, "RateLimited"
end

-- Convenience: try all validators in order. Returns (true) on success or
-- (false, reason) on the first failure.
function RemoteValidation.RunChain(steps: { () -> (boolean, string?) }): (boolean, string?)
	for _, step in ipairs(steps) do
		local ok, reason = step()
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

return RemoteValidation
