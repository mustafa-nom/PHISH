--!strict
-- Guide-side rehydrate after a forced respawn / desync. Re-fires the
-- events the Scanner Guide HUD listens to so it can redraw from
-- authoritative server state (per addendum #4: server is authority; we
-- never regenerate state, only push what's already on the round).
--
-- Lives next to BeltController so it can read state.LaneLocks /
-- state.Highlight / state.ScannedTags / state.MiniBoss / state.VetoUsed
-- via the same shared LevelState table, without circular requires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent.Parent.Parent
local DataService = require(Services:WaitForChild("DataService"))

local BeltController = require(script.Parent:WaitForChild("BeltController"))

local GuideRehydrate = {}

function GuideRehydrate.RehydrateForGuide(round, player: Player)
	local state = round.LevelState[LevelTypes.BackpackCheckpoint]
	if not state then return end
	local scenario = round.ActiveScenario
	if not scenario or scenario.Type ~= LevelTypes.BackpackCheckpoint then return end

	-- Current wave info.
	local wave = scenario.Waves[scenario.CurrentWaveIndex]
	if wave then
		RemoteService.FireClient(player, "WaveStarted", {
			RoundId = round.RoundId,
			WaveIndex = scenario.CurrentWaveIndex,
			ItemCount = #wave.Items,
			BeltSpeed = wave.BeltSpeed,
			ScansAllowed = wave.ScansAllowed,
		})
	end

	-- Active item snapshot.
	if round.ActiveItemId then
		local activeInfo = BeltController.GetActiveItemInfo(round)
		if activeInfo then
			RemoteService.FireClient(player, "ConveyorItemSpawned", {
				RoundId = round.RoundId,
				ItemId = round.ActiveItemId,
				ItemKey = activeInfo.ItemKey,
				DisplayLabel = activeInfo.DisplayLabel,
				Index = scenario.CurrentItemIndex,
				Total = wave and #wave.Items or 0,
				WaveIndex = scenario.CurrentWaveIndex,
			})
			local cached = state.ScannedTags and state.ScannedTags[activeInfo.ItemKey]
			if cached then
				RemoteService.FireClient(player, "ScannerOverlayUpdated", {
					RoundId = round.RoundId,
					ItemId = round.ActiveItemId,
					ItemKey = activeInfo.ItemKey,
					Tags = cached,
					Cached = true,
					ScansUsedThisWave = state.ScansUsedThisWave or 0,
					ScansAllowedThisWave = wave and wave.ScansAllowed or 0,
				})
			end
		end
	end

	if state.LaneLocks then
		RemoteService.FireClient(player, "LaneLockUpdated", {
			RoundId = round.RoundId,
			LaneLocks = state.LaneLocks,
		})
	end

	if state.Highlight then
		RemoteService.FireClient(player, "HighlightUpdated", {
			RoundId = round.RoundId,
			ItemId = state.Highlight.ItemId,
			Color = state.Highlight.Color,
		})
	end

	if state.VetoUsed then
		RemoteService.FireClient(player, "VetoActivated", {
			RoundId = round.RoundId,
			DurationSeconds = 0,
		})
		RemoteService.FireClient(player, "VetoEnded", {
			RoundId = round.RoundId,
		})
	end

	if state.MiniBossActive and state.MiniBoss then
		local pre = {}
		for _, inner in ipairs(state.MiniBoss.InnerItems) do
			table.insert(pre, {
				ItemId = inner.Id,
				DisplayLabel = inner.DisplayLabel,
				ScanTags = inner.ScanTags,
			})
		end
		RemoteService.FireClient(player, "MiniBossStarted", {
			RoundId = round.RoundId,
			InnerCount = #state.MiniBoss.InnerItems,
			InnerItems = pre,
		})
		if state.MiniBoss.CurrentInnerIndex > 0 then
			local inner = state.MiniBoss.InnerItems[state.MiniBoss.CurrentInnerIndex]
			if inner then
				RemoteService.FireClient(player, "MiniBossInnerActivated", {
					RoundId = round.RoundId,
					InnerIndex = state.MiniBoss.CurrentInnerIndex,
					ItemId = inner.Id,
					ItemKey = inner.ItemKey,
					DisplayLabel = inner.DisplayLabel,
				})
			end
		end
	end

	-- Field Manual session-meta union for the duo.
	local explorerSeen = DataService.GetEncounteredItems(round.Explorer)
	local guideSeen = DataService.GetEncounteredItems(round.Guide)
	local union: { [string]: boolean } = {}
	for k in pairs(explorerSeen) do union[k] = true end
	for k in pairs(guideSeen) do union[k] = true end
	RemoteService.FireClient(player, "FieldManualUpdated", {
		RoundId = round.RoundId,
		Encountered = union,
	})
end

return GuideRehydrate
