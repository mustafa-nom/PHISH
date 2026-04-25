--!strict
-- Makes NPCs in Stranger Danger Park speak short personality lines via chat
-- bubbles when the Explorer gets close. Each NPC has a `BB_Bark` attribute
-- (set by StrangerDangerLevel from the archetype). Bubbles cool down per NPC
-- so a hovering player doesn't spam-trigger them.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Chat = game:GetService("Chat")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayAreaConfig = require(Modules:WaitForChild("PlayAreaConfig"))

local localPlayer = Players.LocalPlayer

local BARK_RADIUS = 18
local BARK_COOLDOWN = 9
local lastBark: { [string]: number } = {}

local function getHumanoidRoot(): BasePart?
	local char = localPlayer.Character
	return char and (char:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function findHead(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head :: BasePart end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp :: BasePart end
	return nil
end

local function tick(_dt: number)
	local hrp = getHumanoidRoot()
	if not hrp then return end
	local now = os.clock()
	for _, slot in ipairs(CollectionService:GetTagged(PlayAreaConfig.Tags.PlayArenaSlot)) do
		local playArea = slot:FindFirstChild("PlayArea")
		if not playArea then continue end
		for _, level in ipairs(playArea:GetChildren()) do
			if not level:IsA("Model") then continue end
			for _, npc in ipairs(level:GetChildren()) do
				if not npc:IsA("Model") then continue end
				local bark = npc:GetAttribute("BB_Bark")
				if typeof(bark) ~= "string" or bark == "" or bark == "..." then continue end
				local head = findHead(npc)
				if not head then continue end
				local dist = (head.Position - hrp.Position).Magnitude
				if dist <= BARK_RADIUS then
					local last = lastBark[npc.Name] or 0
					if now - last >= BARK_COOLDOWN then
						lastBark[npc.Name] = now
						Chat:Chat(head, bark, Enum.ChatColor.White)
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	-- only run every 0.4s to keep it cheap
	if math.random() < dt / 0.4 then tick(dt) end
end)
