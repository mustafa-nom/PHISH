--!strict
-- Renders toast notifications in response to the server's `Notify` remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local UIFolder = script.Parent
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))

local _ = Players.LocalPlayer
UIBuilder.GetScreenGui()  -- ensure ScreenGui exists

RemoteService.OnClientEvent("Notify", function(payload)
	if typeof(payload) ~= "table" then return end
	local text = payload.Text or payload.text
	if typeof(text) ~= "string" then
		-- Some Notify events carry structured data (e.g., role selections);
		-- those are consumed by other controllers. Don't toast structured.
		return
	end
	UIBuilder.Toast(text, payload.Duration or 3, payload.Kind)
end)
