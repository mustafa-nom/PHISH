--!strict
-- Renders the bite cue (color + ripple label) and the four decision
-- buttons (Verify / Reel / Cut Line / Report). The Release button appears
-- on Rumor Fish only (after Verify reveals).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local FishCategoryTypes = require(Modules:WaitForChild("FishCategoryTypes"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local state = {
	encounterId = nil :: string?,
	deadline = nil :: number?,
	revealedCategory = nil :: string?,
	frame = nil :: Frame?,
	timerLabel = nil :: TextLabel?,
}

local function destroyFrame()
	if state.frame then
		state.frame:Destroy()
		state.frame = nil
		state.timerLabel = nil
	end
end

local function actionButton(parent: Frame, label: string, action: string, color: Color3?, layoutOrder: number)
	local btn = UIStyle.MakeButton({
		Size = UDim2.new(0, 110, 0, 44),
		Text = label,
		TextSize = UIStyle.TextSize.Body,
		BackgroundColor3 = color or UIStyle.Palette.Accent,
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
	btn.Activated:Connect(function()
		if not state.encounterId then return end
		local payload = { encounterId = state.encounterId }
		if action == "Verify" then
			RemoteService.FireServer("RequestVerify", payload)
		elseif action == "Reel" then
			RemoteService.FireServer("RequestReel", payload)
		elseif action == "CutLine" then
			RemoteService.FireServer("RequestCutLine", payload)
		elseif action == "Report" then
			RemoteService.FireServer("RequestReport", payload)
		elseif action == "Release" then
			RemoteService.FireServer("RequestRelease", payload)
		end
	end)
	return btn
end

local function buildFrame(payload)
	destroyFrame()
	local frame = UIStyle.MakePanel({
		Name = "BiteFrame",
		Size = UDim2.new(0, 520, 0, 200),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		Parent = screen,
	})
	state.frame = frame

	local cueBlob = Instance.new("Frame")
	cueBlob.Size = UDim2.new(0, 60, 0, 60)
	cueBlob.AnchorPoint = Vector2.new(0.5, 0.5)
	cueBlob.Position = UDim2.new(0.5, 0, 0, 36)
	cueBlob.BackgroundColor3 = payload.BobberColor or UIStyle.Palette.Highlight
	cueBlob.BorderSizePixel = 0
	cueBlob.Parent = frame
	UIStyle.ApplyCorner(cueBlob, UDim.new(1, 0))
	UIStyle.ApplyStroke(cueBlob, UIStyle.Palette.PanelStroke, 3)

	-- Pulse the cue blob.
	task.spawn(function()
		while cueBlob and cueBlob.Parent do
			TweenService:Create(cueBlob, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Size = UDim2.new(0, 70, 0, 70) }):Play()
			task.wait(0.05)
			break
		end
	end)

	UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 78),
		Text = ("Ripple: %s"):format(tostring(payload.Ripple or "?")),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = frame,
	})

	state.timerLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 102),
		Text = "Decide!",
		TextSize = UIStyle.TextSize.Body,
		Parent = frame,
	})

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 50)
	row.Position = UDim2.new(0, 8, 1, -58)
	row.BackgroundTransparency = 1
	row.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	actionButton(row, "Verify", "Verify", UIStyle.Palette.Highlight, 1)
	actionButton(row, "Reel", "Reel", UIStyle.Palette.Safe, 2)
	actionButton(row, "Cut Line", "CutLine", UIStyle.Palette.Risky, 3)
	actionButton(row, "Report", "Report", UIStyle.Palette.AskFirst, 4)
	actionButton(row, "Release", "Release", UIStyle.Palette.Panel, 5)
end

RemoteService.OnClientEvent("BiteOccurred", function(payload)
	if typeof(payload) ~= "table" then return end
	state.encounterId = payload.EncounterId
	state.deadline = os.clock() + (payload.DecisionWindowSec or 4)
	state.revealedCategory = nil
	buildFrame(payload)
end)

RemoteService.OnClientEvent("FieldGuideEntryUnlocked", function(payload)
	if typeof(payload) ~= "table" then return end
	state.revealedCategory = payload.Category
	if state.timerLabel then
		state.timerLabel.Text = ("Verified: %s"):format(payload.DisplayName or "?")
	end
end)

RemoteService.OnClientEvent("CatchResolved", function()
	state.encounterId = nil
	state.deadline = nil
	destroyFrame()
end)

RemoteService.OnClientEvent("ReelMinigameStarted", function()
	-- The reel minigame controller takes over; this hud yields the screen.
	destroyFrame()
end)

RunService.RenderStepped:Connect(function()
	if state.deadline and state.timerLabel then
		local remaining = state.deadline - os.clock()
		if remaining <= 0 then
			state.timerLabel.Text = "..."
		else
			state.timerLabel.Text = ("%.1fs to decide"):format(remaining)
		end
	end
end)

-- Suppress lint: FishCategoryTypes is reserved for future per-category UI tinting.
local _2 = FishCategoryTypes
