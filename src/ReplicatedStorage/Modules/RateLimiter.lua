--!strict
-- Per-player, per-key rate limiter. Used both server-side (validation) and
-- client-side (UI throttle).
-- Usage:
--   local limiter = RateLimiter.new()
--   if not limiter:Check(player, "Inspect", 0.5) then return end

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: {
	_lastCall: { [Player]: { [string]: number } },
}, RateLimiter))

function RateLimiter.new(): RateLimiter
	return setmetatable({ _lastCall = {} }, RateLimiter) :: any
end

-- Returns true if the call is allowed (and records it). False if too soon.
function RateLimiter.Check(self: RateLimiter, player: Player, key: string, windowSeconds: number): boolean
	local now = os.clock()
	local perPlayer = self._lastCall[player]
	if not perPlayer then
		perPlayer = {}
		self._lastCall[player] = perPlayer
	end
	local last = perPlayer[key]
	if last and (now - last) < windowSeconds then
		return false
	end
	perPlayer[key] = now
	return true
end

function RateLimiter.Clear(self: RateLimiter, player: Player)
	self._lastCall[player] = nil
end

-- Process-shared limiter so client and server can each spin up one without
-- threading it through every controller.
local sharedServer: RateLimiter? = nil
local sharedClient: RateLimiter? = nil

function RateLimiter.GetServer(): RateLimiter
	if not sharedServer then
		sharedServer = RateLimiter.new()
	end
	return sharedServer :: RateLimiter
end

function RateLimiter.GetClient(): RateLimiter
	if not sharedClient then
		sharedClient = RateLimiter.new()
	end
	return sharedClient :: RateLimiter
end

return RateLimiter
