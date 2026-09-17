--!strict
--[[
	ChaserRenderer
	Owns the visible animal for the local player: resolves the biome's model (or a placeholder),
	places it on the path at the server's chaser position with smoothing, hover/bob offsets by
	locomotion, run/idle animations (or a procedural bob when the rig has none), a lunge toward the
	player when close, telegraph highlights, and the caught/reset/defeated effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetResolver = require(Shared.AssetResolver)
local ChaseProfiles = require(Shared.ChaseProfiles)
local PathUtil = require(Shared.PathUtil)
local Types = require(Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local ModelPrep = require(script.Parent.Parent.ModelPrep)

local WAYPOINT_HEIGHT = 3
local SMOOTH_RATE = 12
local LUNGE_RANGE = 7
local SHAKE_SECONDS = 0.45

local ChaserRenderer = {}

local player = Players.LocalPlayer
local folder: Folder? = nil
local current: ModelPrep.Prepared? = nil
local currentDef: Types.BiomeDef? = nil
local highlight: Highlight? = nil
local renderedS = 0
local retired: { Model } = {}

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "ClientChasers"
	created.Parent = workspace
	folder = created
	return created
end

local function destroyCurrent()
	if current then
		current.model:Destroy()
		current = nil
	end
	highlight = nil
end

local function spawnModel(def: Types.BiomeDef)
	destroyCurrent()
	local source = AssetResolver.animal(def.animal, def.animalFolder)
		or AssetResolver.placeholderAnimal(def.animal, def.palette)
	local prepared = ModelPrep.prepare(source)
	prepared.model.Name = `Chaser_{def.animal}`
	local hl = Instance.new("Highlight")
	hl.Name = "Telegraph"
	hl.FillColor = Color3.fromRGB(255, 60, 60)
	hl.OutlineColor = Color3.fromRGB(255, 120, 120)
	hl.FillTransparency = 0.6
	hl.Enabled = false
	hl.Parent = prepared.model
	highlight = hl
	prepared.model.Parent = getFolder()
	current = prepared
	currentDef = def
	renderedS = ClientState.chaserS
end

local function shakeCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > SHAKE_SECONDS then
			connection:Disconnect()
			return
		end
		local strength = (1 - t / SHAKE_SECONDS) * 0.5
		camera.CFrame = camera.CFrame
			* CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end)
end

local function retireDefeated()
	local prepared = current
	if not prepared then
		return
	end
	current = nil
	highlight = nil
	local model = prepared.model
	table.insert(retired, model)
	local pivot = model:GetPivot()
	local fallen = pivot * CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(0, -prepared.halfHeight * 0.4, 0)
	local proxy = Instance.new("CFrameValue")
	proxy.Value = pivot
	proxy.Changed:Connect(function(value)
		model:PivotTo(value)
	end)
	TweenService
		:Create(proxy, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = fallen })
		:Play()
	task.delay(3, function()
		proxy:Destroy()
		model:Destroy()
		local index = table.find(retired, model)
		if index then
			table.remove(retired, index)
		end
	end)
end

local function render(dt: number)
	local prepared = current
	local def = currentDef
	local path = ClientState.path
	if not prepared or not def or not path then
		return
	end
	local model = prepared.model
	if ClientState.cutsceneActive then
		if model.Parent then
			model.Parent = nil
		end
		return
	elseif not model.Parent then
		model.Parent = getFolder()
	end
	local mode = ClientState.chaserMode
	local target = ClientState.chaserS
	if mode == "frozen" or math.abs(target - renderedS) > 60 then
		renderedS = target
	else
		renderedS += (target - renderedS) * math.min(1, dt * SMOOTH_RATE)
	end
	local t = os.clock() - ClientState.chaseStartedAt
	local position, tangent = PathUtil.positionAt(path, renderedS)
	local vertical = ChaseProfiles.verticalOffset(def.locomotion, def.chase.params, t)
	local flat = Vector3.new(tangent.X, 0, tangent.Z)
	local look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local moving = mode == "chasing"

	-- lunge toward the real player position when the along-path gap is small
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local gap = ClientState.playerS - renderedS
	if moving and root and root:IsA("BasePart") and gap < LUNGE_RANGE then
		local alpha = math.clamp(1 - gap / LUNGE_RANGE, 0, 0.85)
		local behind = root.Position - root.CFrame.LookVector * 2.5 - Vector3.new(0, WAYPOINT_HEIGHT, 0)
		position = position:Lerp(behind, alpha)
	end

	local bob = 0
	local tilt = CFrame.identity
	local hasTracks = next(prepared.tracks) ~= nil
	if hasTracks then
		ModelPrep.play(prepared, if moving then "run" else "idle")
	elseif moving and def.locomotion == "ground" then
		bob = math.abs(math.sin(t * 9)) * 0.45
		tilt = CFrame.Angles(math.sin(t * 9) * math.rad(4), 0, 0)
	end
	local pivotHeight = prepared.halfHeight - WAYPOINT_HEIGHT + vertical + bob
	model:PivotTo(CFrame.lookAlong(position + Vector3.new(0, pivotHeight, 0), look) * tilt)

	local hl = highlight
	if hl then
		local telegraph = moving and ChaseProfiles.telegraph(def.chase.profile, def.chase.params, t)
		hl.Enabled = telegraph
		if telegraph then
			hl.FillTransparency = 0.4 + 0.3 * math.sin(os.clock() * 12)
		end
	end
end

function ChaserRenderer.Init() end

function ChaserRenderer.Start()
	ClientState.BiomeEntered:Connect(function(biome)
		local def = ClientState.biomeDef
		if def and def.index == biome then
			spawnModel(def)
		end
	end)
	ClientState.ChaserEvent:Connect(function(kind)
		if kind == "Caught" then
			shakeCamera()
		elseif kind == "Reset" then
			renderedS = ClientState.chaserS
		elseif kind == "Defeated" then
			retireDefeated()
		end
	end)
	RunService.RenderStepped:Connect(render)
end

--- The model currently rendered (for the progress bar's viewport clone), or nil.
function ChaserRenderer.CurrentModel(): Model?
	return if current then current.model else nil
end

return ChaserRenderer
