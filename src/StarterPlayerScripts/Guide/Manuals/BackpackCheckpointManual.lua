--!strict
-- Renders the Backpack Checkpoint sorting chart on a SurfaceGui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local ScenarioRegistry = require(Modules:WaitForChild("ScenarioRegistry"))

local BackpackCheckpointManual = {}

export type Manual = {
	Frame: Frame,
	Highlight: (self: any, itemKey: string) -> (),
	Destroy: (self: any) -> (),
}

local LANE_ORDER = { "PackIt", "AskFirst", "LeaveIt" }

local function makeLaneSection(parent: Frame, lane: string, items: { string }): { [string]: Frame }
	local theme = ItemRegistry.LaneTheme[lane]
	local section = Instance.new("Frame")
	section.Name = "Lane_" .. lane
	section.Size = UDim2.new(1, 0, 0, 24 + (#items * 24))
	section.BackgroundTransparency = 1
	section.LayoutOrder = #parent:GetChildren()
	section.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = section

	local prefix = "⛔ "
	if lane == "PackIt" then
		prefix = "✅ "
	elseif lane == "AskFirst" then
		prefix = "⚠️ "
	end
	local header = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 22),
		Text = prefix .. theme.Label,
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = theme.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})
	header.Parent = section

	local rows: { [string]: Frame } = {}
	for i, key in ipairs(items) do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. key
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundColor3 = UIStyle.Palette.Panel
		row.BorderSizePixel = 0
		row.LayoutOrder = i + 1
		row.Parent = section
		UIStyle.ApplyCorner(row, UDim.new(0, 4))

		local label = UIStyle.MakeLabel({
			Size = UDim2.new(1, -8, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			Text = ScenarioRegistry.GetItemDisplay(key),
			TextSize = UIStyle.TextSize.Caption,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.Parent = row
		rows[key] = row
	end
	return rows
end

function BackpackCheckpointManual.Build(parent: Instance, manualPayload): Manual
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == "BB_Manual" then
			child:Destroy()
		end
	end

	local frame = Instance.new("Frame")
	frame.Name = "BB_Manual"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = UIStyle.Palette.Background
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIStyle.ApplyCorner(frame, UIStyle.SmallCorner)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 32),
		Text = "Backpack Checkpoint Chart",
		TextSize = UIStyle.TextSize.Heading,
	})
	title.Parent = frame

	local lanes = manualPayload and manualPayload.Lanes or {
		PackIt = ItemRegistry.GetKeysForLane("PackIt"),
		AskFirst = ItemRegistry.GetKeysForLane("AskFirst"),
		LeaveIt = ItemRegistry.GetKeysForLane("LeaveIt"),
	}

	local allRows: { [string]: Frame } = {}
	for _, lane in ipairs(LANE_ORDER) do
		local rows = makeLaneSection(frame, lane, lanes[lane] or {})
		for k, v in pairs(rows) do
			allRows[k] = v
		end
	end

	local manual = {} :: Manual
	manual.Frame = frame
	manual.Highlight = function(_self, itemKey: string)
		for k, row in pairs(allRows) do
			row.BackgroundColor3 = UIStyle.Palette.Panel
		end
		local row = allRows[itemKey]
		if row then
			row.BackgroundColor3 = UIStyle.Palette.Highlight
		end
	end
	manual.Destroy = function(self)
		if self.Frame and self.Frame.Parent then
			self.Frame:Destroy()
		end
	end
	return manual
end

return BackpackCheckpointManual
