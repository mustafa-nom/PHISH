--!strict
-- Client-side buoyancy for non-collide PhishWater tiles. When the character is
-- low over water, apply an upward spring so they hover and bob at the surface
-- while normal Humanoid movement still controls horizontal swimming.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PhishConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PhishConstants"))

local player = Players.LocalPlayer

local WATER_SURFACE_OFFSET = -1.6
local ACTIVATE_ABOVE_SURFACE = 4.25
local RAYCAST_UP = 18
local RAYCAST_DOWN = 42
local SPRING = 42
local DAMPING = 10
local MAX_EXTRA_FORCE = 5200
local BOB_HEIGHT = 0.28
local BOB_SPEED = 3.1

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local swimAttachment: Attachment? = nil
local buoyancy: VectorForce? = nil
local wasSwimming = false

local function getWaterFolder(): Instance?
	local map = Workspace:FindFirstChild("PhishMap")
	return map and map:FindFirstChild("PhishWater")
end

local function ensureForce()
	local currentRoot = root
	if not currentRoot then return end

	if not swimAttachment or swimAttachment.Parent ~= currentRoot then
		if swimAttachment then swimAttachment:Destroy() end
		swimAttachment = Instance.new("Attachment")
		swimAttachment.Name = "PhishSwimAttachment"
		swimAttachment.Parent = currentRoot
	end

	if not buoyancy or buoyancy.Parent ~= currentRoot then
		if buoyancy then buoyancy:Destroy() end
		buoyancy = Instance.new("VectorForce")
		buoyancy.Name = "PhishSwimBuoyancy"
		buoyancy.Attachment0 = swimAttachment
		buoyancy.RelativeTo = Enum.ActuatorRelativeTo.World
		buoyancy.ApplyAtCenterOfMass = true
		buoyancy.Enabled = false
		buoyancy.Parent = currentRoot
	end
end

local function setSwimming(active: boolean)
	if buoyancy then buoyancy.Enabled = active end
	local currentHumanoid = humanoid
	if active and currentHumanoid and not wasSwimming then
		currentHumanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	end
	wasSwimming = active
end

local function bindCharacter(nextCharacter: Model)
	humanoid = nextCharacter:WaitForChild("Humanoid", 5) :: Humanoid?
	root = nextCharacter:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	swimAttachment = nil
	buoyancy = nil
	wasSwimming = false
	ensureForce()
end

local function waterBelow(): RaycastResult?
	local currentRoot = root
	local waterFolder = getWaterFolder()
	if not currentRoot or not waterFolder then return nil end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { waterFolder }
	params.IgnoreWater = true

	local origin = currentRoot.Position + Vector3.new(0, RAYCAST_UP, 0)
	local direction = Vector3.new(0, -(RAYCAST_UP + RAYCAST_DOWN), 0)
	local result = Workspace:Raycast(origin, direction, params)
	if result and result.Instance and CollectionService:HasTag(result.Instance, PhishConstants.Tags.WaterZone) then
		return result
	end
	return nil
end

local function updateSwim()
	local currentRoot = root
	local currentHumanoid = humanoid
	if not currentRoot or not currentHumanoid or currentHumanoid.Health <= 0 then
		setSwimming(false)
		return
	end

	ensureForce()
	local hit = waterBelow()
	if not hit then
		setSwimming(false)
		return
	end

	local waterY = hit.Position.Y
	local rootY = currentRoot.Position.Y
	local lowEnoughForWater = rootY <= waterY + ACTIVATE_ABOVE_SURFACE
	local fallingIntoWater = currentHumanoid.FloorMaterial == Enum.Material.Air and rootY <= waterY + 9
	if not lowEnoughForWater and not fallingIntoWater then
		setSwimming(false)
		return
	end

	local bob = math.sin(os.clock() * BOB_SPEED) * BOB_HEIGHT
	local targetY = waterY + WATER_SURFACE_OFFSET + bob
	local displacement = targetY - rootY
	local verticalVelocity = currentRoot.AssemblyLinearVelocity.Y
	local mass = currentRoot.AssemblyMass
	local extra = math.clamp((displacement * SPRING - verticalVelocity * DAMPING) * mass, -MAX_EXTRA_FORCE, MAX_EXTRA_FORCE)
	local upward = mass * Workspace.Gravity + extra

	if buoyancy then
		buoyancy.Force = Vector3.new(0, upward, 0)
	end
	setSwimming(true)
end

if player.Character then
	task.spawn(bindCharacter, player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

RunService.Heartbeat:Connect(updateSwim)
