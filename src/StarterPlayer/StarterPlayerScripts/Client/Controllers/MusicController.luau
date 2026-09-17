--!strict
--[[
	MusicController
	Owns biome music: one looping Sound per biome (from BiomeDef.music, skipped when nil), a 1.5 s
	crossfade on biome change, an optional chase layer (BiomeDef.musicChase) whose volume rises as the
	animal closes in, and the Music / SFX group volumes bound to the player's settings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)

local CROSSFADE = 1.5
local CHASE_FAR = 120
local CHASE_NEAR = 30

local MusicController = {}

local group: SoundGroup? = nil
local current: Sound? = nil
local chaseLayer: Sound? = nil

local function getGroup(): SoundGroup
	if group then
		return group
	end
	local existing = SoundService:FindFirstChild("Music")
	if existing and existing:IsA("SoundGroup") then
		group = existing
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = "Music"
	created.Volume = 0.6
	created.Parent = SoundService
	group = created
	return created
end

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(CROSSFADE), { Volume = 0 })
	tween:Play()
	tween.Completed:Once(function()
		sound:Destroy()
	end)
end

local function makeLoop(id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = getGroup()
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(CROSSFADE), { Volume = volume }):Play()
	return sound
end

local function onBiomeChanged(_info: Types.ClientBiomeInfo, def: Types.BiomeDef)
	if current then
		fadeOut(current)
		current = nil
	end
	if chaseLayer then
		fadeOut(chaseLayer)
		chaseLayer = nil
	end
	if def.music and def.music ~= "" then
		current = makeLoop(def.music, 0.5)
	end
	if def.musicChase and def.musicChase ~= "" then
		chaseLayer = makeLoop(def.musicChase, 0)
	end
end

local function applySettings(settings: Types.PlayerSettings)
	getGroup().Volume = math.clamp(settings.musicVolume, 0, 1)
	Sfx.setVolume(settings.sfxVolume)
end

function MusicController.Init()
	getGroup()
end

function MusicController.Start()
	ClientState.BiomeChanged:Connect(onBiomeChanged)
	ClientState.DataLoaded:Connect(function(data)
		applySettings(data.settings)
	end)
	ClientState.SettingsChanged:Connect(applySettings)
	RunService.Heartbeat:Connect(function()
		local layer = chaseLayer
		if not layer then
			return
		end
		if ClientState.chaserMode ~= "chasing" then
			layer.Volume += (0 - layer.Volume) * 0.05
			return
		end
		local gap = ClientState.Gap()
		local target = math.clamp((CHASE_FAR - gap) / (CHASE_FAR - CHASE_NEAR), 0, 1) * 0.6
		layer.Volume += (target - layer.Volume) * 0.05
	end)
	if ClientState.biome and ClientState.biomeDef then
		onBiomeChanged(ClientState.biome, ClientState.biomeDef)
	end
end

return MusicController
