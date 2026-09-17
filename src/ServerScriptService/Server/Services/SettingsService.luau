--!strict
--[[
	SettingsService
	Owns validation and persistence of the client-editable settings (cutscene skipping, gap label,
	music and sfx volume, equipped pet). Every field is type-checked and clamped before it touches data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Biomes = require(Shared.Config.Biomes)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local KNOWN_ANIMALS: { [string]: boolean } = {}
for _, biome in ipairs(Biomes) do
	KNOWN_ANIMALS[biome.animal] = true
end

local function asBoolean(value: unknown, fallback: boolean): boolean
	return if type(value) == "boolean" then value else fallback
end

local function asVolume(value: unknown, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(value, 0, 1)
end

local function onSettingsChanged(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local incoming = payload :: { [string]: unknown }
	DataService.Update(player, function(data)
		local s = data.settings
		s.skipCutscenes = asBoolean(incoming.skipCutscenes, s.skipCutscenes)
		s.showGap = asBoolean(incoming.showGap, s.showGap)
		s.musicVolume = asVolume(incoming.musicVolume, s.musicVolume)
		s.sfxVolume = asVolume(incoming.sfxVolume, s.sfxVolume)
		local pet = incoming.equippedPet
		if pet == nil or pet == "" then
			if incoming.equippedPet ~= nil then
				data.equippedPet = nil
			end
		elseif type(pet) == "string" and KNOWN_ANIMALS[pet] and data.tamed[pet] then
			data.equippedPet = pet
		end
	end)
end

function SettingsService.Init() end

function SettingsService.Start()
	Remotes.event(Remotes.Names.SettingsChanged).OnServerEvent:Connect(onSettingsChanged)
end

return SettingsService
