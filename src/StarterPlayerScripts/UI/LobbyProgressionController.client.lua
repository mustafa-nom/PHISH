--!strict
-- Tiny lobby HUD that shows the local player's Trust Seeds + treehouse
-- level. Also toggles visibility on placeholder treehouse stages User 1
-- placed in the lobby (named "TreehouseStage1", "TreehouseStage2", etc.)
-- inside `Workspace.Lobby.Treehouse` if present.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIFolder = script.Parent
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local panel: Frame? = nil
local seedsLabel: TextLabel? = nil
local treehouseLabel: TextLabel? = nil

local function build()
	if panel and panel.Parent then return end
	local screen = UIBuilder.GetScreenGui()
	panel = UIStyle.MakePanel({
		Name = "LobbyProgression",
		Size = UDim2.new(0, 220, 0, 60),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 12),
		Parent = screen,
	})
	UIBuilder.PadLayout(panel :: Frame, 8)

	seedsLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "🌱 0 Trust Seeds",
		TextSize = UIStyle.TextSize.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	seedsLabel.Parent = panel

	treehouseLabel = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 24),
		Text = "Treehouse: stage 1",
		TextSize = UIStyle.TextSize.Caption,
		TextColor3 = UIStyle.Palette.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	treehouseLabel.Parent = panel
end

local function updateTreehouseVisuals(treehouseLevel: number)
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then return end
	local treehouse = lobby:FindFirstChild("Treehouse")
	if not treehouse then return end
	for _, child in ipairs(treehouse:GetChildren()) do
		local stage = string.match(child.Name, "TreehouseStage(%d+)")
		if stage then
			local stageNum = tonumber(stage)
			if stageNum then
				if child:IsA("Model") then
					for _, descendant in ipairs(child:GetDescendants()) do
						if descendant:IsA("BasePart") then
							descendant.Transparency = (stageNum == treehouseLevel) and 0 or 1
							descendant.CanCollide = stageNum == treehouseLevel
						end
					end
				elseif child:IsA("BasePart") then
					child.Transparency = (stageNum == treehouseLevel) and 0 or 1
					child.CanCollide = stageNum == treehouseLevel
				end
			end
		end
	end
end

build()

if _G.BuddyBridge_InitialProgression then
	local p = _G.BuddyBridge_InitialProgression
	if seedsLabel then seedsLabel.Text = ("🌱 %d Trust Seeds"):format(p.TrustSeeds or 0) end
	if treehouseLabel then treehouseLabel.Text = ("Treehouse: stage %d"):format(p.TreehouseLevel or 1) end
	updateTreehouseVisuals(p.TreehouseLevel or 1)
end

RemoteService.OnClientEvent("ProgressionUpdated", function(payload)
	if typeof(payload) ~= "table" then return end
	if seedsLabel then seedsLabel.Text = ("🌱 %d Trust Seeds"):format(payload.TrustSeeds or 0) end
	if treehouseLabel then treehouseLabel.Text = ("Treehouse: stage %d"):format(payload.TreehouseLevel or 1) end
	updateTreehouseVisuals(payload.TreehouseLevel or 1)
end)
