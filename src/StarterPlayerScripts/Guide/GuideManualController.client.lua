--!strict
-- Renders the active manual on the booth's ControlPanel SurfaceGui.
-- Resolves the SurfaceGui via the slot index in RoundStarted payload.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LevelTypes = require(Modules:WaitForChild("LevelTypes"))
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))

local Manuals = script.Parent:WaitForChild("Manuals")
local StrangerDangerManual = require(Manuals:WaitForChild("StrangerDangerManual"))
local BackpackCheckpointManual = require(Manuals:WaitForChild("BackpackCheckpointManual"))
local StrangerDangerBookContent = require(Manuals:WaitForChild("StrangerDangerBookContent"))
local BookView = require(script.Parent:WaitForChild("BookView"))

local state = {
	Role = RoleTypes.None,
	RoundId = nil :: string?,
	SlotIndex = nil :: number?,
	BoothName = nil :: string?,
	LevelType = nil :: string?,
	ActiveManual = nil :: any?,
	ManualPayload = nil :: any?,
	-- Fallback: a screen-space backup if we can't find the SurfaceGui.
	FallbackContainer = nil :: ScreenGui?,
	-- Polished book overlay. Always shown for the Guide on top of the
	-- existing SurfaceGui manual so they have a comfy reading experience.
	Book = nil :: any?,
}

local function destroyBook()
	if state.Book then
		state.Book:Destroy()
		state.Book = nil
	end
end

local function ensureBook()
	if state.Role ~= RoleTypes.Guide then return end
	if state.LevelType ~= LevelTypes.StrangerDangerPark then
		destroyBook()
		return
	end
	if state.Book then return end
	local players = game:GetService("Players")
	local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
	state.Book = BookView.new(playerGui, StrangerDangerBookContent)
end

local function findControlPanelSurfaceGui(): SurfaceGui?
	if not state.SlotIndex then return nil end
	local slotsRoot = Workspace:FindFirstChild("PlayArenaSlots")
	if not slotsRoot then return nil end
	for _, slot in ipairs(slotsRoot:GetChildren()) do
		if slot:GetAttribute("SlotIndex") == state.SlotIndex then
			local boothFolder = slot:FindFirstChild("Booth")
			if not boothFolder then return nil end
			local boothModel = state.BoothName and boothFolder:FindFirstChild(state.BoothName) or boothFolder:FindFirstChildOfClass("Model")
			if not boothModel then return nil end
			local controlPanel = boothModel:FindFirstChild("ControlPanel")
			if not controlPanel then return nil end
			local surfaceGui = controlPanel:FindFirstChildOfClass("SurfaceGui")
			if surfaceGui then return surfaceGui end
		end
	end
	return nil
end

local function getRenderTarget(): Instance
	-- Try the booth's SurfaceGui; fall back to a corner ScreenGui so the
	-- demo still works when the map ships without a SurfaceGui mounted.
	local surfaceGui = findControlPanelSurfaceGui()
	if surfaceGui then
		if state.FallbackContainer then
			state.FallbackContainer:Destroy()
			state.FallbackContainer = nil
		end
		return surfaceGui
	end
	if not state.FallbackContainer then
		local players = game:GetService("Players")
		local screen = Instance.new("ScreenGui")
		screen.Name = "BB_GuideManualFallback"
		screen.ResetOnSpawn = false
		screen.Parent = players.LocalPlayer:WaitForChild("PlayerGui")
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 320, 0, 480)
		frame.AnchorPoint = Vector2.new(0, 0.5)
		frame.Position = UDim2.new(0, 12, 0.5, 0)
		frame.BackgroundColor3 = UIStyle.Palette.Panel
		frame.BorderSizePixel = 0
		frame.Name = "ManualPanel"
		frame.Parent = screen
		UIStyle.ApplyCorner(frame)
		UIStyle.ApplyStroke(frame)
		state.FallbackContainer = screen
	end
	local frame = state.FallbackContainer:FindFirstChild("ManualPanel")
	return frame or state.FallbackContainer
end

local function renderManual()
	if state.Role ~= RoleTypes.Guide then return end
	if not state.LevelType then return end
	if not state.ManualPayload then return end
	local target = getRenderTarget()
	if state.ActiveManual then
		state.ActiveManual:Destroy()
		state.ActiveManual = nil
	end
	if state.LevelType == LevelTypes.StrangerDangerPark then
		state.ActiveManual = StrangerDangerManual.Build(target, state.ManualPayload)
	elseif state.LevelType == LevelTypes.BackpackCheckpoint then
		state.ActiveManual = BackpackCheckpointManual.Build(target, state.ManualPayload)
	end
end

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	state.Role = payload.Role or RoleTypes.None
end)

RemoteService.OnClientEvent("RoundStarted", function(payload)
	state.RoundId = payload.RoundId
	state.SlotIndex = payload.SlotIndex
	state.BoothName = payload.BoothName
end)

RemoteService.OnClientEvent("LevelStarted", function(payload)
	if payload.RoundId ~= state.RoundId then return end
	state.LevelType = payload.LevelType
	-- Manual will arrive separately via GuideManualUpdated for the Guide.
	-- For the Explorer, we just clear local state.
	if state.Role ~= RoleTypes.Guide then
		state.ManualPayload = nil
		if state.ActiveManual then
			state.ActiveManual:Destroy()
			state.ActiveManual = nil
		end
		return
	end
end)

RemoteService.OnClientEvent("GuideManualUpdated", function(payload)
	if state.Role ~= RoleTypes.Guide then return end
	if payload.RoundId ~= state.RoundId then return end
	state.ManualPayload = payload.Manual
	state.LevelType = payload.LevelType
	renderManual()
	ensureBook()
end)

RemoteService.OnClientEvent("NpcDescriptionShown", function(payload)
	if state.Role ~= RoleTypes.Guide then return end
	if payload.Audience ~= "Guide" then return end
	if not state.ActiveManual then return end
	if state.LevelType ~= LevelTypes.StrangerDangerPark then return end
	state.ActiveManual:Highlight(payload.Traits or {})
end)

RemoteService.OnClientEvent("ConveyorItemSpawned", function(payload)
	if state.Role ~= RoleTypes.Guide then return end
	if payload.RoundId ~= state.RoundId then return end
	if not state.ActiveManual then return end
	if state.LevelType ~= LevelTypes.BackpackCheckpoint then return end
	state.ActiveManual:Highlight(payload.ItemKey)
end)

RemoteService.OnClientEvent("LevelEnded", function(payload)
	if payload.RoundId ~= state.RoundId then return end
	if state.ActiveManual then
		state.ActiveManual:Destroy()
		state.ActiveManual = nil
	end
	destroyBook()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	state.RoundId = nil
	state.LevelType = nil
	state.ManualPayload = nil
	if state.ActiveManual then
		state.ActiveManual:Destroy()
		state.ActiveManual = nil
	end
	if state.FallbackContainer then
		state.FallbackContainer:Destroy()
		state.FallbackContainer = nil
	end
	destroyBook()
end)
