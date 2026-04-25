--!strict
-- NPC trait pool for Stranger Danger Park.
-- Traits are drawn from these pools by ScenarioService at level start.
--
-- Tag is the canonical id stored on scenario NPCs (do NOT translate); both
-- Explorer and Guide UIs render DisplayText. The Guide manual cross-references
-- by Risk classification.

local NpcRegistry = {}

NpcRegistry.Risk = {
	Risky = "Risky",
	Safe = "Safe",
	Neutral = "Neutral",
}

-- Every trait that can be drawn for an NPC. Strings on the right are
-- explicitly written to be kid-readable and to match GAME_DESIGN.md
-- "Trait Pool" section verbatim.
NpcRegistry.Traits = {
	-- Risky pool (the explicit archetypes Andrew validated)
	InsideParkedCar = {
		Risk = "Risky",
		DisplayText = "Calling you over from inside a white van",
	},
	HoldingKnife = {
		Risk = "Risky",
		DisplayText = "Holding a knife in the alley behind the shop",
	},
	AskingPersonalInfo = {
		Risk = "Risky",
		DisplayText = "Asking your real name and school",
	},
	OfferingCandy = {
		Risk = "Risky",
		DisplayText = "Offering candy or game items to come with them",
	},
	WantsToGoSomewherePrivate = {
		Risk = "Risky",
		DisplayText = "Wants you to come somewhere private — out of the crowd",
	},
	AloneInBackAlley = {
		Risk = "Risky",
		DisplayText = "Standing alone in a place adults don't usually hang out",
	},

	-- Safe pool
	BehindHotdogStand = {
		Risk = "Safe",
		DisplayText = "Behind the counter at the hot dog stand, wearing an apron",
	},
	WearingApron = {
		Risk = "Safe",
		DisplayText = "Wearing a uniform and helping multiple customers",
	},
	WithKidsAtPlayground = {
		Risk = "Safe",
		DisplayText = "With their kids in the playground",
	},
	PoliceUniform = {
		Risk = "Safe",
		DisplayText = "A police officer / park ranger in uniform",
	},
	ReadingOnBench = {
		Risk = "Safe",
		DisplayText = "Sitting on a public bench reading a book, ignoring you",
	},
}

-- Anchor → preferred role bias. Read by ScenarioService:
-- a "WhiteVan" anchor strongly skews risky; "HotdogStand" strongly skews safe.
-- Format: {Risky = weight, Safe = weight}. Weights are picked relative.
NpcRegistry.AnchorBias = {
	WhiteVan = { Risky = 5, Safe = 0 },
	AlleyBehindShop = { Risky = 5, Safe = 0 },
	HotdogStand = { Risky = 0, Safe = 5 },
	RangerBooth = { Risky = 0, Safe = 5 },
	Playground = { Risky = 1, Safe = 4 },
	Bench = { Risky = 1, Safe = 4 },
	Fountain = { Risky = 1, Safe = 3 },
}

-- For each anchor, the traits that thematically must appear when role aligns.
-- e.g. a Risky NPC at WhiteVan should have InsideParkedCar; a Risky NPC at
-- AlleyBehindShop should have HoldingKnife.
NpcRegistry.AnchorRequiredTraits = {
	WhiteVan = { Risky = { "InsideParkedCar" } },
	AlleyBehindShop = { Risky = { "HoldingKnife", "AloneInBackAlley" } },
	HotdogStand = { Safe = { "BehindHotdogStand", "WearingApron" } },
	RangerBooth = { Safe = { "PoliceUniform" } },
	Playground = { Safe = { "WithKidsAtPlayground" } },
	Bench = { Safe = { "ReadingOnBench" } },
}

-- Convenience: list all tags by risk classification.
function NpcRegistry.GetTagsByRisk(risk: string): { string }
	local result = {}
	for tag, info in pairs(NpcRegistry.Traits) do
		if info.Risk == risk then
			table.insert(result, tag)
		end
	end
	return result
end

-- Sample clue text fragments. Index doesn't matter — ScenarioService picks
-- 3 random ones and they all hint at the same chosen PuppySpawn.
NpcRegistry.ClueFragments = {
	"I saw a fluffy pup near the fountain.",
	"I think I heard a puppy bark behind the playground slide.",
	"There was a little dog under one of the park benches earlier.",
	"A puppy was sniffing around the hot dog stand a few minutes ago.",
	"I noticed a little tail wagging near the ranger booth.",
}

return NpcRegistry
