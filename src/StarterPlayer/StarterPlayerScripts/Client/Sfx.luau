--!strict
--[[
	Sfx
	Owns the short one-shot sounds (hatch, caught, checkpoint, tamed, heartbeat) behind a single
	SoundGroup whose volume follows the player's sfx setting. Asset ids are placeholders (empty = no
	sound) so missing audio never errors; drop your rbxassetid strings into IDS.
]]

local SoundService = game:GetService("SoundService")

local IDS: { [string]: string } = {
	crack = "",
	burst = "",
	roar = "",
	go = "",
	caught = "",
	checkpoint = "",
	tamed = "",
	heartbeat = "",
	click = "",
}

local Sfx = {}

local group: SoundGroup? = nil

local function getGroup(): SoundGroup
	if group then
		return group
	end
	local existing = SoundService:FindFirstChild("SFX")
	if existing and existing:IsA("SoundGroup") then
		group = existing
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = "SFX"
	created.Volume = 0.8
	created.Parent = SoundService
	group = created
	return created
end

function Sfx.setVolume(volume: number)
	getGroup().Volume = math.clamp(volume, 0, 1)
end

--- Plays a one-shot; returns the Sound (or nil when no id is configured).
function Sfx.play(name: string, volume: number?, parent: Instance?): Sound?
	local id = IDS[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `Sfx_{name}`
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.SoundGroup = getGroup()
	sound.Parent = parent or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	return sound
end

--- A looping sound the caller controls (volume/stop); nil when not configured.
function Sfx.loop(name: string, volume: number?): Sound?
	local id = IDS[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `Loop_{name}`
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume or 0
	sound.SoundGroup = getGroup()
	sound.Parent = SoundService
	sound:Play()
	return sound
end

return Sfx
