--!strict
-- Renders the small NPC trait card for the Explorer when they inspect, and
-- mirrors annotations into the world (colored ring around the NPC).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScenarioRegistry = require(Modules:WaitForChild("ScenarioRegistry"))
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))

local UIBuilder = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local localPlayer = Players.LocalPlayer
local _ = localPlayer
local currentRole = RoleTypes.None
local card: Frame? = nil
local rings: { [string]: BasePart } = {}

local function getNpcModel(npcId: string): Model?
	for _, slot in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.PlayArenaSlot)) do
		local playArea = slot:FindFirstChild("PlayArea")
		if playArea then
			for _, level in ipairs(playArea:GetChildren()) do
				local model = level:FindFirstChild(npcId)
				if model and model:IsA("Model") then
					return model
				end
			end
		end
	end
	return nil
end

local function clearCard()
	if card and card.Parent then card:Destroy() end
	card = nil
end

local function showCard(npcId: string, traits: { string })
	clearCard()
	local screen = UIBuilder.GetScreenGui()
	card = UIStyle.MakePanel({
		Name = "NpcDescriptionCard",
		Size = UDim2.new(0, 320, 0, 200),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Parent = screen,
	})
	UIBuilder.PadLayout(card :: Frame, 12)

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 28),
		Text = "What you see",
		TextSize = UIStyle.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Parent = card

	local body = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 1, -36),
		Position = UDim2.new(0, 0, 0, 32),
		Text = "",
		TextSize = UIStyle.TextSize.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	local lines: { string } = {}
	for _, tag in ipairs(traits) do
		table.insert(lines, "• " .. ScenarioRegistry.GetTraitDisplay(tag))
	end
	body.Text = table.concat(lines, "\n")
	body.Parent = card

	task.delay(8, function()
		if card and card:GetAttribute("BB_NpcId") == npcId then
			clearCard()
		end
	end)
	(card :: any):SetAttribute("BB_NpcId", npcId)
end

local function ringColorForMarker(marker: string?): Color3
	if marker == "Safe" then return UIStyle.Palette.Safe end
	if marker == "Risky" then return UIStyle.Palette.Risky end
	if marker == "AskFirst" then return UIStyle.Palette.AskFirst end
	return UIStyle.Palette.Highlight
end

local function clearRing(npcId: string)
	if rings[npcId] then
		rings[npcId]:Destroy()
		rings[npcId] = nil
	end
end

local function applyRing(npcId: string, marker: string)
	clearRing(npcId)
	if marker == "Clear" then return end
	local model = getNpcModel(npcId)
	if not model then return end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local ring = Instance.new("Part")
	ring.Name = "BB_AnnotationRing"
	ring.Anchored = false
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 8, 8)
	ring.Material = Enum.Material.Neon
	ring.Color = ringColorForMarker(marker)
	ring.Transparency = 0.2
	ring.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90)) + Vector3.new(0, -2.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring
	ring.Parent = model
	rings[npcId] = ring
end

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	currentRole = payload.Role or RoleTypes.None
end)

RemoteService.OnClientEvent("NpcDescriptionShown", function(payload)
	if currentRole ~= RoleTypes.Explorer then return end
	if payload.Audience ~= "Explorer" then return end
	showCard(payload.NpcId, payload.Traits or {})
end)

RemoteService.OnClientEvent("NpcAnnotationUpdated", function(payload)
	-- Both Explorer and Guide see the world ring; helps the Guide confirm
	-- the annotation took effect.
	applyRing(payload.NpcId, payload.Marker)
end)

RemoteService.OnClientEvent("LevelEnded", function(_payload)
	for npcId in pairs(rings) do
		clearRing(npcId)
	end
	clearCard()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	for npcId in pairs(rings) do
		clearRing(npcId)
	end
	clearCard()
end)
