--!strict
-- Locks the Guide's camera to a "looking down at a book" pose while a level
-- is active. The book itself is a full-screen ScreenGui (BookView) so this
-- camera mostly affects the soft warm context behind it — a slight downward
-- tilt sells the "I'm reading at a desk" feel.
--
-- Restores the default Custom camera when the level ends or the player
-- swaps out of the Guide role.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local RoleTypes = require(Modules:WaitForChild("RoleTypes"))

local LocalPlayer = Players.LocalPlayer

local state = {
	Role = RoleTypes.None,
	RoundId = nil :: string?,
	SlotIndex = nil :: number?,
	BoothName = nil :: string?,
	LevelType = nil :: string?,
	Active = false,
}

local function findGuideSpawn(): BasePart?
	if not state.SlotIndex then return nil end
	local slotsRoot = Workspace:FindFirstChild("PlayArenaSlots")
	if not slotsRoot then return nil end
	for _, slot in ipairs(slotsRoot:GetChildren()) do
		if slot:GetAttribute("SlotIndex") == state.SlotIndex then
			local boothFolder = slot:FindFirstChild("Booth")
			if not boothFolder then return nil end
			local boothModel = state.BoothName and boothFolder:FindFirstChild(state.BoothName)
				or boothFolder:FindFirstChildOfClass("Model")
			if boothModel then
				return boothModel:FindFirstChild("GuideSpawn", true) :: BasePart?
			end
		end
	end
	return nil
end

local function setLooking(camera: Camera, anchor: BasePart)
	-- position camera ~6 studs back and 4 studs up from the guide spawn,
	-- looking down ~25deg toward a "desk" point in front of the player.
	local pos = anchor.Position + Vector3.new(0, 4, 6)
	local target = anchor.Position + Vector3.new(0, 1.4, 1.5)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(pos, target)
end

local function tryActivate()
	if state.Role ~= RoleTypes.Guide or not state.LevelType then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local anchor = findGuideSpawn()
	if not anchor then
		-- if the booth hasn't replicated yet, retry on the next frame
		task.defer(tryActivate)
		return
	end
	setLooking(camera, anchor)
	state.Active = true
end

local function release()
	if not state.Active then return end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
	end
	state.Active = false
end

RemoteService.OnClientEvent("RoleAssigned", function(payload)
	state.Role = payload.Role or RoleTypes.None
	if state.Role ~= RoleTypes.Guide then
		release()
	else
		tryActivate()
	end
end)

RemoteService.OnClientEvent("RoundStarted", function(payload)
	state.RoundId = payload.RoundId
	state.SlotIndex = payload.SlotIndex
	state.BoothName = payload.BoothName
end)

RemoteService.OnClientEvent("LevelStarted", function(payload)
	if payload.RoundId ~= state.RoundId then return end
	state.LevelType = payload.LevelType
	tryActivate()
end)

RemoteService.OnClientEvent("LevelEnded", function(payload)
	if payload.RoundId ~= state.RoundId then return end
	state.LevelType = nil
	release()
end)

RemoteService.OnClientEvent("RoundEnded", function(_payload)
	state.RoundId = nil
	state.LevelType = nil
	release()
end)
