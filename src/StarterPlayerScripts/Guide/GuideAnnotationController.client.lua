--!strict
-- Annotation buttons (✅/🚩/⚠️/Clear). Targets:
--   * Stranger Danger Park: most-recently-shown NPC (by NpcDescriptionShown).
--   * Backpack Checkpoint: most-recently-spawned belt item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))

local UIBuilder = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local state = {
	Role = RoleTypes.None,
	RoundId = nil :: string?,
	LevelType = nil :: string?,
	NpcId = nil :: string?,
	ItemId = nil :: string?,
}

local panel: Frame? = nil

local function teardown()
	if panel then
		panel:Destroy()
		panel = nil
	end
end

local function buildButtons()
	if state.Role ~= RoleTypes.Guide then teardown() return end
	if not state.RoundId then teardown() return end
	if not state.LevelType then teardown() return end
	teardown()
	local screen = UIBuilder.GetScreenGui()
	panel = UIStyle.MakePanel({
		Name = "GuideAnnotation",
		Size = UDim2.new(0, 360, 0, 80),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Parent = screen,
	})
	UIBuilder.PadLayout(panel :: Frame, 8)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = panel

	local function makeBtn(label: string, color: Color3, onClick: () -> ())
		local btn = UIStyle.MakeButton({
			Size = UDim2.new(0, 70, 1, 0),
			Text = label,
			BackgroundColor3 = color,
			TextSize = UIStyle.TextSize.Body,
		})
		btn.Parent = panel
		btn.Activated:Connect(onClick)
		return btn
	end

	if state.LevelType == LevelTypes.StrangerDangerPark then
		makeBtn("✅ Safe", UIStyle.Palette.Safe, function()
			if state.NpcId then RemoteService.FireServer("RequestAnnotateNpc", state.NpcId, "Safe") end
		end)
		makeBtn("🚩 Risky", UIStyle.Palette.Risky, function()
			if state.NpcId then RemoteService.FireServer("RequestAnnotateNpc", state.NpcId, "Risky") end
		end)
		makeBtn("⚠️ Ask", UIStyle.Palette.AskFirst, function()
			if state.NpcId then RemoteService.FireServer("RequestAnnotateNpc", state.NpcId, "AskFirst") end
		end)
		makeBtn("Clear", UIStyle.Palette.PanelStroke, function()
			if state.NpcId then RemoteService.FireServer("RequestAnnotateNpc", state.NpcId, "Clear") end
		end)
	elseif state.LevelType == LevelTypes.BackpackCheckpoint then
		makeBtn("✅ Pack", UIStyle.Palette.Safe, function()
			if state.ItemId then RemoteService.FireServer("RequestAnnotateItem", state.ItemId, "PackIt") end
		end)
		makeBtn("⚠️ Ask", UIStyle.Palette.AskFirst, function()
			if state.ItemId then RemoteService.FireServer("RequestAnnotateItem", state.ItemId, "AskFirst") end
		end)
		makeBtn("⛔ Leave", UIStyle.Palette.Risky, function()
			if state.ItemId then RemoteService.FireServer("RequestAnnotateItem", state.ItemId, "LeaveIt") end
		end)
		makeBtn("Clear", UIStyle.Palette.PanelStroke, function()
			if state.ItemId then RemoteService.FireServer("RequestAnnotateItem", state.ItemId, "Clear") end
		end)
	end
end

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	state.Role = payload.Role or RoleTypes.None
	buildButtons()
end)

RemoteService.OnClientEvent("RoundStarted", function(payload)
	state.RoundId = payload.RoundId
end)

RemoteService.OnClientEvent("LevelStarted", function(payload)
	if payload.RoundId ~= state.RoundId then return end
	state.LevelType = payload.LevelType
	state.NpcId = nil
	state.ItemId = nil
	buildButtons()
end)

RemoteService.OnClientEvent("NpcDescriptionShown", function(payload)
	if state.Role ~= RoleTypes.Guide then return end
	if payload.Audience ~= "Guide" then return end
	state.NpcId = payload.NpcId
end)

RemoteService.OnClientEvent("ConveyorItemSpawned", function(payload)
	if state.Role ~= RoleTypes.Guide then return end
	state.ItemId = payload.ItemId
end)

RemoteService.OnClientEvent("LevelEnded", function(_payload)
	state.LevelType = nil
	teardown()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	state.Role = RoleTypes.None
	state.RoundId = nil
	state.LevelType = nil
	state.NpcId = nil
	state.ItemId = nil
	teardown()
end)
