--!strict
-- Item pool for Backpack Checkpoint.
-- Each item has a CorrectLane in {"PackIt", "AskFirst", "LeaveIt"} and a
-- DisplayLabel that the Guide manual and the floating-conveyor UI both use.
-- ItemKey matches the Model name in ServerStorage/ItemTemplates/<ItemKey>.

local ItemRegistry = {}

ItemRegistry.Lanes = {
	PackIt = "PackIt",
	AskFirst = "AskFirst",
	LeaveIt = "LeaveIt",
}

ItemRegistry.Items = {
	-- Pack It (green) — OK to share
	FavoriteGame = {
		DisplayLabel = "A game controller (favorite game)",
		CorrectLane = "PackIt",
	},
	FavoriteColor = {
		DisplayLabel = "A paint palette (favorite color)",
		CorrectLane = "PackIt",
	},
	FunnyMeme = {
		DisplayLabel = "A funny meme card",
		CorrectLane = "PackIt",
	},
	PetDrawing = {
		DisplayLabel = "A kid's drawing of their pet",
		CorrectLane = "PackIt",
	},

	-- Ask First (yellow) — gray area
	RealName = {
		DisplayLabel = "A name tag with a handwritten name",
		CorrectLane = "AskFirst",
	},
	PersonalPhoto = {
		DisplayLabel = "A polaroid photo",
		CorrectLane = "AskFirst",
	},
	Birthday = {
		DisplayLabel = "A balloon with a date floating above",
		CorrectLane = "AskFirst",
	},
	BigAchievement = {
		DisplayLabel = "A trophy",
		CorrectLane = "AskFirst",
	},

	-- Leave It (red) — keep private
	HomeAddress = {
		DisplayLabel = "A glowing tiny house",
		CorrectLane = "LeaveIt",
	},
	SchoolName = {
		DisplayLabel = "A school crest banner",
		CorrectLane = "LeaveIt",
	},
	Password = {
		DisplayLabel = "A padlock card",
		CorrectLane = "LeaveIt",
	},
	PhoneNumber = {
		DisplayLabel = "A phone with a number floating above it",
		CorrectLane = "LeaveIt",
	},
	PrivateSecret = {
		DisplayLabel = "A locked diary",
		CorrectLane = "LeaveIt",
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
