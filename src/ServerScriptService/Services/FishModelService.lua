--!strict
-- Builds ReplicatedStorage.PhishFishTemplates for client viewport previews and
-- creates holdable fish Tools when players correctly identify a catch.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhishDex = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishDex"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))

local FishModelService = {}

local FOLDER_NAME = "PhishFishTemplates"
local FISH_TOOL_PREFIX = "CaughtFish_"

local C3 = Color3.fromRGB
local V3 = Vector3.new

local VISUALS: { [string]: { body: Color3, accent: Color3, scale: number, elongated: boolean?, flat: boolean? } } = {
	UrgencyEel = { body = C3(220, 60, 50), accent = C3(255, 230, 0), scale = 1.3, elongated = true },
	AuthorityAnglerfish = { body = C3(20, 30, 80), accent = C3(255, 220, 100), scale = 1.1 },
	RewardTuna = { body = C3(255, 200, 40), accent = C3(255, 255, 200), scale = 1.2 },
	CuriosityCatfish = { body = C3(120, 120, 130), accent = C3(220, 220, 220), scale = 1.0 },
	FearBass = { body = C3(40, 30, 60), accent = C3(220, 30, 40), scale = 1.2 },
	FamiliarityFlounder = { body = C3(220, 200, 200), accent = C3(180, 160, 200), scale = 1.0, flat = true },
	PlainCarp = { body = C3(120, 180, 200), accent = C3(180, 220, 240), scale = 1.0 },
	HonestHerring = { body = C3(200, 210, 220), accent = C3(240, 240, 250), scale = 1.0 },
}

local function mkPart(name: string, parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function weldTo(primary: BasePart, model: Model)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = child
			weld.Parent = primary
		end
	end
end

local function addExtras(model: Model, body: BasePart, speciesId: string, s: number)
	if speciesId == "UrgencyEel" then
		mkPart("Bolt", model, {
			Size = V3(0.6 * s, 1.2 * s, 0.3 * s),
			Color = C3(255, 230, 0),
			Material = Enum.Material.Neon,
			CFrame = body.CFrame * CFrame.new(0, 1.0 * s, 0),
		})
	elseif speciesId == "AuthorityAnglerfish" then
		mkPart("Badge", model, {
			Size = V3(0.8 * s, 0.8 * s, 0.15 * s),
			Color = C3(255, 220, 100),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder,
			CFrame = body.CFrame * CFrame.new(0.5 * s, 0.2 * s, 0.7 * s),
		})
	elseif speciesId == "RewardTuna" then
		for i = 1, 4 do
			mkPart("Confetti_" .. i, model, {
				Size = V3(0.2 * s, 0.2 * s, 0.2 * s),
				Color = C3(120 + i * 25, 220 - i * 18, 180 + i * 8),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				CFrame = body.CFrame * CFrame.new((i - 2.5) * 0.5 * s, 0.6 * s, 0.5 * s),
			})
		end
	elseif speciesId == "CuriosityCatfish" then
		for i, side in ipairs({ -1, 1 }) do
			mkPart("Eye_" .. i, model, {
				Size = V3(0.6 * s, 0.6 * s, 0.6 * s),
				Color = C3(255, 255, 255),
				Shape = Enum.PartType.Ball,
				CFrame = body.CFrame * CFrame.new(0.6 * s, 0.3 * s, side * 0.6 * s),
			})
		end
	elseif speciesId == "FearBass" then
		for i, side in ipairs({ -1, 1 }) do
			local eye = mkPart("EyeRed_" .. i, model, {
				Size = V3(0.4 * s, 0.4 * s, 0.4 * s),
				Color = C3(255, 60, 60),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				CFrame = body.CFrame * CFrame.new(0.6 * s, 0.3 * s, side * 0.5 * s),
			})
			local light = Instance.new("PointLight")
			light.Color = eye.Color
			light.Range = 4
			light.Brightness = 2
			light.Parent = eye
		end
	elseif speciesId == "FamiliarityFlounder" then
		for i = 1, 3 do
			mkPart("FakeStripe_" .. i, model, {
				Size = V3(0.2 * s, 1.4 * s, 0.05 * s),
				Color = C3(180 - i * 10, 160 - i * 10, 200),
				CFrame = body.CFrame * CFrame.new((i - 2) * 0.7 * s, 0, 0.6 * s),
			})
		end
	end
end

local function buildFishModel(species: PhishDex.Species): Model
	local visual = VISUALS[species.id] or VISUALS.PlainCarp
	local model = Instance.new("Model")
	model.Name = species.id

	local s = visual.scale
	local sx, sy, sz
	if visual.elongated then
		sx, sy, sz = 4 * s, 1 * s, 1 * s
	elseif visual.flat then
		sx, sy, sz = 3 * s, 0.5 * s, 2.5 * s
	else
		sx, sy, sz = 3 * s, 1.5 * s, 1.5 * s
	end

	local body = mkPart("Body", model, {
		Size = V3(sx, sy, sz),
		Color = visual.body,
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(),
	})
	local tail = Instance.new("WedgePart")
	tail.Name = "Tail"
	tail.Anchored = false
	tail.CanCollide = false
	tail.Massless = true
	tail.Size = V3(1.2 * s, sy, 1 * s)
	tail.Color = visual.accent
	tail.Material = Enum.Material.SmoothPlastic
	tail.CFrame = body.CFrame * CFrame.new(-(sx / 2 + 0.3 * s), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	tail.Parent = model

	addExtras(model, body, species.id, s)
	weldTo(body, model)
	model.PrimaryPart = body
	model:SetAttribute("FishId", species.id)
	model:SetAttribute("DisplayName", species.displayName)
	model:SetAttribute("IsLegit", species.isLegit)
	CollectionService:AddTag(model, "PhishFishTemplate")
	return model
end

local function getTemplate(speciesId: string): Model?
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local model = folder and folder:FindFirstChild(speciesId)
	if model and model:IsA("Model") then return model end
	return nil
end

local function createTool(speciesId: string, sellValue: number): Tool?
	local species = PhishDex.Get(speciesId)
	local template = species and getTemplate(speciesId)
	if not species or not template then return nil end

	local tool = Instance.new("Tool")
	tool.Name = FISH_TOOL_PREFIX .. speciesId
	tool.ToolTip = species.displayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.5, -1.4) * CFrame.Angles(0, math.rad(90), 0)
	tool:SetAttribute("PhishFishTool", true)
	tool:SetAttribute("FishId", speciesId)
	tool:SetAttribute("DisplayName", species.displayName)
	tool:SetAttribute("SellValue", sellValue)
	tool:SetAttribute("Phish3DIcon", true)  -- Satchel renders this slot as a 3D viewport

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = V3(0.35, 0.35, 0.35)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local fish = template:Clone()
	fish.Name = "FishModel"
	fish:PivotTo(handle.CFrame * CFrame.new(0, 0.25, -1.4) * CFrame.Angles(0, math.rad(90), 0))
	for _, part in ipairs(fish:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end
	fish.Parent = tool
	return tool
end

function FishModelService.Init()
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	for _, species in ipairs(PhishDex.Species) do
		buildFishModel(species).Parent = folder
	end
end

function FishModelService.GiveCaughtFish(player: Player, speciesId: string, sellValue: number): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false end

	local tool = createTool(speciesId, sellValue)
	if not tool then return false end
	tool.Parent = backpack

	local profile = DataService.Get(player)
	profile.fishInventory[speciesId] = (profile.fishInventory[speciesId] or 0) + 1
	return true
end

function FishModelService.IsFishTool(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute("PhishFishTool") == true
end

return FishModelService
