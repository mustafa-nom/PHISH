-- HACK_BoatDriver.server.lua  (lives inside Workspace.PhishMap.PhishBoat as a Script.)
-- HACKATHON FALLBACK: simple WASD boat steering until User 2 swaps in real hovercraft physics.
-- Reads the DriverSeat's ThrottleFloat/SteerFloat and CFrame-translates the anchored Hull
-- each frame. WeldConstraints carry every other part along.
-- DELETE THIS SCRIPT once User 2's boat physics service lands.
-- Source mirrored at studio_scripts/hack_boat_driver.server.luau so it can be reinstalled.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService"))

local boat = script.Parent
local hull = boat:WaitForChild("Hull")
local driver = boat:WaitForChild("DriverSeat")

local SPEED = 24    -- studs/sec at full throttle
local TURN = 1.4    -- rad/sec at full steer
local ROD_TOOL_NAME = "PhishRod"

local jumpConnections = {}
local seatByHumanoid = {}

local function playerFromHumanoid(humanoid)
	local character = humanoid and humanoid.Parent
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function containerHasRod(container)
	if not container then return false end
	local tool = container:FindFirstChild(ROD_TOOL_NAME)
	return tool ~= nil and (tool:GetAttribute("PhishRod") == true or tool:IsA("Tool"))
end

local function playerHasRod(player)
	if containerHasRod(player.Character) then return true end
	if containerHasRod(player:FindFirstChildOfClass("Backpack")) then return true end
	return DataService.Get(player).rodGiven == true
end

local function notify(player, message)
	RemoteService.FireClient(player, "Notify", {
		kind = "Error",
		message = message,
		duration = 3,
	})
end

local function dismount(humanoid, seat)
	if not humanoid or humanoid.Health <= 0 then return end
	local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	humanoid.Sit = false
	if root and root:IsA("BasePart") then
		local side = hull.CFrame.RightVector
		local back = -hull.CFrame.LookVector
		root.CFrame = CFrame.new(seat.Position + side * 5 + back * 2 + Vector3.new(0, 3, 0))
	end
end

local function bindSeat(seat)
	if not seat:IsA("Seat") and not seat:IsA("VehicleSeat") then return end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if not humanoid then return end
		local player = playerFromHumanoid(humanoid)
		if not player then return end

		if not playerHasRod(player) then
			dismount(humanoid, seat)
			notify(player, "Grab a fishing rod before boarding the boat.")
			return
		end

		if jumpConnections[humanoid] and seatByHumanoid[humanoid] == seat then return end
		if jumpConnections[humanoid] then jumpConnections[humanoid]:Disconnect() end
		seatByHumanoid[humanoid] = seat
		jumpConnections[humanoid] = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
			if humanoid.Jump and humanoid.SeatPart == seat then
				dismount(humanoid, seat)
			end
		end)
	end)
end

for _, descendant in ipairs(boat:GetDescendants()) do
	bindSeat(descendant)
end

boat.DescendantAdded:Connect(bindSeat)

RunService.Heartbeat:Connect(function(dt)
	local throttle = driver.ThrottleFloat or 0
	local steer = driver.SteerFloat or 0
	if throttle == 0 and steer == 0 then return end
	-- Bow is +X relative to Hull center, so the boat's "forward" is RightVector.
	local fwd = hull.CFrame.RightVector * (throttle * SPEED * dt)
	local rot = CFrame.fromEulerAnglesYXZ(0, -steer * TURN * dt, 0)
	hull.CFrame = (hull.CFrame + fwd) * rot
end)
