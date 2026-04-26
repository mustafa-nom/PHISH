--!strict
-- Shared UI scaffolding used by every controller. Wraps UIStyle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIStyle = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIStyle"))

local UIBuilder = {}

UIBuilder.UIStyle = UIStyle

function UIBuilder.GetScreenGui(): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screen = playerGui:WaitForChild("PhishUI", 5)
	if screen and screen:IsA("ScreenGui") then
		return screen :: ScreenGui
	end
	local newScreen = Instance.new("ScreenGui")
	newScreen.Name = "PhishUI"
	newScreen.ResetOnSpawn = false
	newScreen.IgnoreGuiInset = false
	newScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	newScreen.Parent = playerGui
	return newScreen
end

function UIBuilder.NamedFrame(name: string, parent: Instance?): Frame
	local existing = parent and parent:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local frame = UIStyle.MakePanel({ Name = name, AnchorPoint = Vector2.new(0.5, 0.5) })
	if parent then
		frame.Parent = parent
	end
	return frame
end

function UIBuilder.Toast(message: string, durationSeconds: number?, kind: string?)
	local screen = UIBuilder.GetScreenGui()
	local container = screen:FindFirstChild("ToastContainer")
	if not container then
		container = Instance.new("Frame")
		container.Name = "ToastContainer"
		container.Size = UDim2.fromScale(1, 0.12)
		container.Position = UDim2.fromScale(0, 0.1)
		container.BackgroundTransparency = 1
		container.ZIndex = 50
		container.Parent = screen
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 4)
		layout.Parent = container
	end
	local toast = UIStyle.MakePanel({
		Size = UDim2.fromScale(0.28, 0.44),
		BackgroundColor3 = (kind == "Error" and UIStyle.Palette.Risky)
			or (kind == "Success" and UIStyle.Palette.Safe)
			or UIStyle.Palette.Panel,
	})
	local label = UIStyle.MakeLabel({
		Size = UDim2.fromScale(0.94, 1),
		Position = UDim2.fromScale(0.03, 0),
		Text = message,
		TextSize = UIStyle.TextSize.Body,
	})
	label.Parent = toast
	toast.Parent = container

	task.delay(durationSeconds or 3, function()
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
end

function UIBuilder.PadLayout(parent: Instance, padding: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, padding or 12)
	p.PaddingBottom = UDim.new(0, padding or 12)
	p.PaddingLeft = UDim.new(0, padding or 12)
	p.PaddingRight = UDim.new(0, padding or 12)
	p.Parent = parent
	return p
end

return UIBuilder
