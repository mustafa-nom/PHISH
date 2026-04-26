--!strict
-- Top-of-screen HUD: pearls + XP + currently equipped rod. Listens to
-- InventoryUpdated.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RodRegistry = require(Modules:WaitForChild("RodRegistry"))
local NumberFormatter = require(Modules:WaitForChild("NumberFormatter"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local panel = UIStyle.MakePanel({
	Name = "PhishStatusHud",
	Size = UDim2.new(0, 360, 0, 56),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Parent = screen,
})

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local function makeStat(parent: Frame, name: string, layoutOrder: number): TextLabel
	local label = UIStyle.MakeLabel({
		Size = UDim2.new(0, 110, 1, -8),
		Text = name,
		TextSize = UIStyle.TextSize.Body,
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
	return label
end

local pearlsLabel = makeStat(panel, "Pearls 0", 1)
local xpLabel = makeStat(panel, "XP 0", 2)
local rodLabel = makeStat(panel, "Wooden Rod", 3)

local function update(snapshot)
	if typeof(snapshot) ~= "table" then return end
	pearlsLabel.Text = ("Pearls %s"):format(NumberFormatter.Comma(snapshot.Pearls or 0))
	xpLabel.Text = ("XP %s"):format(NumberFormatter.Comma(snapshot.Xp or 0))
	local rod = snapshot.EquippedRodId and RodRegistry.GetById(snapshot.EquippedRodId)
	rodLabel.Text = rod and rod.displayName or "—"
end

RemoteService.OnClientEvent("InventoryUpdated", update)

task.spawn(function()
	local ok, snap = pcall(function()
		return RemoteService.InvokeServer("GetSnapshot")
	end)
	if ok and snap then update(snap) end
end)
