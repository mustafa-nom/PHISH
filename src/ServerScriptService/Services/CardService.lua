--!strict
-- Picks a card for a catch. Reads from ServerStorage.ScamCards (server-only)
-- so isLegit and redFlags never leave the server until a decision lands.

local ServerStorage = game:GetService("ServerStorage")
local ScamCards = require(ServerStorage:WaitForChild("ScamCards"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local CardService = {}

local function progressionDifficultyForPlayer(player: Player): number
	local p = DataService.Get(player)
	-- Tutorial nudge: first 3 catches are easy. After that, scale gently.
	if p.totalCatches < 3 then return 1 end
	if p.totalCatches < 10 then return 2 end
	return 3
end

-- Chooses a card and caches it as the "active" card for the player so the
-- decision handler can validate against the same card without trusting the
-- client.
local activeByPlayer: { [Player]: any } = {}

function CardService.PickAndArm(player: Player, waterDifficulty: number?): any
	local targetDifficulty = math.max(progressionDifficultyForPlayer(player), waterDifficulty or 1)
	local card = ScamCards.PickForWaterDifficulty(targetDifficulty)
	activeByPlayer[player] = card
	return card
end

function CardService.GetActive(player: Player): any?
	return activeByPlayer[player]
end

function CardService.Clear(player: Player)
	activeByPlayer[player] = nil
end

-- Public projection: what the client gets to render the inspection card.
-- Strips isLegit, species, redFlags. Includes trueUrl on links so URL Magnifier
-- can reveal it (the player still has to interpret the mismatch).
function CardService.ToPublic(card: any): { [string]: any }
	local pubLinks = {}
	for i, link in ipairs(card.links) do
		pubLinks[i] = { displayText = link.displayText, trueUrl = link.trueUrl }
	end
	return {
		cardId = card.id,
		zone = card.zone,
		difficulty = card.difficulty,
		sender = card.sender,
		subject = card.subject,
		body = card.body,
		links = pubLinks,
	}
end

function CardService.Init() end

return CardService
