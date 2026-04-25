--!strict
-- Generates a randomized scenario for Stranger Danger Park.
-- Inputs: the cloned level's NPC spawn parts (with Anchor + NpcSpawnId
-- attributes) and the puppy spawn candidates.
-- Outputs: a StrangerDangerScenario per docs/TECHNICAL_DESIGN.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NpcRegistry = require(Modules:WaitForChild("NpcRegistry"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local Constants = require(Modules:WaitForChild("Constants"))
local TagQueries = require(Modules:WaitForChild("TagQueries"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))

local ScenarioTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScenarioTypes"))

local StrangerDangerScenario = {}

local function shuffle<T>(list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = math.random(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

local function pickRandom<T>(list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[math.random(#list)]
end

local function pickRoleByAnchorBias(anchor: string?): string
	local biases = anchor and NpcRegistry.AnchorBias[anchor] or nil
	local riskyWeight = 1
	local safeWeight = 1
	if biases then
		riskyWeight = biases.Risky or 1
		safeWeight = biases.Safe or 1
	end
	local total = riskyWeight + safeWeight
	if math.random() * total < riskyWeight then
		return ScenarioTypes.NpcRoles.Risky
	end
	return ScenarioTypes.NpcRoles.SafeWithClue
end

local function drawTraitsForNpc(role: string, anchor: string?): { string }
	local pool: { string }
	if role == ScenarioTypes.NpcRoles.Risky then
		pool = NpcRegistry.GetTagsByRisk(NpcRegistry.Risk.Risky)
	else
		pool = NpcRegistry.GetTagsByRisk(NpcRegistry.Risk.Safe)
	end

	-- Anchor-required traits first
	local traits: { string } = {}
	local seen: { [string]: boolean } = {}
	if anchor and NpcRegistry.AnchorRequiredTraits[anchor] then
		local section = NpcRegistry.AnchorRequiredTraits[anchor]
		local roleSection = nil
		if role == ScenarioTypes.NpcRoles.Risky then
			roleSection = section.Risky
		else
			roleSection = section.Safe
		end
		if roleSection then
			for _, tag in ipairs(roleSection) do
				if NpcRegistry.Traits[tag] and not seen[tag] then
					table.insert(traits, tag)
					seen[tag] = true
				end
			end
		end
	end

	-- Fill remaining 1–3 traits from the pool
	local target = math.random(1, 3)
	if #traits >= target then
		return traits
	end
	local shuffled = shuffle(pool)
	for _, tag in ipairs(shuffled) do
		if not seen[tag] then
			table.insert(traits, tag)
			seen[tag] = true
			if #traits >= target then
				break
			end
		end
	end
	return traits
end

local function gatherSpawnPoints(levelModel: Model): { { Spawn: BasePart, Id: string, Anchor: string? } }
	local result = {}
	for _, part in ipairs(TagQueries.GetTaggedInside(levelModel, PlayAreaConfig.Tags.BuddyNpcSpawn)) do
		if part:IsA("BasePart") then
			local id = part:GetAttribute(PlayAreaConfig.Attributes.NpcSpawnId)
			if typeof(id) ~= "string" then
				id = part:GetFullName()
			end
			local anchor = part:GetAttribute(PlayAreaConfig.Attributes.Anchor)
			if typeof(anchor) ~= "string" then
				anchor = nil
			end
			table.insert(result, { Spawn = part, Id = id, Anchor = anchor })
		end
	end
	return result
end

-- Decide each spawn's role:
-- 3 SafeWithClue, 2 SafeNoClue, remaining = Risky.
-- Anchor bias drives which spawns *prefer* which role.
local function assignRoles(spawns: { { Spawn: BasePart, Id: string, Anchor: string? } }): { string }
	local roles: { string } = table.create(#spawns, "")

	local order = shuffle({ table.unpack({}) })  -- placeholder
	-- build an ordered list of indices sorted by "risky preference" desc
	local indexed: { { Index: number, RiskyScore: number } } = {}
	for i, spawn in ipairs(spawns) do
		local score = 0
		if spawn.Anchor and NpcRegistry.AnchorBias[spawn.Anchor] then
			score = NpcRegistry.AnchorBias[spawn.Anchor].Risky or 0
		end
		table.insert(indexed, { Index = i, RiskyScore = score + math.random() })
	end
	table.sort(indexed, function(a, b)
		return a.RiskyScore > b.RiskyScore
	end)

	local total = #spawns
	local safeWithClueCount = math.min(Constants.CLUES_TO_FIND, math.max(1, total - 2))
	local riskyCount = math.max(1, math.floor(total * 0.35))
	if total >= 7 then
		riskyCount = math.max(2, riskyCount)
	end
	local safeNoClueCount = math.max(0, total - safeWithClueCount - riskyCount)
	-- Reconcile if rounding pushed us over
	while safeWithClueCount + safeNoClueCount + riskyCount > total do
		if safeNoClueCount > 0 then
			safeNoClueCount -= 1
		elseif riskyCount > 1 then
			riskyCount -= 1
		else
			safeWithClueCount -= 1
		end
	end
	while safeWithClueCount + safeNoClueCount + riskyCount < total do
		safeNoClueCount += 1
	end

	-- First N indices (highest RiskyScore) → Risky
	for i = 1, riskyCount do
		roles[indexed[i].Index] = ScenarioTypes.NpcRoles.Risky
	end
	-- Then SafeWithClue
	for i = riskyCount + 1, riskyCount + safeWithClueCount do
		roles[indexed[i].Index] = ScenarioTypes.NpcRoles.SafeWithClue
	end
	-- Remaining → SafeNoClue
	for i = riskyCount + safeWithClueCount + 1, #spawns do
		roles[indexed[i].Index] = ScenarioTypes.NpcRoles.SafeNoClue
	end
	return roles
end

local function pickPuppySpawnId(levelModel: Model): string?
	local candidates = TagQueries.GetTaggedInside(levelModel, PlayAreaConfig.Tags.PuppySpawn)
	if #candidates == 0 then
		return nil
	end
	local choice = candidates[math.random(#candidates)]
	if not choice:IsA("BasePart") then
		return nil
	end
	choice:SetAttribute("BB_PuppyChosen", true)
	return choice:GetFullName()
end

local function buildClueFragments(count: number): { string }
	local pool = table.clone(NpcRegistry.ClueFragments)
	local result: { string } = {}
	for _ = 1, count do
		if #pool == 0 then
			break
		end
		local idx = math.random(#pool)
		table.insert(result, pool[idx])
		table.remove(pool, idx)
	end
	return result
end

function StrangerDangerScenario.Generate(levelModel: Model): ScenarioTypes.StrangerDangerScenario?
	if not levelModel then
		return nil
	end
	local spawns = gatherSpawnPoints(levelModel)
	if #spawns < 3 then
		warn("StrangerDangerScenario: fewer than 3 BuddyNpcSpawn parts in level — cannot generate")
		return nil
	end
	local roles = assignRoles(spawns)

	local clueTexts = buildClueFragments(Constants.CLUES_TO_FIND)
	local clueIndex = 1

	local npcs: { ScenarioTypes.StrangerDangerNpc } = {}
	for i, spawn in ipairs(spawns) do
		local role = roles[i]
		local traits = drawTraitsForNpc(role, spawn.Anchor)
		local clueText: string? = nil
		if role == ScenarioTypes.NpcRoles.SafeWithClue then
			clueText = clueTexts[clueIndex]
			clueIndex += 1
		end
		table.insert(npcs, {
			Id = string.format("npc_%d", i),
			SpawnPointId = spawn.Id,
			Anchor = spawn.Anchor,
			Role = role,
			Traits = traits,
			ClueText = clueText,
		})
	end

	local riskyTags = NpcRegistry.GetTagsByRisk(NpcRegistry.Risk.Risky)
	local safeTags = NpcRegistry.GetTagsByRisk(NpcRegistry.Risk.Safe)

	local scenario: ScenarioTypes.StrangerDangerScenario = {
		Type = LevelTypes.StrangerDangerPark,
		PuppySpawnId = pickPuppySpawnId(levelModel) or "",
		Npcs = npcs,
		GuideManual = {
			RiskyTags = riskyTags,
			SafeTags = safeTags,
		},
		Annotations = {},
	}
	return scenario
end

return StrangerDangerScenario
