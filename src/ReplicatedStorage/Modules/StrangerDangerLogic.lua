--!strict
-- The new Stranger Danger gameplay model in one shared module.
--
-- Three things live here:
-- 1. Per-NPC archetype definitions: silhouette (what the Explorer sees at a
--    glance) + cue pool (what the Guide reads in their book).
-- 2. The math that turns a chosen subset of cues into a "Verdict"
--    (Approach / AskFirst / Avoid) — single signals are intentionally
--    ambiguous, combinations are decisive.
-- 3. Direction/landmark logic for the clue triangulation puzzle.
--
-- Both server (ScenarioService, ExplorerInteractionService) and client
-- (book, explorer card, clue map) require this module. Keep it pure data +
-- functions — no Roblox-instance dependencies.

local StrangerDangerLogic = {}

-- ===========================================================================
-- Verdicts and action enum
-- ===========================================================================

StrangerDangerLogic.Verdict = {
	Approach = "Approach",
	AskFirst = "AskFirst",
	Avoid = "Avoid",
}

StrangerDangerLogic.Action = {
	Approach = "Approach",
	AskFirst = "AskFirst",
	Avoid = "Avoid",
}

-- ===========================================================================
-- Cue pool. Each cue has a name, a Risk score, and Explorer/Guide text.
--   Explorer text is a flavor description ("hands hidden in pockets") that
--   shows up only AFTER the Explorer asks the Guide for a cue (AskFirst).
--   Guide text is the kid-readable manual entry that lives in the book.
--
-- Risk scores: -2 = strong red flag, -1 = soft red flag, +1 = soft green,
-- +2 = strong green. The verdict thresholds in EvaluateVerdict use the SUM.
-- ===========================================================================

export type Cue = {
	Tag: string,
	Risk: number,
	ExplorerText: string,   -- shown to Explorer when they "Ask First"
	GuideText: string,      -- shown to Guide in the book
}

StrangerDangerLogic.Cues = {
	-- Risky cues
	InsideParkedCar = {
		Tag = "InsideParkedCar",
		Risk = -2,
		ExplorerText = "Sitting inside the parked van, waving at you",
		GuideText = "Calling you over from inside a vehicle",
	},
	OfferingCandy = {
		Tag = "OfferingCandy",
		Risk = -2,
		ExplorerText = "Holding out candy or a free game item",
		GuideText = "Offering candy or 'a secret' to come closer",
	},
	WantsPrivateSpot = {
		Tag = "WantsPrivateSpot",
		Risk = -2,
		ExplorerText = "Pointing toward a quiet alley away from the crowd",
		GuideText = "Wants you somewhere private, away from people",
	},
	HoldingKnife = {
		Tag = "HoldingKnife",
		Risk = -2,
		ExplorerText = "Holding something sharp at their side",
		GuideText = "Visible weapon — sharp object in hand",
	},
	AskingPersonalInfo = {
		Tag = "AskingPersonalInfo",
		Risk = -1,
		ExplorerText = "Asking what your real name is",
		GuideText = "Asking real name, school, address",
	},
	HoodedAlone = {
		Tag = "HoodedAlone",
		Risk = -1,
		ExplorerText = "Hood pulled up, face shadowed",
		GuideText = "Hood up, face hidden, alone",
	},
	LingeringNoReason = {
		Tag = "LingeringNoReason",
		Risk = -1,
		ExplorerText = "Standing in one spot for a long time, watching",
		GuideText = "Hanging out where adults don't usually stand",
	},

	-- Safe cues
	BehindCounter = {
		Tag = "BehindCounter",
		Risk = 2,
		ExplorerText = "Standing behind a counter with a register",
		GuideText = "Behind a shop counter, working",
	},
	WearingUniform = {
		Tag = "WearingUniform",
		Risk = 2,
		ExplorerText = "Wearing a uniform with a name tag",
		GuideText = "Uniform + visible name tag",
	},
	HelpingMultipleKids = {
		Tag = "HelpingMultipleKids",
		Risk = 1,
		ExplorerText = "Helping a line of kids, not just you",
		GuideText = "Helping many people, not focused on one",
	},
	WithFamily = {
		Tag = "WithFamily",
		Risk = 1,
		ExplorerText = "Pushing a stroller / holding a kid's hand",
		GuideText = "Busy with their own family",
	},
	IgnoringYou = {
		Tag = "IgnoringYou",
		Risk = 1,
		ExplorerText = "Reading on a bench, not looking up at you",
		GuideText = "Doing their own thing, not trying to get you",
	},
	OfficerBadge = {
		Tag = "OfficerBadge",
		Risk = 2,
		ExplorerText = "Park ranger badge on their chest",
		GuideText = "Park ranger / officer badge",
	},
}

-- ===========================================================================
-- Archetypes — keyed by NPC template name (matches NpcTemplates folder).
-- Each archetype has:
--   Silhouette: { Headline, Outline (single-line shape hint), AccentColor,
--     SpotlightColor }: what the Explorer sees at a glance, in one line.
--   CuePool: list of cue tags this archetype can have.
--   RequiredCues: cues that must always be present (per anchor lock).
-- ===========================================================================

export type Silhouette = {
	Headline: string,        -- one-line description for the Explorer card
	Outline: string,         -- e.g. "Tall hooded figure", "Cheery vendor"
	AccentColor: { number },  -- {r, g, b} 0-255 — used for a colored frame
	Stance: string,          -- short pose hint
}

export type Archetype = {
	Template: string,
	BaseRisk: "Risky" | "Safe" | "Neutral",
	Silhouette: Silhouette,
	CuePool: { string },
	RequiredCues: { string }?,
	Bark: string?,            -- chat-bubble line shown when Explorer is near
}

StrangerDangerLogic.Archetypes = {
	HotDogVendor = {
		Template = "HotDogVendor",
		BaseRisk = "Safe",
		Silhouette = {
			Headline = "Cheery vendor in a red apron behind a hot dog counter",
			Outline = "Apron + paper hat",
			AccentColor = { 220, 90, 78 },
			Stance = "Behind counter, smiling",
		},
		CuePool = { "BehindCounter", "WearingUniform", "HelpingMultipleKids" },
		RequiredCues = { "BehindCounter" },
		Bark = "Fresh dogs! Come get one!",
	},
	Ranger = {
		Template = "Ranger",
		BaseRisk = "Safe",
		Silhouette = {
			Headline = "Park ranger in a green uniform with a shiny badge",
			Outline = "Ranger hat + badge",
			AccentColor = { 78, 132, 88 },
			Stance = "On patrol, scanning the park",
		},
		CuePool = { "OfficerBadge", "WearingUniform", "HelpingMultipleKids" },
		RequiredCues = { "OfficerBadge" },
		Bark = "Stay safe out there, kiddo!",
	},
	ParentWithKid = {
		Template = "ParentWithKid",
		BaseRisk = "Safe",
		Silhouette = {
			Headline = "Adult pushing a stroller, holding a small kid's hand",
			Outline = "Stroller + kid",
			AccentColor = { 132, 200, 255 },
			Stance = "Walking with family",
		},
		CuePool = { "WithFamily", "HelpingMultipleKids", "IgnoringYou" },
		RequiredCues = { "WithFamily" },
		Bark = "Hold my hand sweetie, careful crossing!",
	},
	CasualParkGoer = {
		Template = "CasualParkGoer",
		BaseRisk = "Safe",
		Silhouette = {
			Headline = "Person on a bench reading, sunglasses on",
			Outline = "Sunglasses + book",
			AccentColor = { 180, 232, 140 },
			Stance = "Sitting, reading",
		},
		CuePool = { "IgnoringYou", "WithFamily" },
		Bark = "...",
	},
	HoodedAdult = {
		Template = "HoodedAdult",
		BaseRisk = "Risky",
		Silhouette = {
			Headline = "Tall figure with a black hood up, face shadowed",
			Outline = "Hood + dark cloak",
			AccentColor = { 60, 60, 64 },
			Stance = "Standing alone, hands hidden",
		},
		CuePool = { "HoodedAlone", "LingeringNoReason", "WantsPrivateSpot" },
		RequiredCues = { "HoodedAlone" },
		Bark = "Hey kid... come over here a sec.",
	},
	VehicleLeaner = {
		Template = "VehicleLeaner",
		BaseRisk = "Risky",
		Silhouette = {
			Headline = "Adult leaning out of a parked white van's open door",
			Outline = "Sunglasses + van",
			AccentColor = { 236, 110, 110 },
			Stance = "Leaning out a vehicle",
		},
		CuePool = { "InsideParkedCar", "OfferingCandy", "AskingPersonalInfo" },
		RequiredCues = { "InsideParkedCar" },
		Bark = "Want some candy? Hop in!",
	},
	KnifeArchetype = {
		Template = "KnifeArchetype",
		BaseRisk = "Risky",
		Silhouette = {
			Headline = "Tense figure in a dark hood holding something at their side",
			Outline = "Hood + something sharp",
			AccentColor = { 40, 40, 48 },
			Stance = "Tense, weapon visible",
		},
		CuePool = { "HoldingKnife", "HoodedAlone", "WantsPrivateSpot", "LingeringNoReason" },
		RequiredCues = { "HoldingKnife" },
		Bark = "...",
	},
}

-- ===========================================================================
-- EvaluateVerdict — sums up the cue risk scores and returns a verdict.
-- This is the math the Explorer's Approach choice is graded against.
-- Single-signal NPCs (1 cue) tend to land in AskFirst on purpose.
-- ===========================================================================

function StrangerDangerLogic.EvaluateVerdict(cueTags: { string }): string
	local total = 0
	local count = 0
	for _, tag in ipairs(cueTags) do
		local cue = StrangerDangerLogic.Cues[tag]
		if cue then
			total += cue.Risk
			count += 1
		end
	end
	-- thresholds: ≤ -3 = Avoid, ≥ +3 = Approach, otherwise AskFirst.
	-- single-signal NPCs (count == 1) are always AskFirst regardless of
	-- magnitude — the design forces communication on weak evidence.
	if count <= 1 then
		return StrangerDangerLogic.Verdict.AskFirst
	end
	if total <= -3 then
		return StrangerDangerLogic.Verdict.Avoid
	end
	if total >= 3 then
		return StrangerDangerLogic.Verdict.Approach
	end
	return StrangerDangerLogic.Verdict.AskFirst
end

-- ===========================================================================
-- Direction / landmark fragments for clue triangulation.
-- The puppy hides at one of 5 landmarks. Safe NPCs give a TRUTHFUL fragment
-- that points toward the right landmark; Risky NPCs give a MISLEADING
-- fragment that points away. Three correct fragments triangulate it.
-- ===========================================================================

StrangerDangerLogic.Landmarks = {
	"fountain",
	"playground",
	"alley",
	"bench",
	"hotdog",
	"ranger",
}

StrangerDangerLogic.LandmarkDisplay = {
	fountain = "the fountain",
	playground = "the playground slide",
	alley = "the alley by the shop",
	bench = "the park bench",
	hotdog = "the hot dog stand",
	ranger = "the ranger booth",
}

local TRUTHFUL_TEMPLATES = {
	"I saw a fluffy puppy near %s.",
	"A small dog ran toward %s a few minutes ago.",
	"Heard a tiny bark coming from %s.",
	"Tail wagging spotted by %s.",
	"Pawprints lead to %s.",
}

local MISLEADING_TEMPLATES = {
	"That dog you're after? Definitely went past %s.",
	"I'd check %s. Trust me.",
	"Pretty sure your puppy's hiding near %s. Hop in and I'll show you.",
}

local function pickFrom<T>(list: { T }): T
	return list[math.random(1, #list)]
end

function StrangerDangerLogic.MakeTruthfulFragment(landmark: string): string
	local template = pickFrom(TRUTHFUL_TEMPLATES)
	return string.format(template, StrangerDangerLogic.LandmarkDisplay[landmark] or landmark)
end

function StrangerDangerLogic.MakeMisleadingFragment(realLandmark: string): string
	-- pick a different landmark to point at
	local options = {}
	for _, lm in ipairs(StrangerDangerLogic.Landmarks) do
		if lm ~= realLandmark then
			table.insert(options, lm)
		end
	end
	local fake = pickFrom(options)
	local template = pickFrom(MISLEADING_TEMPLATES)
	return string.format(template, StrangerDangerLogic.LandmarkDisplay[fake] or fake)
end

-- ===========================================================================
-- PickCues — given an archetype, draw 3 cues from its pool. RequiredCues
-- come first; remainder are random from the pool.
-- ===========================================================================

local function shuffleInPlace<T>(list: { T })
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

function StrangerDangerLogic.PickCues(archetypeName: string, count: number): { string }
	local archetype = StrangerDangerLogic.Archetypes[archetypeName]
	if not archetype then return {} end
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	if archetype.RequiredCues then
		for _, tag in ipairs(archetype.RequiredCues) do
			if not seen[tag] and StrangerDangerLogic.Cues[tag] then
				table.insert(result, tag)
				seen[tag] = true
			end
		end
	end
	local pool = table.clone(archetype.CuePool)
	shuffleInPlace(pool)
	for _, tag in ipairs(pool) do
		if #result >= count then break end
		if not seen[tag] then
			table.insert(result, tag)
			seen[tag] = true
		end
	end
	return result
end

-- ===========================================================================
-- Result types — what the Explorer's three actions resolve to. Used by
-- ExplorerInteractionService when grading the action.
-- ===========================================================================

StrangerDangerLogic.ActionResult = {
	-- Approach a SafeWithClue NPC successfully
	ClueGranted = "ClueGranted",
	-- Approach a Risky NPC -> consequence
	RiskyConsequence = "RiskyConsequence",
	-- Approach a SafeNoClue
	NoClueChat = "NoClueChat",
	-- AskFirst -> Guide reveals one more cue
	CueRevealed = "CueRevealed",
	-- Avoid -> safe, no progress
	AvoidedSafely = "AvoidedSafely",
	-- Avoid a SafeWithClue -> missed opportunity (no penalty)
	MissedClue = "MissedClue",
}

return StrangerDangerLogic
