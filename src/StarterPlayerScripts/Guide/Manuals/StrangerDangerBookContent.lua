--!strict
-- Page content for the Guide's Stranger Danger book. Each entry is one
-- two-page spread. Image fields are placeholders — swap "rbxassetid://0"
-- with real asset IDs (decals you upload to roblox.com/library or your
-- creator dashboard) when you have them.
--
-- The book reads like a kid-friendly safety field guide: an intro spread,
-- then "faces to know" spreads pairing one risky archetype with one safer
-- archetype so the Guide always has both sides to relay to the Explorer.

local PLACEHOLDER = "rbxassetid://0"

local pages = {
	{
		Title = "Stranger Danger",
		Left = {
			Heading = "What to avoid",
			Image = PLACEHOLDER,
			Caption = "Watch the body language",
			Bullets = {
				"Calling you over from a parked car",
				"Asking you somewhere private or away from people",
				"Offering candy, free game items, or 'a secret'",
				"Asking for your real name, school, or address",
			},
		},
		Right = {
			Heading = "Safer signs",
			Image = PLACEHOLDER,
			Caption = "These adults are usually OK",
			Bullets = {
				"Standing behind a counter or register",
				"Wearing a uniform or name tag",
				"Helping multiple people, not just you",
				"Hanging out with their own kids or family",
			},
		},
	},
	{
		Title = "Faces to know",
		Left = {
			Heading = "White Van",
			Image = PLACEHOLDER,
			Caption = "Risky — calling you over",
			Bullets = {
				"Side door open, waving you in",
				"Engine running, ready to leave",
				"Tell your buddy: walk back to the crowd",
			},
		},
		Right = {
			Heading = "Hot Dog Vendor",
			Image = PLACEHOLDER,
			Caption = "Safer — behind a counter",
			Bullets = {
				"Apron and uniform hat",
				"Helping every kid, not just you",
				"Tell your buddy: ask for a clue here",
			},
		},
	},
	{
		Title = "Faces to know",
		Left = {
			Heading = "Hooded Adult",
			Image = PLACEHOLDER,
			Caption = "Risky — alone in the alley",
			Bullets = {
				"Hood pulled up, face hidden",
				"Hangs out where adults don't usually stand",
				"Tell your buddy: keep walking, don't engage",
			},
		},
		Right = {
			Heading = "Park Ranger",
			Image = PLACEHOLDER,
			Caption = "Safer — uniform + badge",
			Bullets = {
				"Wears a green uniform with a badge",
				"Stationed at the ranger booth",
				"Tell your buddy: it's OK to ask for help",
			},
		},
	},
	{
		Title = "Faces to know",
		Left = {
			Heading = "Vehicle Leaner",
			Image = PLACEHOLDER,
			Caption = "Risky — hanging by a car",
			Bullets = {
				"Sunglasses, leaning on a parked car",
				"Watching kids without a job to do",
				"Tell your buddy: cross the street",
			},
		},
		Right = {
			Heading = "Parent With Kid",
			Image = PLACEHOLDER,
			Caption = "Safer — busy with their own kid",
			Bullets = {
				"Pushing a stroller or holding a kid's hand",
				"Focused on their family, not on you",
				"Tell your buddy: it's safe to walk past",
			},
		},
	},
	{
		Title = "Faces to know",
		Left = {
			Heading = "Knife Carrier",
			Image = PLACEHOLDER,
			Caption = "Risky — visible weapon",
			Bullets = {
				"Carrying or showing something sharp",
				"Acting tense or aggressive",
				"Tell your buddy: leave NOW, find a uniform",
			},
		},
		Right = {
			Heading = "Casual Park-Goer",
			Image = PLACEHOLDER,
			Caption = "Probably safer — neutral",
			Bullets = {
				"Sitting on a bench, reading or on a phone",
				"Doesn't try to get your attention",
				"Tell your buddy: probably OK to pass",
			},
		},
	},
	{
		Title = "Habit to keep",
		Left = {
			Heading = "Pause",
			Image = PLACEHOLDER,
			Caption = "Before you walk up",
			Bullets = {
				"Stop a few steps away",
				"Look at what they're wearing and doing",
				"Take a breath before you decide",
			},
		},
		Right = {
			Heading = "Talk + Choose",
			Image = PLACEHOLDER,
			Caption = "Together with your buddy",
			Bullets = {
				"Tell your buddy what you see",
				"Listen to what your buddy reads in the book",
				"Decide together — never alone",
			},
		},
	},
}

return pages
