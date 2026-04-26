--!strict
-- XP-driven level progression and cosmetic unlocks.

local Progression = {}

export type BoatSkin = {
	id: string,
	name: string,
	minLevel: number,
	color: Color3,
}

export type LevelInfo = {
	xp: number,
	level: number,
	currentLevelXp: number,
	nextLevelXp: number?,
	xpIntoLevel: number,
	xpForNextLevel: number?,
	progress: number,
	isMaxLevel: boolean,
	boatSkin: BoatSkin,
}

Progression.LevelThresholds = {
	0,    -- Level 1
	60,   -- Level 2
	150,  -- Level 3
	280,  -- Level 4
	450,  -- Level 5
	660,  -- Level 6
	910,  -- Level 7
	1200, -- Level 8
	1530, -- Level 9
	1900, -- Level 10
}

Progression.BoatSkins = {
	{
		id = "driftwood",
		name = "Driftwood Brown",
		minLevel = 1,
		color = Color3.fromRGB(116, 76, 48),
	},
	{
		id = "coral",
		name = "Coral Red",
		minLevel = 2,
		color = Color3.fromRGB(224, 104, 84),
	},
	{
		id = "lagoon",
		name = "Lagoon Teal",
		minLevel = 4,
		color = Color3.fromRGB(36, 168, 165),
	},
	{
		id = "sunburst",
		name = "Sunburst Gold",
		minLevel = 6,
		color = Color3.fromRGB(245, 184, 70),
	},
	{
		id = "storm",
		name = "Storm Blue",
		minLevel = 8,
		color = Color3.fromRGB(75, 120, 210),
	},
	{
		id = "astral",
		name = "Astral Pink",
		minLevel = 10,
		color = Color3.fromRGB(220, 90, 210),
	},
}

function Progression.GetMaxLevel(): number
	return #Progression.LevelThresholds
end

function Progression.GetLevelForXp(xp: number): number
	local safeXp = math.max(0, math.floor(xp))
	local level = 1
	for thresholdLevel, threshold in ipairs(Progression.LevelThresholds) do
		if safeXp >= threshold then
			level = thresholdLevel
		else
			break
		end
	end
	return level
end

function Progression.GetBoatSkinForLevel(level: number): BoatSkin
	local skin = Progression.BoatSkins[1]
	for _, candidate in ipairs(Progression.BoatSkins) do
		if level >= candidate.minLevel then
			skin = candidate
		else
			break
		end
	end
	return skin
end

function Progression.GetUnlockedBoatSkins(level: number): { BoatSkin }
	local unlocked = {}
	for _, skin in ipairs(Progression.BoatSkins) do
		if level >= skin.minLevel then
			table.insert(unlocked, skin)
		end
	end
	return unlocked
end

function Progression.GetLevelInfo(xp: number): LevelInfo
	local safeXp = math.max(0, math.floor(xp))
	local level = Progression.GetLevelForXp(safeXp)
	local currentLevelXp = Progression.LevelThresholds[level] or 0
	local nextLevelXp = Progression.LevelThresholds[level + 1]
	local xpForNextLevel = nextLevelXp and (nextLevelXp - currentLevelXp) or nil
	local xpIntoLevel = safeXp - currentLevelXp
	local progress = 1
	if xpForNextLevel and xpForNextLevel > 0 then
		progress = math.clamp(xpIntoLevel / xpForNextLevel, 0, 1)
	end

	return {
		xp = safeXp,
		level = level,
		currentLevelXp = currentLevelXp,
		nextLevelXp = nextLevelXp,
		xpIntoLevel = xpIntoLevel,
		xpForNextLevel = xpForNextLevel,
		progress = progress,
		isMaxLevel = nextLevelXp == nil,
		boatSkin = Progression.GetBoatSkinForLevel(level),
	}
end

return Progression
