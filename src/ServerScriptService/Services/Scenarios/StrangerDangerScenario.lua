--!strict
-- Generates a randomized scenario for Stranger Danger Park.
--
-- Each spawn point gets:
-- - an Archetype (which NPC template to clone there) chosen via the anchor's
--   bias toward Risky vs Safe
-- - a Role (Risky / SafeWithClue / SafeNoClue) decided after archetype
-- - 1-3 visible Cues drawn from the archetype's cue pool, full info for the
--   Guide's book
-- - a Silhouette (the one-line "what does the Explorer see at a glance")
-- - optional Fragment: truthful (safe) or misleading (risky) puppy clue
--
-- The Explorer never receives Cues directly — only Silhouette. Asymmetric
-- info is enforced server-side by ExplorerInteractionService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local StrangerDangerLogic = require(Modules:WaitForChild("StrangerDangerLogic"))

local ScenarioTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScenarioTypes"))

local StrangerDangerScenario = {}

-- archetype catalog grouped by base risk so we can match anchor bias to
-- archetype options. one archetype per NPC template the map generator
-- builds. (kept in this file rather than the Logic module because the
-- *catalog* is server-authoritative — clients only need cue text/silhouettes.)
local SAFE_ARCHETYPES = { "HotDogVendor", "Ranger", "ParentWithKid", "CasualParkGoer" }
local RISKY_ARCHETYPES = { "VehicleLeaner", "HoodedAdult", "KnifeArchetype" }

-- anchor → preferred archetype map. when an anchor strongly fits a specific
-- archetype, use it directly; falls back to risk-pool random pick otherwise.
local ANCHOR_FAVORITES = {
	HotdogShop = { Safe = "HotDogVendor" },
	GeneralStore = { Safe = "Ranger" },
	WhiteVan = { Risky = "VehicleLeaner" },
	AlleyMouth = { Risky = "KnifeArchetype" },
	NorthSidewalk = { Safe = "ParentWithKid" },
	SouthSidewalk = { Safe = "CasualParkGoer" },
	EastSidewalk = { Safe = "ParentWithKid", Risky = "HoodedAdult" },
	WestSidewalk = { Safe = "CasualParkGoer", Risky = "HoodedAdult" },
}

local ANCHOR_RISK_BIAS = {
	HotdogShop = { Risky = 0, Safe = 5 },
	GeneralStore = { Risky = 0, Safe = 5 },
	WhiteVan = { Risky = 5, Safe = 0 },
	AlleyMouth = { Risky = 5, Safe = 0 },
	NorthSidewalk = { Risky = 1, Safe = 3 },
	SouthSidewalk = { Risky = 1, Safe = 3 },
	EastSidewalk = { Risky = 2, Safe = 3 },
	WestSidewalk = { Risky = 2, Safe = 3 },
}

local function shuffle<T>(list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = math.random(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

local function pickFromList<T>(list: { T }): T?
	if #list == 0 then return nil end
	return list[math.random(#list)]
end

local function gatherSpawnPoints(levelModel: Model)
	local result = {}
	for _, part in ipairs(TagQueries.GetTaggedInside(levelModel, PlayAreaConfig.Tags.BuddyNpcSpawn)) do
		if part:IsA("BasePart") then
			local id = part:GetAttribute(PlayAreaConfig.Attributes.NpcSpawnId)
			if typeof(id) ~= "string" then id = part:GetFullName() end
			local anchor = part:GetAttribute(PlayAreaConfig.Attributes.Anchor)
			if typeof(anchor) ~= "string" then anchor = nil end
			table.insert(result, { Spawn = part, Id = id, Anchor = anchor })
		end
	end
	return result
end

-- pick risk classification per spawn. force at least 3 SafeWithClue slots
-- so triangulation always has 3 truthful fragments to hand out. ensure at
-- least 1 Risky so the Guide has something to flag.
local function assignRoles(spawns)
	local count = #spawns
	local indexed = {}
	for i, spawn in ipairs(spawns) do
		local bias = spawn.Anchor and ANCHOR_RISK_BIAS[spawn.Anchor] or { Risky = 1, Safe = 1 }
		local riskyScore = (bias.Risky or 0) + math.random()
		table.insert(indexed, { Index = i, RiskyScore = riskyScore })
	end
	table.sort(indexed, function(a, b) return a.RiskyScore > b.RiskyScore end)

	local target = {}
	target.SafeWithClue = math.min(Constants.CLUES_TO_FIND, math.max(1, count - 3))
	target.Risky = math.max(2, math.floor(count * 0.35))
	target.SafeNoClue = math.max(0, count - target.SafeWithClue - target.Risky)
	while target.SafeWithClue + target.SafeNoClue + target.Risky > count do
		if target.SafeNoClue > 0 then target.SafeNoClue -= 1
		elseif target.Risky > 1 then target.Risky -= 1
		else target.SafeWithClue -= 1 end
	end
	while target.SafeWithClue + target.SafeNoClue + target.Risky < count do
		target.SafeNoClue += 1
	end

	local roles = table.create(count, "")
	for i = 1, target.Risky do
		roles[indexed[i].Index] = ScenarioTypes.NpcRoles.Risky
	end
	for i = target.Risky + 1, target.Risky + target.SafeWithClue do
		roles[indexed[i].Index] = ScenarioTypes.NpcRoles.SafeWithClue
	end
	for i = target.Risky + target.SafeWithClue + 1, count do
		roles[indexed[i].Index] = ScenarioTypes.NpcRoles.SafeNoClue
	end
	return roles
end

local function pickArchetype(role: string, anchor: string?): string
	-- prefer the anchor's favorite for this risk side
	local riskKey = role == ScenarioTypes.NpcRoles.Risky and "Risky" or "Safe"
	if anchor then
		local fav = ANCHOR_FAVORITES[anchor]
		if fav and fav[riskKey] then
			return fav[riskKey]
		end
	end
	local pool = role == ScenarioTypes.NpcRoles.Risky and RISKY_ARCHETYPES or SAFE_ARCHETYPES
	return pickFromList(pool) or pool[1]
end

local function pickPuppyLandmarkAndSpawn(levelModel: Model): (string, string)
	local landmarks = StrangerDangerLogic.Landmarks
	local landmark = landmarks[math.random(#landmarks)]
	local candidates = TagQueries.GetTaggedInside(levelModel, PlayAreaConfig.Tags.PuppySpawn)
	if #candidates == 0 then return landmark, "" end
	local choice = candidates[math.random(#candidates)]
	if not choice:IsA("BasePart") then return landmark, "" end
	choice:SetAttribute("BB_PuppyChosen", true)
	choice:SetAttribute("BB_PuppyLandmark", landmark)
	return landmark, choice:GetFullName()
end

function StrangerDangerScenario.Generate(levelModel: Model): any?
	if not levelModel then return nil end
	local spawns = gatherSpawnPoints(levelModel)
	if #spawns < 3 then
		warn("StrangerDangerScenario: fewer than 3 BuddyNpcSpawn parts in level")
		return nil
	end

	local roles = assignRoles(spawns)
	local landmark, puppySpawnId = pickPuppyLandmarkAndSpawn(levelModel)

	local npcs: { any } = {}
	for i, spawn in ipairs(spawns) do
		local role = roles[i]
		local archetype = pickArchetype(role, spawn.Anchor)
		local archetypeData = StrangerDangerLogic.Archetypes[archetype]
		local cueCount = math.random(2, 3)
		local cues = StrangerDangerLogic.PickCues(archetype, cueCount)
		local verdict = StrangerDangerLogic.EvaluateVerdict(cues)

		-- truthful fragments come from any safe NPC; misleading fragments
		-- come from risky NPCs. SafeNoClue gets nothing.
		local fragment: any? = nil
		if role == ScenarioTypes.NpcRoles.SafeWithClue then
			fragment = {
				Truthful = true,
				Landmark = landmark,
				Text = StrangerDangerLogic.MakeTruthfulFragment(landmark),
			}
		elseif role == ScenarioTypes.NpcRoles.Risky then
			fragment = {
				Truthful = false,
				Landmark = landmark,
				Text = StrangerDangerLogic.MakeMisleadingFragment(landmark),
			}
		end

		local silhouette = archetypeData and archetypeData.Silhouette or {
			Headline = "Someone in the park",
			Outline = "Person",
			AccentColor = { 200, 200, 200 },
			Stance = "Standing",
		}

		table.insert(npcs, {
			Id = string.format("npc_%d", i),
			SpawnPointId = spawn.Id,
			Anchor = spawn.Anchor,
			Archetype = archetype,
			Role = role,
			Silhouette = silhouette,
			Cues = cues,
			Verdict = verdict,
			Fragment = fragment,
			Bark = archetypeData and archetypeData.Bark,
			-- legacy mirrors
			Traits = cues,
			ClueText = fragment and fragment.Text,
		})
	end

	-- guide manual now lists every cue tag (the book has its own structure)
	local riskyTags, safeTags = {}, {}
	for tag, cue in pairs(StrangerDangerLogic.Cues) do
		if cue.Risk < 0 then
			table.insert(riskyTags, tag)
		else
			table.insert(safeTags, tag)
		end
	end

	return {
		Type = LevelTypes.StrangerDangerPark,
		PuppySpawnId = puppySpawnId,
		PuppyLandmark = landmark,
		Npcs = npcs,
		GuideManual = {
			RiskyTags = riskyTags,
			SafeTags = safeTags,
		},
		Annotations = {},
	}
end

return StrangerDangerScenario
