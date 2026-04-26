--!strict
-- Passive fishing gear sold by the shop. Catchers are purchased, deployed on
-- valid water tiles, then periodically add fish into profile.catcherInventory.

export type Catcher = {
	id: string,
	name: string,
	price: number,
	minWaterTier: number,
	catchIntervalSeconds: number,
	capacity: number,
	sellValueMultiplier: number,
	description: string,
}

local CatcherCatalog = {}

CatcherCatalog.Catchers = {
	{
		id = "minnow_net",
		name = "Minnow Net",
		price = 75,
		minWaterTier = 1,
		catchIntervalSeconds = 55,
		capacity = 6,
		sellValueMultiplier = 0.75,
		description = "A simple net for Beginner water. Slow, cheap, and reliable.",
	},
	{
		id = "smart_trap",
		name = "Smart Trap",
		price = 250,
		minWaterTier = 2,
		catchIntervalSeconds = 38,
		capacity = 12,
		sellValueMultiplier = 1.0,
		description = "A sensor trap for stronger water. Holds a medium stash.",
	},
	{
		id = "deep_sea_scanner",
		name = "Deep Sea Scanner",
		price = 800,
		minWaterTier = 3,
		catchIntervalSeconds = 24,
		capacity = 24,
		sellValueMultiplier = 1.35,
		description = "An advanced scanner for high-tier water. Fast and high capacity.",
	},
}

local byId: { [string]: Catcher } = {}
for _, catcher in ipairs(CatcherCatalog.Catchers) do
	byId[catcher.id] = catcher
end

function CatcherCatalog.GetById(id: string): Catcher?
	return byId[id]
end

return CatcherCatalog
