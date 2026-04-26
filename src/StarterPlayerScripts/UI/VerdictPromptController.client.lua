--!strict
-- Lesson popup shown after the skill bar succeeds. Reveals the fish, its
-- field-guide lesson, and offers two verdict buttons — Reel It In (good
-- catch) or Cut & Report (refuse). On timeout, auto-fires the safe default
-- (Refuse), since the kid-friendly default for an unread bait is "don't
-- trust it."

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local activeFrame: Frame? = nil
local activeEncounterId: string? = nil
local activeDeadline: number? = nil
local activeTimerLabel: TextLabel? = nil
local fired = false

local function rarityColor(rarity: string?): Color3
	if rarity == "Legendary" then return Color3.fromRGB(255, 200, 80) end
	if rarity == "Epic" then return Color3.fromRGB(220, 130, 250) end
	if rarity == "Rare" then return Color3.fromRGB(120, 200, 255) end
	return Color3.fromRGB(220, 220, 220)
end

local function close()
	if activeFrame then activeFrame:Destroy() end
	activeFrame = nil
	activeEncounterId = nil
	activeDeadline = nil
	activeTimerLabel = nil
end

local function fireVerdict(verdict: string)
	if fired then return end
	if not activeEncounterId then return end
	fired = true
	RemoteService.FireServer("RequestVerdict", {
		encounterId = activeEncounterId,
		verdict = verdict,
	})
end

local function build(payload)
	close()
	fired = false
	activeEncounterId = payload.EncounterId
	activeDeadline = os.clock() + (payload.DecisionWindowSec or 6)

	local frame = UIStyle.MakePanel({
		Name = "VerdictPrompt",
		Size = UDim2.new(0, 560, 0, 300),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Parent = screen,
	})
	activeFrame = frame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = rarityColor(payload.Rarity)
	header.BorderSizePixel = 0
	header.Parent = frame
	UIStyle.ApplyCorner(header)

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 6),
		Text = payload.DisplayName or "Fish",
		TextSize = UIStyle.TextSize.Title,
		TextColor3 = Color3.fromRGB(40, 28, 16),
		Parent = header,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 38),
		Text = ("%s • %s"):format(tostring(payload.Category), tostring(payload.Rarity)),
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = Color3.fromRGB(50, 36, 22),
		Parent = header,
	})

	UIStyle.MakeLabel({
		Size = UDim2.new(1, -32, 0, 116),
		Position = UDim2.new(0, 16, 0, 76),
		Text = payload.LessonExplanation or "",
		TextSize = UIStyle.TextSize.Body,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})

	activeTimerLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 0, 196),
		Text = "Decide!",
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		Parent = frame,
	})

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -32, 0, 56)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -16)
	row.BackgroundTransparency = 1
	row.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local reelBtn = UIStyle.MakeButton({
		Size = UDim2.new(0, 220, 0, 52),
		Text = "Reel It In",
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Safe,
		LayoutOrder = 1,
		Parent = row,
	})
	reelBtn.Activated:Connect(function() fireVerdict("Reel") end)

	local refuseBtn = UIStyle.MakeButton({
		Size = UDim2.new(0, 220, 0, 52),
		Text = "Cut & Report",
		TextSize = UIStyle.TextSize.Heading,
		BackgroundColor3 = UIStyle.Palette.Risky,
		LayoutOrder = 2,
		Parent = row,
	})
	refuseBtn.Activated:Connect(function() fireVerdict("Refuse") end)
end

RemoteService.OnClientEvent("VerdictPromptReady", function(payload)
	if typeof(payload) ~= "table" then return end
	build(payload)
end)

RemoteService.OnClientEvent("CatchResolved", function()
	close()
end)

RemoteService.OnClientEvent("LineSnapped", function()
	close()
end)

RunService.RenderStepped:Connect(function()
	if activeDeadline and activeTimerLabel then
		local remaining = activeDeadline - os.clock()
		if remaining <= 0 then
			activeTimerLabel.Text = "Time's up — defaulting to Cut & Report."
			-- Server fires the auto-Refuse on its own timer; just stop counting.
			activeDeadline = nil
		else
			activeTimerLabel.Text = ("%.1fs to decide"):format(remaining)
		end
	end
end)
