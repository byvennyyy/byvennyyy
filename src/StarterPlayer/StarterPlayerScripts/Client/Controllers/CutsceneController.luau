--!strict
--[[
	CutsceneController
	Owns the egg-hatch cutscene played at every biome start: freeze the player, frame the egg on its
	pedestal, wobble, crack, burst, reveal the animal with a tier card, return the camera and shout RUN.
	Timings come from GameConfig.Cutscene. The first hatch of each biome always plays in full; repeats
	can be skipped with any input, and the skipCutscenes setting reduces them to the tier card.
	Every exit path (skip, death, error) restores the camera and control, then sends CutsceneDone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetResolver = require(Shared.AssetResolver)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local ModelPrep = require(script.Parent.Parent.ModelPrep)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local CutsceneController = {}

local player = Players.LocalPlayer
local Beats = GameConfig.Cutscene
local running = false
local skipRequested = false
local skipAllowed = false

type Layer = { root: Frame, card: TextLabel, sub: TextLabel, flash: Frame, run: TextLabel, hint: TextLabel }
local layer: Layer? = nil

local function buildLayer(): Layer
	if layer and layer.root.Parent then
		return layer
	end
	local root = UI.make("Frame", {
		Name = "Cutscene",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 50,
		Parent = UI.screen(),
	}) :: Frame
	UI.make("Frame", {
		Name = "BarTop",
		Size = UDim2.new(1, 0, 0.09, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = root,
	})
	UI.make("Frame", {
		Name = "BarBottom",
		Size = UDim2.new(1, 0, 0.09, 0),
		Position = UDim2.fromScale(0, 0.91),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = root,
	})
	local flash = UI.make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = root,
	}) :: Frame
	local card = UI.text({
		Name = "Card",
		Size = UDim2.new(0.8, 0, 0.12, 0),
		Position = UDim2.fromScale(0.1, 0.62),
		Text = "",
		ZIndex = 53,
		Visible = false,
		Parent = root,
	})
	local sub = UI.text({
		Name = "Sub",
		Size = UDim2.new(0.8, 0, 0.05, 0),
		Position = UDim2.fromScale(0.1, 0.74),
		Text = "",
		Font = UI.BodyFont,
		TextColor3 = Color3.fromRGB(235, 235, 235),
		ZIndex = 53,
		Visible = false,
		Parent = root,
	})
	local run = UI.text({
		Name = "Run",
		Size = UDim2.new(0.6, 0, 0.18, 0),
		Position = UDim2.fromScale(0.2, 0.38),
		Text = "RUN!",
		TextColor3 = Color3.fromRGB(255, 70, 70),
		ZIndex = 53,
		Visible = false,
		Parent = root,
	})
	local hint = UI.text({
		Name = "Hint",
		Size = UDim2.new(0.5, 0, 0.035, 0),
		Position = UDim2.fromScale(0.25, 0.925),
		Text = "tap or press any key to skip",
		Font = UI.BodyFont,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		ZIndex = 53,
		Visible = false,
		Parent = root,
	})
	layer = { root = root, card = card, sub = sub, flash = flash, run = run, hint = hint }
	return layer :: Layer
end

local function freeze(on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		root.Anchored = on
	end
	if humanoid then
		humanoid.WalkSpeed = if on then 0 else 16
		humanoid.JumpPower = if on then 0 else 50
	end
end

local function waitBeat(seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if skipRequested then
			return false
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return false
		end
		RunService.RenderStepped:Wait()
	end
	return true
end

local function tweenCamera(camera: Camera, target: CFrame, seconds: number)
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
	tween:Play()
end

local function pedestalView(pedestal: CFrame): (CFrame, Vector3)
	local focus = pedestal.Position + Vector3.new(0, 2.5, 0)
	local eye = pedestal.Position + pedestal.RightVector * 8 + Vector3.new(0, 4.5, 0) + pedestal.LookVector * 6
	return CFrame.lookAt(eye, focus), focus
end

local function spawnShell(origin: Vector3, palette: Types.Palette)
	for _ = 1, 10 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(math.random(5, 12) / 10, 0.2, math.random(5, 12) / 10)
		shard.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		shard.Color = palette.secondary
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.AssemblyLinearVelocity =
			Vector3.new((math.random() - 0.5) * 24, math.random(10, 22), (math.random() - 0.5) * 24)
		shard.Parent = workspace
		Debris:AddItem(shard, Beats.shellFragmentLifetime)
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(palette.accent)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(12, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Enabled = false
	local holder = Instance.new("Part")
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(origin)
	emitter.Parent = holder
	holder.Parent = workspace
	emitter:Emit(60)
	Debris:AddItem(holder, 3)
end

local function play(biome: number, animal: string, firstTimeEver: boolean)
	local info = ClientState.biome
	local def = ClientState.biomeDef
	local camera = workspace.CurrentCamera
	if not info or not def or def.index ~= biome or not camera then
		Remotes.event(Remotes.Names.CutsceneDone):FireServer()
		return
	end
	local ui = buildLayer()
	local settings = ClientState.data and ClientState.data.settings
	local reduced = settings ~= nil and settings.skipCutscenes and not firstTimeEver
	running = true
	skipRequested = false
	skipAllowed = not firstTimeEver
	ClientState.cutsceneActive = true
	ui.root.Visible = true
	ui.hint.Visible = skipAllowed and not reduced
	ui.card.Text = string.upper(`BIOME {biome} - {def.tier} - {def.name}`)
	ui.card.TextColor3 = def.tierColor
	ui.sub.Text = string.upper(animal)

	local egg: Model? = nil
	local reveal: ModelPrep.Prepared? = nil
	local originalCameraType = camera.CameraType

	local results = {
		pcall(function()
			if reduced then
				ui.card.Visible = true
				ui.sub.Visible = true
				waitBeat(1.2)
				return
			end
			freeze(true)
			camera.CameraType = Enum.CameraType.Scriptable
			local view, focus = pedestalView(info.eggPedestal)
			tweenCamera(camera, view, Beats.cameraInSeconds)

			local eggSource = AssetResolver.egg(def.eggModel) or AssetResolver.placeholderEgg(def.palette)
			local eggPrep = ModelPrep.prepare(eggSource)
			egg = eggPrep.model
			local eggBase = CFrame.new(info.eggPedestal.Position + Vector3.new(0, 0.75 + eggPrep.halfHeight, 0))
				* CFrame.Angles(0, info.eggPedestal:ToEulerAnglesYXZ(), 0)
			eggPrep.model:PivotTo(eggBase)
			eggPrep.model.Parent = workspace
			if not waitBeat(Beats.cameraInSeconds) then
				return
			end

			-- wobble with growing amplitude
			local wobbleStart = os.clock()
			while os.clock() - wobbleStart < Beats.wobbleSeconds do
				if skipRequested then
					return
				end
				local t = (os.clock() - wobbleStart) / Beats.wobbleSeconds
				local amplitude = math.rad(4 + 16 * t)
				local angle = math.sin(t * Beats.wobbleCount * math.pi * 2) * amplitude
				eggPrep.model:PivotTo(eggBase * CFrame.Angles(0, 0, angle))
				if math.floor(t * Beats.wobbleCount) ~= math.floor((t - 1 / 60) * Beats.wobbleCount) then
					Sfx.play("crack", 0.8)
				end
				RunService.RenderStepped:Wait()
			end

			-- burst
			Sfx.play("burst", 1)
			ui.flash.BackgroundTransparency = 0.1
			TweenService:Create(ui.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			spawnShell(eggBase.Position, def.palette)
			local top = eggPrep.model:FindFirstChild("Top")
			if top and top:IsA("BasePart") then
				TweenService:Create(
					top,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = top.CFrame * CFrame.new(0, 6, 2) * CFrame.Angles(0.8, 0, 0.5), Transparency = 1 }
				):Play()
				for _, part in eggPrep.model:GetDescendants() do
					if part:IsA("BasePart") and part ~= top then
						part.Transparency = 1
					end
				end
			else
				eggPrep.model:Destroy()
				egg = nil
			end

			local animalSource = AssetResolver.animal(def.animal, def.animalFolder)
				or AssetResolver.placeholderAnimal(def.animal, def.palette)
			local prep = ModelPrep.prepare(animalSource)
			reveal = prep
			local standing = CFrame.lookAt(
				info.eggPedestal.Position + Vector3.new(0, 0.75 + prep.halfHeight, 0),
				focus + info.eggPedestal.LookVector * -10
			)
			prep.model:PivotTo(standing)
			prep.model.Parent = workspace
			ModelPrep.play(prep, "idle")
			local burstStart = os.clock()
			while os.clock() - burstStart < Beats.burstSeconds do
				local t = (os.clock() - burstStart) / Beats.burstSeconds
				local overshoot = 1 + 0.25 * math.sin(t * math.pi)
				local scale = prep.baseScale * (0.1 + 0.9 * t) * overshoot
				prep.model:ScaleTo(math.max(0.05, scale))
				prep.model:PivotTo(standing)
				camera.CFrame = view
					* CFrame.new(
						(math.random() - 0.5) * Beats.shakeMagnitude,
						(math.random() - 0.5) * Beats.shakeMagnitude,
						0
					)
				RunService.RenderStepped:Wait()
			end
			prep.model:ScaleTo(prep.baseScale)
			prep.model:PivotTo(standing)
			camera.CFrame = view
			Sfx.play("roar", 1)

			-- tier card slam
			ui.card.Visible = true
			ui.sub.Visible = true
			local scaler = Instance.new("UIScale")
			scaler.Scale = 1.8
			scaler.Parent = ui.card
			TweenService
				:Create(scaler, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			Debris:AddItem(scaler, 1)
			waitBeat(Beats.cardSeconds)
		end),
	}
	if not results[1] then
		warn(`[Cutscene] error: {results[2]}`)
	end

	-- release (runs on every exit path)
	ui.card.Visible = false
	ui.sub.Visible = false
	ui.hint.Visible = false
	if egg then
		egg:Destroy()
	end
	if reveal then
		reveal.model:Destroy()
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if camera.CameraType == Enum.CameraType.Scriptable and root and root:IsA("BasePart") and not reduced then
		tweenCamera(
			camera,
			CFrame.lookAt(root.Position - root.CFrame.LookVector * 10 + Vector3.new(0, 5, 0), root.Position),
			Beats.cameraOutSeconds
		)
		waitBeat(Beats.cameraOutSeconds)
	end
	camera.CameraType = if originalCameraType == Enum.CameraType.Scriptable
		then Enum.CameraType.Custom
		else originalCameraType
	freeze(false)
	ClientState.cutsceneActive = false
	Remotes.event(Remotes.Names.CutsceneDone):FireServer()
	Sfx.play("go", 1)
	ui.run.Visible = true
	ui.run.TextTransparency = 0
	TweenService:Create(
		ui.run,
		TweenInfo.new(Beats.runTextSeconds + 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	):Play()
	task.delay(Beats.runTextSeconds + 0.7, function()
		ui.run.Visible = false
		if not running then
			ui.root.Visible = false
		end
	end)
	running = false
	ui.root.Visible = false
end

function CutsceneController.Init() end

function CutsceneController.Start()
	ClientState.BiomeEntered:Connect(function(biome, animal, firstTimeEver)
		if running then
			skipRequested = true
			task.wait(0.2)
		end
		task.spawn(play, biome, animal, firstTimeEver)
	end)
	UserInputService.InputBegan:Connect(function(_input, processed)
		if running and skipAllowed and not processed then
			skipRequested = true
		end
	end)
end

function CutsceneController.IsRunning(): boolean
	return running
end

return CutsceneController
