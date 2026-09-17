--!strict
--[[
	SettingsController
	Owns the settings panel: skip-cutscene and gap-label toggles, music and sfx volume steppers.
	Changes apply locally at once (ClientState.SettingsChanged) and are sent to the server debounced.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local SettingsController = {}

local rows: { [string]: any } = {}
local sendScheduled = false

local function settings(): Types.PlayerSettings?
	return if ClientState.data then ClientState.data.settings else nil
end

local function push()
	local s = settings()
	if not s then
		return
	end
	ClientState.SettingsChanged:Fire(s)
	if sendScheduled then
		return
	end
	sendScheduled = true
	task.delay(0.5, function()
		sendScheduled = false
		local latest = settings()
		if latest then
			Remotes.event(Remotes.Names.SettingsChanged):FireServer(table.clone(latest))
		end
	end)
end

local function refresh()
	local s = settings()
	if not s then
		return
	end
	rows.skipCutscenes.Text = if s.skipCutscenes then "ON" else "OFF"
	rows.showGap.Text = if s.showGap then "ON" else "OFF"
	rows.musicVolume.Text = `{math.floor(s.musicVolume * 100 + 0.5)}%`
	rows.sfxVolume.Text = `{math.floor(s.sfxVolume * 100 + 0.5)}%`
end

local function toggleRow(parent: Frame, order: number, key: "skipCutscenes" | "showGap", title: string, blurb: string)
	local row = UI.make("Frame", {
		Name = key,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Color3.fromRGB(34, 39, 50),
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	}) :: Frame
	UI.corner(10).Parent = row
	UI.text({
		Size = UDim2.new(1, -160, 0, 28),
		Position = UDim2.fromOffset(12, 4),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = row,
	})
	UI.text({
		Size = UDim2.new(1, -160, 0, 22),
		Position = UDim2.fromOffset(12, 32),
		Text = blurb,
		Font = UI.BodyFont,
		TextColor3 = Color3.fromRGB(190, 195, 205),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = row,
	})
	local button = UI.button({
		Size = UDim2.fromOffset(120, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Text = "OFF",
		ZIndex = 23,
		Parent = row,
	})
	rows[key] = button
	button.Activated:Connect(function()
		local s = settings()
		if not s then
			return
		end
		Sfx.play("click", 0.6)
		s[key] = not s[key]
		refresh()
		push()
	end)
end

local function volumeRow(parent: Frame, order: number, key: "musicVolume" | "sfxVolume", title: string)
	local row = UI.make("Frame", {
		Name = key,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Color3.fromRGB(34, 39, 50),
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	}) :: Frame
	UI.corner(10).Parent = row
	UI.text({
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = row,
	})
	local minus = UI.button({
		Size = UDim2.fromOffset(44, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -140, 0.5, 0),
		Text = "-",
		ZIndex = 23,
		Parent = row,
	})
	local value = UI.text({
		Size = UDim2.fromOffset(76, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Text = "",
		ZIndex = 23,
		Parent = row,
	})
	local plus = UI.button({
		Size = UDim2.fromOffset(44, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Text = "+",
		ZIndex = 23,
		Parent = row,
	})
	rows[key] = value
	local function bump(delta: number)
		local s = settings()
		if not s then
			return
		end
		Sfx.play("click", 0.6)
		s[key] = math.clamp(math.floor((s[key] + delta) * 10 + 0.5) / 10, 0, 1)
		refresh()
		push()
	end
	minus.Activated:Connect(function()
		bump(-0.1)
	end)
	plus.Activated:Connect(function()
		bump(0.1)
	end)
end

function SettingsController.Init()
	local _, content = UI.panel("Settings", "Settings")
	UI.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	toggleRow(
		content,
		1,
		"skipCutscenes",
		"Skip repeat hatch cutscenes",
		"The first hatch of every biome always plays."
	)
	toggleRow(content, 2, "showGap", "Show distance to the animal", "The studs label under the chase bar.")
	volumeRow(content, 3, "musicVolume", "Music volume")
	volumeRow(content, 4, "sfxVolume", "Sound effects volume")
end

function SettingsController.Start()
	ClientState.ToggleSettings.Event:Connect(function()
		if UI.togglePanel("Settings") then
			refresh()
		end
	end)
	ClientState.DataLoaded:Connect(refresh)
end

return SettingsController
