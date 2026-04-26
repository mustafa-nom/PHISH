--!strict
-- Persistent Board of Fame backed by OrderedDataStore. Score = correct
-- catches. The board reads the top 10 globally and renders them onto
-- every BasePart tagged BoardOfFame (SurfaceGui body label) plus fires
-- LeaderboardUpdated to clients. Updates on a 30s loop.
--
-- DataService.OnSaved hooks fire after each profile save so the
-- player's score stays current without waiting for the periodic refresh.
--
-- Failure modes: if Studio API access is disabled or the store errors,
-- the previous text stays on the board and nothing crashes.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local LeaderboardService = {}

local LEADERBOARD_NAME = "PhishLeaderboardCorrectCatchesV1"
local TOP_N = 10
local REFRESH_INTERVAL = 30

local store: OrderedDataStore? = nil
do
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(LEADERBOARD_NAME)
	end)
	if ok then store = s else warn("[PHISH][Leaderboard] No OrderedDataStore: " .. tostring(s)) end
end

-- Avoid hammering Players:GetNameFromUserIdAsync — cache lookups.
local nameCache: { [number]: string } = {}
local function nameForUserId(userId: number): string
	local cached = nameCache[userId]
	if cached then return cached end
	-- If the player is currently online we already have the name.
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			nameCache[userId] = p.DisplayName
			return p.DisplayName
		end
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return string.format("Player %d", userId)
end

local function writeScore(userId: number, score: number)
	if not store then return end
	local s = store
	pcall(function()
		s:UpdateAsync(tostring(userId), function(prev)
			-- Only overwrite if the new score is bigger so we never regress
			-- a player's leaderboard rank on a misread.
			if type(prev) == "number" and prev >= score then return nil end
			return score
		end)
	end)
end

local function readTop(): { { userId: number, score: number } }
	if not store then return {} end
	local s = store
	local ok, page = pcall(function()
		return s:GetSortedAsync(false, TOP_N):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then return {} end
	local out = {}
	for _, entry in ipairs(page) do
		local uid = tonumber(entry.key)
		local score = tonumber(entry.value)
		if uid and score then
			table.insert(out, { userId = uid, score = score })
		end
	end
	return out
end

local lastBoardText = "(no one's caught a phish yet)"

local function buildBoardText(): string
	local top = readTop()
	if #top == 0 then return lastBoardText end
	local lines = {}
	for i, row in ipairs(top) do
		table.insert(lines, string.format("%d. %s — %d catches", i, nameForUserId(row.userId), row.score))
	end
	local text = table.concat(lines, "\n")
	lastBoardText = text
	return text
end

local function pushBoard()
	local text = buildBoardText()
	for _, panel in ipairs(CollectionService:GetTagged(PhishConstants.Tags.BoardOfFame)) do
		local sg = panel:FindFirstChildWhichIsA("SurfaceGui")
		if sg then
			-- Prefer a child explicitly named "Body". Fall back to the second
			-- TextLabel by Y position (legacy SurfaceGui layout).
			local body = sg:FindFirstChild("Body")
			if not (body and body:IsA("TextLabel")) then
				local labels = {}
				for _, c in ipairs(sg:GetChildren()) do
					if c:IsA("TextLabel") then table.insert(labels, c) end
				end
				table.sort(labels, function(a, b) return a.Position.Y.Scale < b.Position.Y.Scale end)
				body = labels[2]
			end
			if body and body:IsA("TextLabel") then body.Text = text end
		end
	end
	RemoteService.FireAllClients("LeaderboardUpdated", { text = text, top = readTop() })
end

function LeaderboardService.Init()
	-- Mirror every profile save into the ordered store so live ranks
	-- update without waiting for the 30s loop.
	DataService.OnSaved(function(player, profile)
		writeScore(player.UserId, profile.correctCatches or 0)
	end)

	-- Initial paint as soon as we boot — gives the SurfaceGui content even
	-- before the first periodic tick.
	task.spawn(function()
		task.wait(2)
		pushBoard()
	end)

	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			pushBoard()
		end
	end)
end

return LeaderboardService
