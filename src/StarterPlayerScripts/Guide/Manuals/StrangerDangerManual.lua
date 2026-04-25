--!strict
-- Renders the Stranger Danger trait reference manual on a SurfaceGui.
-- Highlights matching trait rows when the Explorer inspects an NPC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NpcRegistry = require(Modules:WaitForChild("NpcRegistry"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local ScenarioRegistry = require(Modules:WaitForChild("ScenarioRegistry"))

local StrangerDangerManual = {}

export type Manual = {
	Frame: Frame,
	TraitRows: { [string]: Frame },
	Highlight: (self: any, traitTags: { string }) -> (),
	Destroy: (self: any) -> (),
}

local function makeRow(parent: Frame, tag: string, text: string, kind: string)
	local row = Instance.new("Frame")
	row.Name = "Row_" .. tag
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundColor3 = UIStyle.Palette.Panel
	row.BorderSizePixel = 0
	row.LayoutOrder = #parent:GetChildren()
	row.Parent = parent
	UIStyle.ApplyCorner(row, UIStyle.SmallCorner)

	local marker = Instance.new("Frame")
	marker.Size = UDim2.new(0, 6, 1, -6)
	marker.Position = UDim2.new(0, 4, 0, 3)
	marker.BackgroundColor3 = (kind == "Risky") and UIStyle.Palette.Risky or UIStyle.Palette.Safe
	marker.BorderSizePixel = 0
	marker.Parent = row
	UIStyle.ApplyCorner(marker, UDim.new(0, 3))

	local label = UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		Text = (kind == "Risky" and "🚩 " or "✅ ") .. text,
		TextSize = UIStyle.TextSize.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
	label.Parent = row
	return row
end

function StrangerDangerManual.Build(parent: Instance, manualPayload): Manual
	-- Wipe any previous manual
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
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 36),
		Text = "Stranger Danger Manual",
		TextSize = UIStyle.TextSize.Heading,
	})
	title.Parent = frame

	local riskyHeader = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "🚩 Stay away if you see:",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.Risky,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	riskyHeader.Parent = frame

	local rows: { [string]: Frame } = {}
	local riskyTags = (manualPayload and manualPayload.RiskyTags) or NpcRegistry.GetTagsByRisk(NpcRegistry.Risk.Risky)
	for _, tag in ipairs(riskyTags) do
		rows[tag] = makeRow(frame, tag, ScenarioRegistry.GetTraitDisplay(tag), "Risky")
	end

	local safeHeader = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "✅ Probably safe if you see:",
		TextSize = UIStyle.TextSize.Body,
		TextColor3 = UIStyle.Palette.Safe,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	safeHeader.Parent = frame

	local safeTags = (manualPayload and manualPayload.SafeTags) or NpcRegistry.GetTagsByRisk(NpcRegistry.Risk.Safe)
	for _, tag in ipairs(safeTags) do
		rows[tag] = makeRow(frame, tag, ScenarioRegistry.GetTraitDisplay(tag), "Safe")
	end

	local manual = {} :: Manual
	manual.Frame = frame
	manual.TraitRows = rows
	manual.Highlight = function(self, traitTags: { string })
		for tag, row in pairs(self.TraitRows) do
			row.BackgroundColor3 = UIStyle.Palette.Panel
		end
		for _, tag in ipairs(traitTags or {}) do
			local row = self.TraitRows[tag]
			if row then
				row.BackgroundColor3 = UIStyle.Palette.Highlight
			end
		end
	end
	manual.Destroy = function(self)
		if self.Frame and self.Frame.Parent then
			self.Frame:Destroy()
		end
	end

	return manual
end

return StrangerDangerManual
