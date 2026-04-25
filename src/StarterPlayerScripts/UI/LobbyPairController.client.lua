--!strict
-- Handles capsule confirm + invite UIs and exposes the proximity-prompt
-- "Invite to Play" on other players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = require(ReplicatedStorage:WaitForChild("RemoteService"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local UIFolder = script.Parent
local UIBuilder = require(UIFolder:WaitForChild("UIBuilder"))
local UIStyle = UIBuilder.UIStyle

local localPlayer = Players.LocalPlayer

local activeCapsuleConfirm: { CapsuleId: string, Container: Frame? }? = nil
local activeInvite: { InviteId: string, Container: Frame? }? = nil

local function clearCapsulePrompt()
	if activeCapsuleConfirm and activeCapsuleConfirm.Container then
		activeCapsuleConfirm.Container:Destroy()
	end
	activeCapsuleConfirm = nil
end

local function clearInvitePrompt()
	if activeInvite and activeInvite.Container then
		activeInvite.Container:Destroy()
	end
	activeInvite = nil
end

local function showCapsuleConfirm(payload)
	clearCapsulePrompt()
	local screen = UIBuilder.GetScreenGui()
	local frame = UIStyle.MakePanel({
		Name = "CapsuleConfirm",
		Size = UDim2.new(0, 360, 0, 180),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Parent = screen,
	})
	UIBuilder.PadLayout(frame, 16)

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 32),
		Text = "Buddy ready!",
		TextSize = UIStyle.TextSize.Heading,
	})
	title.Parent = frame

	local subtitle = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 36),
		Text = ("%s wants to play with you."):format(payload.Partner or "Someone"),
		TextSize = UIStyle.TextSize.Body,
	})
	subtitle.Parent = frame

	local confirm = UIStyle.MakeButton({
		Size = UDim2.new(0.5, -8, 0, 60),
		Position = UDim2.new(0, 0, 1, -68),
		Text = "Confirm Pair",
	})
	confirm.Parent = frame

	local cancel = UIStyle.MakeButton({
		Size = UDim2.new(0.5, -8, 0, 60),
		Position = UDim2.new(0.5, 8, 1, -68),
		Text = "Step off",
		BackgroundColor3 = UIStyle.Palette.PanelStroke,
	})
	cancel.Parent = frame

	confirm.Activated:Connect(function()
		RemoteService.FireServer("RequestPairFromCapsule", payload.CapsuleId)
	end)
	cancel.Activated:Connect(function()
		clearCapsulePrompt()
	end)

	activeCapsuleConfirm = { CapsuleId = payload.CapsuleId, Container = frame }
end

local function showInvite(payload)
	clearInvitePrompt()
	local screen = UIBuilder.GetScreenGui()
	local frame = UIStyle.MakePanel({
		Name = "InviteReceived",
		Size = UDim2.new(0, 360, 0, 180),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Parent = screen,
	})
	UIBuilder.PadLayout(frame, 16)

	local title = UIStyle.MakeLabel({
		Size = UDim2.new(1, 0, 0, 32),
		Text = ("%s invited you!"):format(payload.FromName or "Someone"),
		TextSize = UIStyle.TextSize.Heading,
	})
	title.Parent = frame

	local accept = UIStyle.MakeButton({
		Size = UDim2.new(0.5, -8, 0, 60),
		Position = UDim2.new(0, 0, 1, -68),
		Text = "Accept",
		BackgroundColor3 = UIStyle.Palette.Safe,
	})
	accept.Parent = frame

	local decline = UIStyle.MakeButton({
		Size = UDim2.new(0.5, -8, 0, 60),
		Position = UDim2.new(0.5, 8, 1, -68),
		Text = "No thanks",
		BackgroundColor3 = UIStyle.Palette.PanelStroke,
	})
	decline.Parent = frame

	accept.Activated:Connect(function()
		RemoteService.FireServer("RespondToInvite", payload.InviteId, true)
		clearInvitePrompt()
	end)
	decline.Activated:Connect(function()
		RemoteService.FireServer("RespondToInvite", payload.InviteId, false)
		clearInvitePrompt()
	end)

	activeInvite = { InviteId = payload.InviteId, Container = frame }
	task.delay(payload.ExpiresIn or 15, function()
		if activeInvite and activeInvite.InviteId == payload.InviteId then
			clearInvitePrompt()
		end
	end)
end

-- Build "Invite to Play" prompt on every other player's character.
local function setupInvitePromptForCharacter(player: Player, character: Model)
	if player == localPlayer then return end
	task.wait(0.2)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	if root:FindFirstChild("BB_InvitePrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BB_InvitePrompt"
	prompt.ActionText = "Invite to Play"
	prompt.ObjectText = player.Name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = Constants.PROXIMITY_INVITE_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(triggerer)
		if triggerer ~= localPlayer then return end
		RemoteService.FireServer("RequestInvitePlayer", player.UserId)
		UIBuilder.Toast("Invite sent to " .. player.Name, 2, "Success")
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		setupInvitePromptForCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		setupInvitePromptForCharacter(player, character)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

RemoteService.OnClientEvent("CapsulePairReady", function(payload)
	if typeof(payload) ~= "table" then return end
	showCapsuleConfirm(payload)
end)

RemoteService.OnClientEvent("CapsulePairCleared", function(_payload)
	clearCapsulePrompt()
end)

RemoteService.OnClientEvent("InviteReceived", function(payload)
	if typeof(payload) ~= "table" then return end
	showInvite(payload)
end)

RemoteService.OnClientEvent("PairAssigned", function(payload)
	clearCapsulePrompt()
	clearInvitePrompt()
	UIBuilder.Toast("You're paired up! Pick your role.", 3, "Success")
end)

RemoteService.OnClientEvent("PairCleared", function(_payload)
	clearCapsulePrompt()
	clearInvitePrompt()
	UIBuilder.Toast("Pair ended.", 2)
end)
