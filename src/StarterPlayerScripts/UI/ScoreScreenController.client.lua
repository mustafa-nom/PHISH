--!strict
-- Final score screen with replay / return-to-lobby buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormatter = require(Modules:WaitForChild("NumberFormatter"))

local UIFolder = script.Parent
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local panel: Frame? = nil

local function teardown()
	if panel then
		panel:Destroy()
		panel = nil
	end
end

local function makeRow(parent: Frame, label: string, value: string, layoutOrder: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	local lbl = UIStyle.MakeLabel({
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	lbl.Parent = row
	local val = UIStyle.MakeLabel({
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.new(0.5, 8, 0, 0),
		Text = value,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	val.Parent = row
end

local function build(payload)
	teardown()
	local screen = UIBuilder.GetScreenGui()
	panel = UIStyle.MakePanel({
		Name = "ScoreScreen",
		Size = UDim2.new(0, 460, 0, 460),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Parent = screen,
	})
	UIBuilder.PadLayout(panel :: Frame, 16)

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 44),
		Text = ("%s Run"):format(payload.Rank or "Bronze"),
		TextSize = UIStyle.TextSize.Title,
		TextColor3 = UIStyle.Palette.Accent,
	})
	title.Parent = panel

	local cheer = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 44),
		Text = "Nice run! You paused before risky strangers and asked your buddy.",
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextWrapped = true,
	})
	cheer.Parent = panel

	local rows = Instance.new("Frame")
	rows.Size = UDim2.new(1, 0, 0, 220)
	rows.Position = UDim2.new(0, 0, 0, 80)
	rows.BackgroundTransparency = 1
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = rows

	makeRow(rows, "Total", NumberFormatter.Comma(payload.TotalScore or 0), 1)
	makeRow(rows, "Time", NumberFormatter.Time(payload.Elapsed or 0), 2)
	makeRow(rows, "Trust points", NumberFormatter.Comma(payload.TrustPoints or 0), 3)
	makeRow(rows, "Mistakes", tostring(payload.Mistakes or 0), 4)
	makeRow(rows, "Perfect levels", tostring(payload.PerfectLevels or 0), 5)
	if payload.Rewards then
		makeRow(rows, "Trust Seeds earned", "🌱 " .. tostring(payload.Rewards.TotalSeeds or 0), 6)
	end

	local replay = UIStyle.MakeButton({
		Size = UDim2.new(0.5, -8, 0, 60),
		Position = UDim2.new(0, 0, 1, -68),
		Text = "Replay",
		BackgroundColor3 = UIStyle.Palette.Safe,
	})
	replay.Parent = panel

	local back = UIStyle.MakeButton({
		Size = UDim2.new(0.5, -8, 0, 60),
		Position = UDim2.new(0.5, 8, 1, -68),
		Text = "Back to Lobby",
	})
	back.Parent = panel

	replay.Activated:Connect(function()
		RemoteService.FireServer("StartRound")
		teardown()
	end)
	back.Activated:Connect(function()
		RemoteService.FireServer("ReturnToLobby")
		teardown()
	end)
end

RemoteService.OnClientEvent("ShowScoreScreen", function(payload)
	if typeof(payload) ~= "table" then return end
	build(payload)
end)

RemoteService.OnClientEvent("PairCleared", function(_payload)
	teardown()
end)
