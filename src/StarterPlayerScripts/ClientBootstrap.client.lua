--!strict
-- Client init for PHISH!. Other controllers are LocalScripts that auto-start;
-- this bootstrap exists to:
--   * make sure the remote folder is replicated before any controller fires
--   * create the shared ScreenGui parent
--   * pull the player's data snapshot on join

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedStorage:WaitForChild(Constants.REMOTE_FOLDER_NAME)

local screen = playerGui:FindFirstChild(Constants.SCREEN_GUI_NAME)
if not screen then
	screen = Instance.new("ScreenGui")
	screen.Name = Constants.SCREEN_GUI_NAME
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
end

-- Pull initial snapshot. InventoryUpdated is event-driven afterwards.
task.spawn(function()
	local ok, snap = pcall(function()
		return RemoteService.InvokeServer("GetSnapshot")
	end)
	if ok and snap then
		local _ = snap
	end
end)

print("[PHISH!] Client bootstrap ready.")
