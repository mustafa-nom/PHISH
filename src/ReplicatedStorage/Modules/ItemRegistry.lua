--!strict
-- Item pool for Backpack Checkpoint.
--
-- Each item has:
--   CorrectLane    "PackIt" | "AskFirst" | "LeaveIt"
--   DisplayLabel   shown in Guide manual + Explorer floating label
--   Category       "Privacy" | "Phishing" | "Mixed"   (PRD content axis)
--   DifficultyTier 1 | 2 | 3                          (gates Wave 3 content)
--   ScanTags       { string } revealed by the Guide's X-ray Scan tool
-- ItemKey matches the Model name in ServerStorage/ItemTemplates/<ItemKey>.

local ItemRegistry = {}

ItemRegistry.Lanes = {
	PackIt = "PackIt",
	AskFirst = "AskFirst",
	LeaveIt = "LeaveIt",
}

ItemRegistry.Categories = {
	Privacy = "Privacy",
	Phishing = "Phishing",
	Mixed = "Mixed",
}

ItemRegistry.Items = {
	-- Pack It (green) — OK to share
	FavoriteGame = {
		DisplayLabel = "A game controller (favorite game)",
		CorrectLane = "PackIt",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "interest", "public" },
	},
	FavoriteColor = {
		DisplayLabel = "A paint palette (favorite color)",
		CorrectLane = "PackIt",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "interest", "public" },
	},
	FunnyMeme = {
		DisplayLabel = "A funny meme card",
		CorrectLane = "PackIt",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "joke", "public" },
	},
	PetDrawing = {
		DisplayLabel = "A kid's drawing of their pet",
		CorrectLane = "PackIt",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "art", "public" },
	},

	-- Ask First (yellow) — gray area
	RealName = {
		DisplayLabel = "A name tag with a handwritten name",
		CorrectLane = "AskFirst",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "name", "ask grownup" },
	},
	PersonalPhoto = {
		DisplayLabel = "A polaroid photo",
		CorrectLane = "AskFirst",
		Category = "Privacy",
		DifficultyTier = 2,
		ScanTags = { "photo", "ask grownup" },
	},
	Birthday = {
		DisplayLabel = "A balloon with a date floating above",
		CorrectLane = "AskFirst",
		Category = "Privacy",
		DifficultyTier = 2,
		ScanTags = { "birthday", "ask grownup" },
	},
	BigAchievement = {
		DisplayLabel = "A trophy",
		CorrectLane = "AskFirst",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "achievement", "ask grownup" },
	},
	FriendInviteUnknown = {
		DisplayLabel = "A friend request from someone you don't recognize",
		CorrectLane = "AskFirst",
		Category = "Mixed",
		DifficultyTier = 3,
		ScanTags = { "stranger", "ask grownup", "social" },
	},

	-- Leave It (red) — keep private
	HomeAddress = {
		DisplayLabel = "A glowing tiny house",
		CorrectLane = "LeaveIt",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "address", "private" },
	},
	SchoolName = {
		DisplayLabel = "A school crest banner",
		CorrectLane = "LeaveIt",
		Category = "Privacy",
		DifficultyTier = 2,
		ScanTags = { "school", "private" },
	},
	Password = {
		DisplayLabel = "A padlock card",
		CorrectLane = "LeaveIt",
		Category = "Privacy",
		DifficultyTier = 2,
		ScanTags = { "password", "private" },
	},
	PhoneNumber = {
		DisplayLabel = "A phone with a number floating above it",
		CorrectLane = "LeaveIt",
		Category = "Privacy",
		DifficultyTier = 2,
		ScanTags = { "phone", "private" },
	},
	PrivateSecret = {
		DisplayLabel = "A locked diary",
		CorrectLane = "LeaveIt",
		Category = "Privacy",
		DifficultyTier = 1,
		ScanTags = { "secret", "private" },
	},
	-- Phishing items (incoming) — Tier 2-3 phishing content
	FreeRobuxEnvelope = {
		DisplayLabel = "An envelope marked 'YOU WON!'",
		CorrectLane = "LeaveIt",
		Category = "Phishing",
		DifficultyTier = 2,
		ScanTags = { "scam", "too good to be true" },
	},
	ClickHereChat = {
		DisplayLabel = "A chat bubble that says 'click here'",
		CorrectLane = "LeaveIt",
		Category = "Phishing",
		DifficultyTier = 2,
		ScanTags = { "scam", "link" },
	},
	WrappedStrangerGift = {
		DisplayLabel = "A wrapped present from a stranger",
		CorrectLane = "LeaveIt",
		Category = "Phishing",
		DifficultyTier = 3,
		ScanTags = { "stranger", "scam" },
	},
	TooGoodOffer = {
		DisplayLabel = "A screenshot of a too-good-to-be-true offer",
		CorrectLane = "LeaveIt",
		Category = "Phishing",
		DifficultyTier = 3,
		ScanTags = { "scam", "too good to be true" },
	},
	WeirdTyposChat = {
		DisplayLabel = "A chat from 'your friend' with weird typos",
		CorrectLane = "AskFirst",
		Category = "Phishing",
		DifficultyTier = 3,
		ScanTags = { "imposter", "ask grownup" },
	},
	FakeDeliverySlip = {
		DisplayLabel = "A delivery slip with no return address",
		CorrectLane = "AskFirst",
		Category = "Phishing",
		DifficultyTier = 3,
		ScanTags = { "unknown sender", "ask grownup" },
	},
}

-- Get the list of ItemKeys whose CorrectLane matches `lane`.
function ItemRegistry.GetKeysForLane(lane: string): { string }
	local result = {}
	for key, info in pairs(ItemRegistry.Items) do
		if info.CorrectLane == lane then
			table.insert(result, key)
		end
	end
	return result
end

-- Get the list of ItemKeys whose DifficultyTier is at most `maxTier`.
function ItemRegistry.GetKeysUpToTier(maxTier: number): { string }
	local result = {}
	for key, info in pairs(ItemRegistry.Items) do
		if (info.DifficultyTier or 1) <= maxTier then
			table.insert(result, key)
		end
	end
	return result
end

-- Intersect lane + tier filters. Used by the wave generator to keep
-- per-wave content tier-gated (Tier-3 items only appear in Wave 3).
function ItemRegistry.GetKeysForLaneUpToTier(lane: string, maxTier: number): { string }
	local result = {}
	for key, info in pairs(ItemRegistry.Items) do
		if info.CorrectLane == lane and (info.DifficultyTier or 1) <= maxTier then
			table.insert(result, key)
		end
	end
	return result
end

function ItemRegistry.GetItem(key: string)
	return ItemRegistry.Items[key]
end

function ItemRegistry.IsValidLane(lane: string?): boolean
	return lane == ItemRegistry.Lanes.PackIt
		or lane == ItemRegistry.Lanes.AskFirst
		or lane == ItemRegistry.Lanes.LeaveIt
end

-- Lane display config for UI tinting.
ItemRegistry.LaneTheme = {
	PackIt = { Label = "Pack It", Color = Color3.fromRGB(108, 196, 96) },
	AskFirst = { Label = "Ask First", Color = Color3.fromRGB(245, 200, 90) },
	LeaveIt = { Label = "Leave It", Color = Color3.fromRGB(220, 92, 92) },
}

return ItemRegistry
