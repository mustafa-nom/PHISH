--!strict
-- Boat input forwarder. When the player presses E near a part tagged
-- PhishRowboatSeat, requests to enter that boat. WASD/arrow keys then
-- forward throttle/steer to the server. Shift to exit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local UIStyle = require(Modules:WaitForChild("UIStyle"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local screen = UIBuilder.GetScreenGui()

local state = {
	driving = false,
	boatId = nil :: string?,
	throttle = 0,
	steer = 0,
	keys = {} :: { [Enum.KeyCode]: boolean },
	hud = nil :: Frame?,
	near = nil :: { boatId: string, seat: BasePart }?,
}

local function findNearestSeat(): { boatId: string, seat: BasePart }?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local closest, closestDist = nil, math.huge
	for _, seat in ipairs(CollectionService:GetTagged(Constants.TAGS.RowboatSeat)) do
		if seat:IsA("BasePart") then
			local dist = (seat.Position - root.Position).Magnitude
			if dist < closestDist and dist < 10 then
				local model = seat:FindFirstAncestorOfClass("Model")
				while model and not CollectionService:HasTag(model, Constants.TAGS.Rowboat) do
					model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") or nil
				end
				if model then
					local boatId = model:GetAttribute(Constants.ATTRS.BoatId)
					if typeof(boatId) ~= "string" or boatId == "" then
						boatId = model:GetFullName()
					end
					closest = { boatId = boatId :: string, seat = seat }
					closestDist = dist
				end
			end
		end
	end
	return closest
end

local function showHud(text: string)
	if state.hud then state.hud:Destroy() end
	state.hud = UIStyle.MakePanel({
		Name = "BoatHud",
		Size = UDim2.new(0, 360, 0, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Parent = screen,
	})
	UIStyle.MakeLabel({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.new(0, 8, 0, 4),
		Text = text,
		TextSize = UIStyle.TextSize.Body,
		Parent = state.hud,
	})
end

local function hideHud()
	if state.hud then state.hud:Destroy() end
	state.hud = nil
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		if not state.driving and state.near then
			state.boatId = state.near.boatId
			RemoteService.FireServer("RequestEnterBoat", { boatId = state.boatId })
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift and state.driving then
		RemoteService.FireServer("RequestExitBoat", {})
	end
	if state.driving then state.keys[input.KeyCode] = true end
end)

UserInputService.InputEnded:Connect(function(input)
	if state.driving then state.keys[input.KeyCode] = nil end
end)

RemoteService.OnClientEvent("BoatStateUpdated", function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.Driving == true then
		state.driving = true
		state.boatId = payload.BoatId
		showHud("Driving — WASD to move, Shift to exit")
	elseif payload.Driving == false then
		state.driving = false
		state.boatId = nil
		state.throttle = 0
		state.steer = 0
		state.keys = {}
		hideHud()
	end
end)

local lastSent = 0
RunService.Heartbeat:Connect(function()
	state.near = findNearestSeat()
	if not state.driving then
		if state.near and not state.hud then
			showHud("Press E to drive")
		elseif not state.near and state.hud then
			hideHud()
		end
		return
	end
	local throttle = 0
	if state.keys[Enum.KeyCode.W] or state.keys[Enum.KeyCode.Up] then throttle += 1 end
	if state.keys[Enum.KeyCode.S] or state.keys[Enum.KeyCode.Down] then throttle -= 1 end
	local steer = 0
	if state.keys[Enum.KeyCode.D] or state.keys[Enum.KeyCode.Right] then steer += 1 end
	if state.keys[Enum.KeyCode.A] or state.keys[Enum.KeyCode.Left] then steer -= 1 end
	if throttle ~= state.throttle or steer ~= state.steer or (os.clock() - lastSent) > 0.2 then
		state.throttle = throttle
		state.steer = steer
		lastSent = os.clock()
		RemoteService.FireServer("RequestBoatInput", { throttle = throttle, steer = steer })
	end
end)
