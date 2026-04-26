--!strict
-- Shows the post-decision feedback panel. Reveals species, isLegit verdict,
-- red flags, and reward delta. Auto-dismisses after a few seconds so the
-- player loops back to fishing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local IconFactory = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("IconFactory"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()

local function clearOld()
	local old = screen:FindFirstChild("PhishResultPanel")
	if old then old:Destroy() end
end

local function render(payload: any)
	clearOld()
	if type(payload) ~= "table" then return end

	local correct = payload.wasCorrect == true
	local headerColor = correct and UIStyle.Palette.Safe or UIStyle.Palette.Risky

	local panel = UIStyle.MakePanel({
		Name = "PhishResultPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 380),
		BackgroundColor3 = UIStyle.Palette.Background,
	})
	panel.Parent = screen

	local header = UIStyle.MakePanel({
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = headerColor,
	})
	header.Parent = panel
	local headerIcon = correct and IconFactory.Check(36) or IconFactory.Cross(36)
	IconFactory.Pill(header, headerIcon,
		correct and "NICE CATCH" or "THAT WAS BAIT",
		Color3.new(1, 1, 1), UIStyle.TextSize.Title)

	local subtitle = string.format("%s — %s",
		payload.speciesDisplayName or payload.species or "?",
		payload.isLegit and "Legitimate" or "Phish")
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -32, 0, 28),
		Position = UDim2.fromOffset(16, 76),
		Text = subtitle,
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	local flagsTitle = UIStyle.MakeLabel({
		Size = UDim2.new(1, -32, 0, 24),
		Position = UDim2.fromOffset(16, 112),
		Text = (#(payload.redFlags or {}) > 0) and "Red flags:" or "No red flags — that one was real.",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	flagsTitle.Parent = panel

	local y = 140
	for _, f in ipairs(payload.redFlags or {}) do
		local row = UIStyle.MakeLabel({
			Size = UDim2.new(1, -32, 0, 36),
			Position = UDim2.fromOffset(16, y),
			Text = "• " .. (f.reason or ""),
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		})
		row.Parent = panel
		y += 40
	end

	-- Reward row: coin + delta, sparkle + xp delta, both inline.
	local coinsDelta = payload.coinsDelta or 0
	local xpDelta = payload.xpDelta or 0
	if coinsDelta ~= 0 or xpDelta ~= 0 then
		local rewardRow = Instance.new("Frame")
		rewardRow.Size = UDim2.new(1, -32, 0, 36)
		rewardRow.Position = UDim2.new(0, 16, 1, -48)
		rewardRow.BackgroundTransparency = 1
		rewardRow.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 14)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = rewardRow

		if coinsDelta ~= 0 then
			local cell = Instance.new("Frame")
			cell.Size = UDim2.fromOffset(120, 36)
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = 1
			cell.Parent = rewardRow
			IconFactory.Pill(cell, IconFactory.Coin(28),
				string.format("%+d", coinsDelta),
				UIStyle.Palette.TextPrimary, UIStyle.TextSize.Heading)
		end
		if xpDelta ~= 0 then
			local cell = Instance.new("Frame")
			cell.Size = UDim2.fromOffset(140, 36)
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = 2
			cell.Parent = rewardRow
			IconFactory.Pill(cell, IconFactory.Sparkle(24),
				string.format("%+d XP", xpDelta),
				UIStyle.Palette.TextPrimary, UIStyle.TextSize.Heading)
		end
	end

	task.delay(5, function()
		if panel and panel.Parent then panel:Destroy() end
	end)
end

RemoteService.OnClientEvent("DecisionResult", render)
