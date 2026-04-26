--!strict
-- Shows the post-decision feedback panel. Reveals species, isLegit verdict,
-- red flags, and reward delta. Auto-dismisses after a few seconds so the
-- player loops back to fishing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))
local IconFactory = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("IconFactory"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local screen = UIBuilder.GetScreenGui()
local activeDismiss: (() -> ())? = nil

local function clearOld()
	if activeDismiss then
		activeDismiss()
		activeDismiss = nil
	end
	local old = screen:FindFirstChild("PhishResultPanel")
	if old then old:Destroy() end
end

local function render(payload: any)
	clearOld()
	if type(payload) ~= "table" then return end

	local correct = payload.wasCorrect == true
	local headerColor = correct and UIStyle.Palette.Safe or UIStyle.Palette.Risky

	local dismissed = false
	local dismissInput: RBXScriptConnection? = nil
	local dismissLayer = Instance.new("TextButton")
	dismissLayer.Name = "PhishResultPanel"
	dismissLayer.Size = UDim2.fromScale(1, 1)
	dismissLayer.BackgroundTransparency = 1
	dismissLayer.BorderSizePixel = 0
	dismissLayer.Text = ""
	dismissLayer.AutoButtonColor = false
	dismissLayer.ZIndex = 40
	dismissLayer.Parent = screen

	local function dismiss()
		if dismissed then return end
		dismissed = true
		if dismissInput then
			dismissInput:Disconnect()
			dismissInput = nil
		end
		if dismissLayer and dismissLayer.Parent then
			dismissLayer:Destroy()
		end
		if activeDismiss == dismiss then
			activeDismiss = nil
		end
	end
	activeDismiss = dismiss

	dismissLayer.Activated:Connect(dismiss)
	dismissInput = UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dismiss()
		end
	end)

	local panel = UIStyle.MakePanel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 380),
		BackgroundColor3 = UIStyle.Palette.Background,
		ZIndex = 41,
	})
	panel.Parent = dismissLayer
	UIStyle.ApplyScale(panel, 0.7)

	local header = UIStyle.MakePanel({
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = headerColor,
	})
	header.Parent = panel
	UIStyle.MakeLabel({
		Size = UDim2.fromScale(1, 1),
		Text = correct and "NICE CATCH" or "THAT WAS BAIT",
		Font = UIStyle.FontBold,
		TextSize = UIStyle.TextSize.Title,
		TextColor3 = Color3.new(1, 1, 1),
	}).Parent = header

	local subtitle = string.format("%s - %s",
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
		Text = (#(payload.redFlags or {}) > 0) and "Red flags:" or "No red flags - that one was real.",
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
			Text = "- " .. (f.reason or ""),
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		})
		row.Parent = panel
		y += 40
	end

	local flagsCorrect = #(payload.flagsCorrect or {})
	local flagsFalse = #(payload.flagsFalse or {})
	local flagBonusCoins = payload.flagBonusCoins or 0
	local flagBonusXp = payload.flagBonusXp or 0
	if flagsCorrect > 0 or flagsFalse > 0 or flagBonusCoins ~= 0 or flagBonusXp ~= 0 then
		local summary = string.format("Red flag score: %d right, %d wrong", flagsCorrect, flagsFalse)
		if flagBonusCoins ~= 0 then
			summary ..= string.format("   Coins %+d", flagBonusCoins)
		end
		if flagBonusXp ~= 0 then
			summary ..= string.format("   XP %+d", flagBonusXp)
		end
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -32, 0, 32),
			Position = UDim2.fromOffset(16, math.min(y + 4, 292)),
			Text = summary,
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = (flagsFalse > 0 and flagsCorrect == 0) and UIStyle.Palette.Risky or UIStyle.Palette.Safe,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}).Parent = panel
	end

	if payload.fishAddedToInventory == true and (payload.fishSellValue or 0) > 0 then
		UIStyle.MakeLabel({
			Size = UDim2.new(1, -32, 0, 28),
			Position = UDim2.fromOffset(16, math.min(y + 40, 320)),
			Text = string.format("Fish added to backpack - sell value: %d pearls", payload.fishSellValue),
			Font = UIStyle.FontBold,
			TextSize = UIStyle.TextSize.Body,
			TextColor3 = UIStyle.Palette.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}).Parent = panel
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
		dismiss()
	end)
end

RemoteService.OnClientEvent("DecisionResult", render)
