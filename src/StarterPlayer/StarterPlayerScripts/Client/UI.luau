--!strict
--[[
	UI
	Small helpers for building the HUD in code: a property-applying constructor, the shared
	ScreenGui, and a few common pieces (rounded corners, strokes, text). Every controller builds its
	own frames with these so sizing and fonts stay consistent and phone-friendly.
]]

local Players = game:GetService("Players")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.BodyFont = Enum.Font.GothamMedium
UI.ScreenGuiName = "AnimalObbyHUD"

function UI.make(className: string, props: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

function UI.stroke(color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

function UI.text(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Color3.fromRGB(20, 20, 30),
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	return UI.make("TextLabel", defaults) :: TextLabel
end

--- The one ScreenGui every controller draws into (created on first use).
function UI.screen(): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(UI.ScreenGuiName)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = UI.ScreenGuiName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

-- Panels (Egg Dex, Settings, Shop) are exclusive: opening one closes the others.
local panels: { [string]: GuiObject } = {}

function UI.registerPanel(name: string, frame: GuiObject)
	panels[name] = frame
	frame.Visible = false
end

function UI.togglePanel(name: string): boolean
	local target = panels[name]
	if not target then
		return false
	end
	local show = not target.Visible
	for key, frame in pairs(panels) do
		frame.Visible = show and key == name
	end
	return show
end

--- A rounded button with a label; the caller connects Activated.
function UI.button(props: { [string]: any }): TextButton
	local defaults: { [string]: any } = {
		BackgroundColor3 = Color3.fromRGB(45, 52, 66),
		AutoButtonColor = true,
		Font = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local button = UI.make("TextButton", defaults) :: TextButton
	UI.corner(10).Parent = button
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 24
	constraint.Parent = button
	return button
end

--- A panel frame centred on screen with a title bar and close button; returns (panel, content).
function UI.panel(name: string, title: string): (Frame, Frame)
	local panel = UI.make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundColor3 = Color3.fromRGB(24, 28, 36),
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = UI.screen(),
	}) :: Frame
	UI.corner(14).Parent = panel
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(760, 560)
	sizeConstraint.MinSize = Vector2.new(300, 260)
	sizeConstraint.Parent = panel
	UI.text({
		Name = "Title",
		Size = UDim2.new(1, -60, 0, 44),
		Position = UDim2.fromOffset(16, 6),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = panel,
	})
	local close = UI.button({
		Name = "Close",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -48, 0, 8),
		Text = "X",
		BackgroundColor3 = Color3.fromRGB(180, 50, 50),
		ZIndex = 21,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local content = UI.make("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -24, 1, -68),
		Position = UDim2.fromOffset(12, 58),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = panel,
	}) :: Frame
	UI.registerPanel(name, panel)
	return panel, content
end

function UI.isPhone(): boolean
	local camera = workspace.CurrentCamera
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and camera ~= nil and camera.ViewportSize.X < 900
end

return UI
