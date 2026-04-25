--!strict
-- Top-of-screen HUD: timer, mistakes, trust points, micro-objective.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormatter = require(Modules:WaitForChild("NumberFormatter"))
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))

local UIFolder = script.Parent
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local panel: Frame? = nil
local timeLabel: TextLabel? = nil
local mistakesLabel: TextLabel? = nil
local trustLabel: TextLabel? = nil
local objectiveLabel: TextLabel? = nil

local activeRoundId: string? = nil
local roundStartedAt = 0
local mistakes = 0
local trustPoints = 0
local cluesCollected = 0
local cluesNeeded = 3
local itemsSorted = 0
local itemsTotal = 6
local levelType: string? = nil
local heartbeat: RBXScriptConnection? = nil

local function build()
	local screen = UIBuilder.GetScreenGui()
	if panel and panel.Parent then return end
	panel = UIStyle.MakePanel({
		Name = "RoundHud",
		Size = UDim2.new(0, 520, 0, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Parent = screen,
	})
	UIBuilder.PadLayout(panel :: Frame, 8)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.Parent = panel

	timeLabel = UIStyle.MakeLabel({
		Size = UDim2.new(0, 90, 1, 0),
		Text = "0:00",
		TextSize = UIStyle.TextSize.Heading,
	})
	timeLabel.Parent = panel

	mistakesLabel = UIStyle.MakeLabel({
		Size = UDim2.new(0, 80, 1, 0),
		Text = "0 misses",
		TextSize = UIStyle.TextSize.Body,
	})
	mistakesLabel.Parent = panel

	trustLabel = UIStyle.MakeLabel({
		Size = UDim2.new(0, 110, 1, 0),
		Text = "0 trust",
		TextSize = UIStyle.TextSize.Body,
	})
	trustLabel.Parent = panel

	objectiveLabel = UIStyle.MakeLabel({
		Size = UDim2.new(0, 200, 1, 0),
		Text = "",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.Highlight,
	})
	objectiveLabel.Parent = panel
end

local function teardown()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if panel then
		panel:Destroy()
		panel = nil
	end
	timeLabel = nil
	mistakesLabel = nil
	trustLabel = nil
	objectiveLabel = nil
	activeRoundId = nil
	levelType = nil
end

local function refreshObjective()
	if not objectiveLabel then return end
	if levelType == LevelTypes.StrangerDangerPark then
		objectiveLabel.Text = ("Find %d / %d clues"):format(cluesCollected, cluesNeeded)
	elseif levelType == LevelTypes.BackpackCheckpoint then
		objectiveLabel.Text = ("Sort %d / %d items"):format(itemsSorted, itemsTotal)
	else
		objectiveLabel.Text = ""
	end
end

local function startTicker()
	if heartbeat then heartbeat:Disconnect() end
	heartbeat = RunService.Heartbeat:Connect(function()
		if not activeRoundId or not timeLabel then return end
		local elapsed = os.clock() - roundStartedAt
		timeLabel.Text = NumberFormatter.Time(elapsed)
	end)
end

RemoteService.OnClientEvent("RoundStarted", function(payload)
	if typeof(payload) ~= "table" then return end
	build()
	activeRoundId = payload.RoundId
	roundStartedAt = payload.StartedAt or os.clock()
	mistakes = 0
	trustPoints = 0
	cluesCollected = 0
	itemsSorted = 0
	if mistakesLabel then mistakesLabel.Text = "0 misses" end
	if trustLabel then trustLabel.Text = "0 trust" end
	startTicker()
end)

RemoteService.OnClientEvent("LevelStarted", function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.RoundId ~= activeRoundId then return end
	levelType = payload.LevelType
	cluesCollected = 0
	itemsSorted = 0
	if payload.Scenario then
		if payload.Scenario.TotalCluesNeeded then
			cluesNeeded = payload.Scenario.TotalCluesNeeded
		end
		if payload.Scenario.Total then
			itemsTotal = payload.Scenario.Total
		end
	end
	refreshObjective()
end)

RemoteService.OnClientEvent("ScoreUpdated", function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.RoundId and payload.RoundId ~= activeRoundId then return end
	mistakes = payload.Mistakes or mistakes
	trustPoints = payload.TrustPoints or trustPoints
	if mistakesLabel then mistakesLabel.Text = ("%d miss%s"):format(mistakes, mistakes == 1 and "" or "es") end
	if trustLabel then trustLabel.Text = ("%s trust"):format(NumberFormatter.Comma(trustPoints)) end
end)

RemoteService.OnClientEvent("ClueCollected", function(payload)
	if payload.RoundId ~= activeRoundId then return end
	cluesCollected = payload.Total or cluesCollected
	cluesNeeded = payload.NeededTotal or cluesNeeded
	refreshObjective()
end)

RemoteService.OnClientEvent("ItemSortResult", function(payload)
	if payload.RoundId ~= activeRoundId then return end
	if payload.Correct then
		itemsSorted += 1
	end
	refreshObjective()
end)

RemoteService.OnClientEvent("LevelEnded", function(payload)
	if payload.RoundId ~= activeRoundId then return end
	UIBuilder.Toast(("Level complete: %s"):format(payload.LevelType or ""), 2, "Success")
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	teardown()
end)
