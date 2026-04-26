--!strict
-- Consumable deployable gear. Each item creates a temporary water-area effect.

export type Gear = {
	id: string,
	name: string,
	price: number,
	radius: number,
	durationSeconds: number,
	cashMultiplier: number?,
	passiveIntervalMultiplier: number?,
	sellValueBonus: number?,
	description: string,
}

local GearCatalog = {}

GearCatalog.Gear = {
	{
		id = "cash_bob",
		name = "2x Cash Bob",
		price = 100,
		radius = 15,
		durationSeconds = 120,
		cashMultiplier = 2,
		description = "Drops a glowing bob that doubles fish sell value in its circle for 2 minutes.",
	},
	{
		id = "lucky_chum",
		name = "Lucky Chum",
		price = 150,
		radius = 18,
		durationSeconds = 120,
		passiveIntervalMultiplier = 0.7,
		description = "Speeds up passive catchers inside the circle while the chum lasts.",
	},
	{
		id = "pearl_lantern",
		name = "Pearl Lantern",
		price = 200,
		radius = 20,
		durationSeconds = 150,
		sellValueBonus = 5,
		description = "Adds +5 pearls to fish caught inside the glow.",
	},
}

local byId: { [string]: Gear } = {}
for _, gear in ipairs(GearCatalog.Gear) do
	byId[gear.id] = gear
end

function GearCatalog.GetById(id: string): Gear?
	return byId[id]
end

return GearCatalog
