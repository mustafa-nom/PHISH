--!strict
-- Optional, minimal analytics. Just prints structured events for the
-- judges' Studio output panel — no external service.

local AnalyticsService = {}

local function emit(eventName: string, data: { [string]: any }?)
	local body = data and game:GetService("HttpService"):JSONEncode(data) or ""
	print(("[Analytics] %s %s"):format(eventName, body))
end

function AnalyticsService.LogRoundStarted(round)
	emit("RoundStarted", {
		RoundId = round.RoundId,
		PairId = round.PairId,
		SlotIndex = round.SlotIndex,
	})
end

function AnalyticsService.LogRoundCompleted(round, finalScore)
	emit("RoundCompleted", {
		RoundId = round.RoundId,
		Rank = finalScore.Rank,
		Mistakes = finalScore.Mistakes,
		Elapsed = finalScore.Elapsed,
		TrustPoints = finalScore.TrustPoints,
	})
end

function AnalyticsService.LogLevelEnded(round, levelType: string, summary)
	emit("LevelEnded", {
		RoundId = round.RoundId,
		LevelType = levelType,
		Summary = summary,
	})
end

function AnalyticsService.Init()
	-- Stateless module.
end

return AnalyticsService
