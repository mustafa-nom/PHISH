--!strict
-- Page generator for the Guide's Stranger Danger book.
--
-- Pages are derived from StrangerDangerLogic.Archetypes so the cues, names,
-- and silhouettes always match what the server is actually generating.
-- The book has 3 sections:
--   1. Intro — what to avoid / safer signs
--   2. Faces — one page per archetype (left page = how to spot, right page
--      = what to ASK YOUR EXPLORER and the verdict)
--   3. Clue Map — populated live as fragments stream in. starts empty.
--
-- Image fields are placeholders ("rbxassetid://0"). User uploads decals and
-- swaps the IDs in StrangerDangerLogic.Archetypes (or here for art-only
-- pages like the intro).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StrangerDangerLogic = require(Modules:WaitForChild("StrangerDangerLogic"))

local PLACEHOLDER = "rbxassetid://0"

-- friendly labels for archetype keys (the keys are identifier-cased)
local ARCHETYPE_LABEL = {
	HotDogVendor = "Hot Dog Vendor",
	Ranger = "Park Ranger",
	ParentWithKid = "Parent + Kid",
	CasualParkGoer = "Park Reader",
	HoodedAdult = "Hooded Adult",
	VehicleLeaner = "Van Leaner",
	KnifeArchetype = "Tense Stranger",
}

-- ranked: want the most teachable contrasts first
local ARCHETYPE_ORDER = {
	"VehicleLeaner",   -- the iconic risky to teach
	"HotDogVendor",    -- iconic safe
	"HoodedAdult",
	"Ranger",
	"KnifeArchetype",
	"ParentWithKid",
	"CasualParkGoer",
}

local function bulletsFromCues(cueTags: { string }, useGuideText: boolean): { string }
	local out: { string } = {}
	for _, tag in ipairs(cueTags) do
		local cue = StrangerDangerLogic.Cues[tag]
		if cue then
			table.insert(out, useGuideText and cue.GuideText or cue.ExplorerText)
		end
	end
	return out
end

local function verdictTip(archetype): string
	local sample = StrangerDangerLogic.PickCues(archetype, 3)
	-- since cue choice randomizes per round, the book gives the WORST-case
	-- read for risky archetypes and BEST-case for safe — in either case the
	-- duo should read 2-3 cues before deciding.
	local logic = StrangerDangerLogic.Archetypes[archetype]
	if not logic then return "Ask First if unsure." end
	if logic.BaseRisk == "Risky" then
		return "If 2 cues match the risky pool — tell your Explorer to AVOID."
	elseif logic.BaseRisk == "Safe" then
		return "If 2 cues match the safe pool — tell your Explorer they can APPROACH."
	end
	return "Mixed cues — ASK FIRST and re-check before approaching."
end

local function buildArchetypePage(archetype: string)
	local data = StrangerDangerLogic.Archetypes[archetype]
	if not data then return nil end
	local label = ARCHETYPE_LABEL[archetype] or archetype
	local risk = data.BaseRisk
	local title = (risk == "Risky" and "WATCH OUT — " or risk == "Safe" and "SAFE BET — " or "") .. label
	return {
		Title = title,
		Left = {
			Heading = data.Silhouette.Outline,
			Image = PLACEHOLDER,
			Caption = data.Silhouette.Headline,
			Bullets = bulletsFromCues(data.CuePool, true),
		},
		Right = {
			Heading = (risk == "Risky" and "Tell your buddy")
				or (risk == "Safe" and "Tell your buddy")
				or "Ask first",
			Image = PLACEHOLDER,
			Caption = verdictTip(archetype),
			Bullets = (function()
				if risk == "Risky" then
					return {
						"Stay back, don't go closer",
						"Pick AVOID on the action card",
						"Their fragment is probably a lie",
					}
				elseif risk == "Safe" then
					return {
						"Walk up and say hi",
						"Pick APPROACH on the action card",
						"Their clue is truthful — write it on the map",
					}
				else
					return {
						"Use ASK FIRST to learn one more cue",
						"If next cue is risky → AVOID",
						"If next cue is safe → APPROACH",
					}
				end
			end)(),
		},
	}
end

local function buildIntroPages()
	return {
		{
			Title = "STRANGER DANGER",
			Left = {
				Heading = "Risky signals",
				Image = PLACEHOLDER,
				Caption = "Tell your buddy: AVOID",
				Bullets = {
					"Calling you over from a parked car",
					"Asking you somewhere private",
					"Offering candy or game items",
					"Asking real name, school, address",
					"Hood up + alone + lingering",
				},
			},
			Right = {
				Heading = "Safer signals",
				Image = PLACEHOLDER,
				Caption = "Tell your buddy: APPROACH",
				Bullets = {
					"Behind a counter / register",
					"Wearing a uniform + name tag",
					"Helping multiple people",
					"With their own kids or family",
					"Doing their own thing, ignoring you",
				},
			},
		},
		{
			Title = "HOW TO PLAY",
			Left = {
				Heading = "Your job",
				Image = PLACEHOLDER,
				Caption = "Read the book, talk to your buddy",
				Bullets = {
					"Buddy describes who they see",
					"Find the matching face in the book",
					"Tell them: APPROACH / ASK FIRST / AVOID",
					"Risky NPCs lie about the puppy — listen but verify",
				},
			},
			Right = {
				Heading = "Find the puppy",
				Image = PLACEHOLDER,
				Caption = "3 truthful clues triangulate it",
				Bullets = {
					"Each safe NPC tells you one location",
					"Risky NPCs send you the wrong way",
					"The Clue Map at the back collects all of them",
					"Pick the landmark with the most matches",
				},
			},
		},
	}
end

local function buildClueMapPage()
	-- placeholder; live updates fill this out via BookView:UpdateClueMap()
	return {
		Title = "CLUE MAP",
		Left = {
			Heading = "Fragments collected",
			Image = PLACEHOLDER,
			Caption = "Each safe approach adds a fragment here",
			Bullets = { "(no fragments yet — go meet someone safe)" },
		},
		Right = {
			Heading = "Best guess",
			Image = PLACEHOLDER,
			Caption = "Where the puppy is hiding",
			Bullets = { "(need at least one truthful fragment)" },
		},
	}
end

local function build(): { any }
	local pages = buildIntroPages()
	for _, key in ipairs(ARCHETYPE_ORDER) do
		local page = buildArchetypePage(key)
		if page then table.insert(pages, page) end
	end
	table.insert(pages, buildClueMapPage())
	return pages
end

local Built = build()

-- expose helpers so the controller can resolve the live clue map page index
Built.ArchetypeIndex = function(archetype: string): number?
	local startOffset = #buildIntroPages()
	for i, key in ipairs(ARCHETYPE_ORDER) do
		if key == archetype then
			return startOffset + i
		end
	end
	return nil
end

Built.ClueMapIndex = function(): number
	return #Built
end

Built.LandmarkLabel = function(landmark: string): string
	return StrangerDangerLogic.LandmarkDisplay[landmark] or landmark
end

return Built
