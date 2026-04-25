--!strict
-- Pixel Post intro slide. Shows a centered overlay on level start with the
-- title + body from the server-fired `PixelPostIntro` event, fades after
-- DurationSeconds. P0 is non-gating: Wave 1 has already started server-side.
-- The P2 gated version will wait on a `RequestDismissIntro` from both clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIFolder = script.Parent
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local activeOverlay: Frame? = nil
local activeToken = 0

local function teardown()
	if activeOverlay then
		activeOverlay:Destroy()
		activeOverlay = nil
	end
end

local function show(payload)
	teardown()
	local screen = UIBuilder.GetScreenGui()
	local overlay = Instance.new("Frame")
	overlay.Name = "PixelPostIntro"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 200
	overlay.Parent = screen
	activeOverlay = overlay

	local card = UIStyle.MakePanel({
		Name = "Card",
		Size = UDim2.new(0, 540, 0, 200),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = overlay,
	})
	card.ZIndex = 201
	UIBuilder.PadLayout(card, 18)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = card

	local stamp = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "✉ PIXEL POST",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.Highlight,
		LayoutOrder = 1,
	})
	stamp.ZIndex = 202
	stamp.Parent = card

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 36),
		Text = payload.Title or "Pixel Post: Outbound Sorting",
		TextSize = UIStyle.TextSize.Heading,
		LayoutOrder = 2,
	})
	title.ZIndex = 202
	title.Parent = card

	local body = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 96),
		Text = payload.Body or "First shift! Talk to your buddy.",
		TextSize = UIStyle.TextSize.Body,
		TextWrapped = true,
		LayoutOrder = 3,
	})
	body.ZIndex = 202
	body.Parent = card

	activeToken += 1
	local token = activeToken
	local duration = tonumber(payload.DurationSeconds) or 5
	task.delay(duration, function()
		if token ~= activeToken then return end
		if not activeOverlay or not activeOverlay.Parent then return end
		local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(activeOverlay, fadeInfo, { BackgroundTransparency = 1 }):Play()
		task.delay(0.4, function()
			if token ~= activeToken then return end
			teardown()
		end)
	end)
end

RemoteService.OnClientEvent("PixelPostIntro", function(payload)
	if typeof(payload) ~= "table" then return end
	show(payload)
end)

RemoteService.OnClientEvent("LevelEnded", function(_payload)
	teardown()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	teardown()
end)
