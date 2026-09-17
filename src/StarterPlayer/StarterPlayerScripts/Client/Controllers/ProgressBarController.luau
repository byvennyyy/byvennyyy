--!strict
--[[
	ProgressBarController
	Owns the biome-wide chase bar at the top of the screen: ten tier-coloured stage segments with
	checkpoint ticks, a finish flag, the player's headshot marker and the animal's viewport-render
	marker moving along the bar, a gap readout, proximity pulsing with a heartbeat layer, and the
	head-start countdown while the animal is frozen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetResolver = require(Shared.AssetResolver)
local GameConfig = require(Shared.Config.GameConfig)
local Types = require(Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local ModelPrep = require(script.Parent.Parent.ModelPrep)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local DANGER_GAP = 40
local PLAYER_MARKER = 44
local ANIMAL_MARKER = 52

local ProgressBarController = {}

local player = Players.LocalPlayer

type Bar = {
	root: Frame,
	track: Frame,
	segments: Frame,
	ticks: Frame,
	playerMarker: ImageLabel,
	animalMarker: Frame,
	animalStroke: UIStroke,
	viewport: ViewportFrame,
	gapLabel: TextLabel,
	countdown: TextLabel,
}
local bar: Bar? = nil
local displayedPlayer = 0
local displayedAnimal = 0
local heartbeat: Sound? = nil
local pulseTween: Tween? = nil
local frozenUntil = 0
local viewportModel: Model? = nil
local viewportCamera: Camera? = nil

local function build(): Bar
	local screen = UI.screen()
	local width = if UI.isPhone() then 0.9 else 0.62
	local root = UI.make("Frame", {
		Name = "ProgressBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.new(width, 0, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = screen,
	}) :: Frame
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 30)
	constraint.MaxSize = Vector2.new(1100, 30)
	constraint.Parent = root
	local track = UI.make("Frame", {
		Name = "Track",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 20, 26),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = root,
	}) :: Frame
	UI.corner(15).Parent = track
	UI.stroke(Color3.fromRGB(70, 76, 90), 2).Parent = track
	local segments = UI.make("Frame", {
		Name = "Segments",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = track,
	}) :: Frame
	UI.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = segments,
	})
	local ticks = UI.make(
		"Frame",
		{ Name = "Ticks", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Parent = track }
	) :: Frame
	UI.text({
		Name = "Flag",
		Size = UDim2.fromOffset(28, 28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Text = "🏁",
		ZIndex = 9,
		Parent = track,
	})
	local animalMarker = UI.make("Frame", {
		Name = "AnimalMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(ANIMAL_MARKER, ANIMAL_MARKER),
		BackgroundColor3 = Color3.fromRGB(30, 34, 44),
		ZIndex = 10,
		Parent = track,
	}) :: Frame
	UI.corner(12).Parent = animalMarker
	local animalStroke = UI.stroke(Color3.fromRGB(255, 255, 255), 2)
	animalStroke.Parent = animalMarker
	local viewport = UI.make("ViewportFrame", {
		Name = "Render",
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		ZIndex = 11,
		Parent = animalMarker,
	}) :: ViewportFrame
	local countdown = UI.text({
		Name = "Countdown",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, 2),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 230, 120),
		ZIndex = 12,
		Parent = animalMarker,
	})
	local playerMarker = UI.make("ImageLabel", {
		Name = "PlayerMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(PLAYER_MARKER, PLAYER_MARKER),
		BackgroundColor3 = Color3.fromRGB(60, 200, 120),
		Image = "",
		ZIndex = 12,
		Parent = track,
	}) :: ImageLabel
	UI.corner(22).Parent = playerMarker
	UI.stroke(Color3.fromRGB(255, 255, 255), 2).Parent = playerMarker
	local gapLabel = UI.text({
		Name = "Gap",
		Size = UDim2.fromOffset(90, 18),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Text = "",
		Font = UI.BodyFont,
		ZIndex = 9,
		Parent = root,
	})
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if ok and type(image) == "string" then
			playerMarker.Image = image
		end
	end)
	return {
		root = root,
		track = track,
		segments = segments,
		ticks = ticks,
		playerMarker = playerMarker,
		animalMarker = animalMarker,
		animalStroke = animalStroke,
		viewport = viewport,
		gapLabel = gapLabel,
		countdown = countdown,
	}
end

local function rebuild(info: Types.ClientBiomeInfo, def: Types.BiomeDef)
	local b = bar
	if not b then
		return
	end
	for _, child in b.segments:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child in b.ticks:GetChildren() do
		child:Destroy()
	end
	local h, s, v = def.tierColor:ToHSV()
	local light = Color3.fromHSV(h, s, math.max(0.35, v))
	local dark = Color3.fromHSV(h, s, math.max(0.2, v * 0.6))
	for i = 1, GameConfig.StagesPerBiome do
		local segment = UI.make("Frame", {
			Name = `Seg{i}`,
			Size = UDim2.new(1 / GameConfig.StagesPerBiome, -2, 1, 0),
			BackgroundColor3 = if i % 2 == 0 then dark else light,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = b.segments,
		}) :: Frame
		UI.corner(6).Parent = segment
	end
	for i, s2 in info.checkpointS do
		if i > 1 then
			UI.make("Frame", {
				Name = `Tick{i}`,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(s2 / info.length, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Color3.fromRGB(240, 240, 240),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = b.ticks,
			})
		end
	end
	-- viewport render of the animal
	if viewportModel then
		viewportModel:Destroy()
		viewportModel = nil
	end
	if def.renderImage then
		b.viewport.Visible = false
		local image = b.animalMarker:FindFirstChild("RenderImage") :: ImageLabel?
			or UI.make("ImageLabel", {
				Name = "RenderImage",
				Size = UDim2.new(1, -6, 1, -6),
				Position = UDim2.fromOffset(3, 3),
				BackgroundTransparency = 1,
				ZIndex = 11,
				Parent = b.animalMarker,
			}) :: ImageLabel
		image.Image = def.renderImage
		image.Visible = true
	else
		local existingImage = b.animalMarker:FindFirstChild("RenderImage")
		if existingImage and existingImage:IsA("ImageLabel") then
			existingImage.Visible = false
		end
		b.viewport.Visible = true
		local source = AssetResolver.animal(def.animal, def.animalFolder)
			or AssetResolver.placeholderAnimal(def.animal, def.palette)
		local prepared = ModelPrep.prepare(source)
		prepared.model:PivotTo(CFrame.new(0, 0, 0))
		prepared.model.Parent = b.viewport
		viewportModel = prepared.model
		local camera = viewportCamera or Instance.new("Camera")
		viewportCamera = camera
		camera.Parent = b.viewport
		b.viewport.CurrentCamera = camera
		local extents = prepared.model:GetExtentsSize()
		local distance = extents.Magnitude * 1.1
		camera.CFrame =
			CFrame.lookAt(Vector3.new(distance * 0.7, extents.Y * 0.35, distance * 0.7), Vector3.new(0, 0, 0))
	end
	displayedPlayer = info.checkpointS[1] / info.length
	displayedAnimal = displayedPlayer
	b.root.Visible = true
end

local function setDanger(on: boolean)
	local b = bar
	if not b then
		return
	end
	if on and not pulseTween then
		b.animalStroke.Color = Color3.fromRGB(255, 60, 60)
		local tween = TweenService:Create(
			b.animalStroke,
			TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 5 }
		)
		tween:Play()
		pulseTween = tween
		if not heartbeat then
			heartbeat = Sfx.loop("heartbeat", 0)
		end
	elseif not on and pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
		b.animalStroke.Thickness = 2
		b.animalStroke.Color = Color3.fromRGB(255, 255, 255)
	end
end

local function update(dt: number)
	local b = bar
	local info = ClientState.biome
	if not b or not info or info.length <= 0 then
		return
	end
	local targetPlayer = math.clamp(ClientState.playerS / info.length, 0, 1)
	local targetAnimal = math.clamp(ClientState.chaserS / info.length, 0, 1)
	local rate = math.min(1, dt * 10)
	displayedPlayer += (targetPlayer - displayedPlayer) * rate
	displayedAnimal += (targetAnimal - displayedAnimal) * rate
	b.playerMarker.Position = UDim2.fromScale(displayedPlayer, 0.5)
	b.animalMarker.Position = UDim2.fromScale(displayedAnimal, 0.5)
	local mode = ClientState.chaserMode
	b.animalMarker.Visible = mode ~= "inactive"
	local gap = ClientState.Gap()
	local settings = ClientState.data and ClientState.data.settings
	local showGap = settings == nil or settings.showGap
	if mode == "chasing" and showGap then
		b.gapLabel.Text = `{math.max(0, math.floor(gap))} studs`
		b.gapLabel.TextColor3 = if gap < DANGER_GAP then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(230, 230, 230)
	else
		b.gapLabel.Text = ""
	end
	local danger = mode == "chasing" and gap < DANGER_GAP
	setDanger(danger)
	if heartbeat then
		heartbeat.Volume = if danger then math.clamp((DANGER_GAP - gap) / DANGER_GAP, 0, 1) * 0.8 else 0
	end
	if mode == "frozen" then
		local remaining = frozenUntil - os.clock()
		b.countdown.Text = if remaining > 0 then string.format("%.0f", math.ceil(remaining)) else "..."
	elseif mode == "defeated" then
		b.countdown.Text = "TAMED"
	else
		b.countdown.Text = ""
	end
	if viewportModel then
		viewportModel:PivotTo(CFrame.Angles(0, os.clock() * 0.8, 0))
	end
end

function ProgressBarController.Init()
	bar = build()
	if bar then
		bar.root.Visible = false
	end
end

function ProgressBarController.Start()
	ClientState.BiomeChanged:Connect(rebuild)
	if ClientState.biome and ClientState.biomeDef then
		rebuild(ClientState.biome, ClientState.biomeDef)
	end
	ClientState.BiomeEntered:Connect(function()
		local def = ClientState.biomeDef
		frozenUntil = os.clock() + GameConfig.Cutscene.totalSeconds + (if def then def.chase.headStart else 8)
	end)
	ClientState.ChaserEvent:Connect(function(kind)
		local def = ClientState.biomeDef
		if kind == "Reset" and def then
			frozenUntil = os.clock() + Players.RespawnTime + def.chase.respawnHeadStart
		elseif kind == "Hatched" then
			frozenUntil = 0
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return ProgressBarController
