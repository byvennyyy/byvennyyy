--!strict
--[[
	ChaseProfiles

	Owns the seven chaser behaviour profiles (steady, bursty, stalker, flyer, swimmer, blinker, roarer)
	as pure, stateless functions of time. The server calls multiplier() and blinkStep() every Heartbeat
	to shape how fast the chaser advances along its path; the client calls verticalOffset() and
	telegraph() to render the animal (hover height, warning effect before a blink or during a roar).
	Nothing here touches Instances, so the module also runs under the standalone luau CLI for tests.

	Conventions:
	- `t` is seconds since the chaser started chasing (monotonic, >= 0). Non-finite or negative values
	  are treated as 0 so the math can never error.
	- `params` is the biome's profile-specific tuning table (ChaseConfig.params). Every key is optional
	  and falls back to the defaults documented next to each profile; non-finite values are ignored.
	- Unknown profile names never error: multiplier 1, blinkStep 0, telegraph false, verticalOffset 0.
]]

local Types = require(script.Parent.Types)

type ChaseProfileName = Types.ChaseProfileName
type Locomotion = Types.Locomotion
type Params = { [string]: number }

local TWO_PI = 2 * math.pi

local ChaseProfiles = {}

local names: { ChaseProfileName } = { "steady", "bursty", "stalker", "flyer", "swimmer", "blinker", "roarer" }
ChaseProfiles.Names = table.freeze(names)

-- True for a real, finite number (rejects NaN and +-inf).
local function isFinite(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- params[key] when it is a finite number, otherwise `default`. Tolerates a missing params table.
local function param(params: Params?, key: string, default: number): number
	if params == nil then
		return default
	end
	local value = params[key]
	if isFinite(value) then
		return value
	end
	return default
end

-- A duration in seconds (or a distance): finite and >= 0, otherwise `default`.
local function duration(params: Params?, key: string, default: number): number
	local value = param(params, key, default)
	if value >= 0 then
		return value
	end
	return default
end

-- A period in seconds: finite and > 0, otherwise `default` (a zero period would divide by zero).
local function period(params: Params?, key: string, default: number): number
	local value = param(params, key, default)
	if value > 0 then
		return value
	end
	return default
end

-- Coerces a time value to a finite, non-negative number.
local function clock(t: number): number
	if not isFinite(t) then
		return 0
	end
	return math.max(t, 0)
end

-- bursty: square wave of burstSeconds at burstMultiplier followed by restSeconds at restMultiplier.
-- Defaults: burstMultiplier 1.5, burstSeconds 2, restMultiplier 0.6, restSeconds 3. Starts bursting.
local function burstyMultiplier(params: Params?, t: number): number
	local burstSeconds = duration(params, "burstSeconds", 2)
	local restSeconds = duration(params, "restSeconds", 3)
	local cycle = burstSeconds + restSeconds
	if cycle <= 0 then
		return 1
	end
	if t % cycle < burstSeconds then
		return param(params, "burstMultiplier", 1.5)
	end
	return param(params, "restMultiplier", 0.6)
end

-- stalker: 1 + min(playerIdleSeconds, idleCap) * idleGain. Defaults: idleCap 4, idleGain 0.35.
local function stalkerMultiplier(params: Params?, playerIdleSeconds: number): number
	local idleCap = duration(params, "idleCap", 4)
	local idleGain = param(params, "idleGain", 0.35)
	local idle = math.min(clock(playerIdleSeconds), idleCap)
	return 1 + idle * idleGain
end

-- roarer: phase within the roarEvery cycle plus the roar and sprint window lengths.
-- Defaults: roarEvery 9, roarSeconds 1.2, sprintSeconds 2.5. The roar opens each cycle (t = 0, 9, 18, ...).
local function roarPhase(params: Params?, t: number): (number, number, number)
	local roarEvery = period(params, "roarEvery", 9)
	local roarSeconds = math.min(duration(params, "roarSeconds", 1.2), roarEvery)
	local sprintSeconds = duration(params, "sprintSeconds", 2.5)
	return t % roarEvery, roarSeconds, sprintSeconds
end

-- roarer: 0 while roaring, sprintMultiplier (default 1.6) for sprintSeconds afterwards, else 1.
local function roarerMultiplier(params: Params?, t: number): number
	local phase, roarSeconds, sprintSeconds = roarPhase(params, t)
	if phase < roarSeconds then
		return 0
	elseif phase < roarSeconds + sprintSeconds then
		return param(params, "sprintMultiplier", 1.6)
	end
	return 1
end

--[[
	Speed multiplier applied to the biome's base speed this tick. Never negative.
	steady / flyer / swimmer = 1, blinker = params.baseMultiplier (default 0.8; the jump itself comes from
	blinkStep), bursty / stalker / roarer as documented on their helpers. Unknown profiles return 1.
]]
function ChaseProfiles.multiplier(
	profile: ChaseProfileName,
	params: Params,
	t: number,
	playerIdleSeconds: number
): number
	local now = clock(t)
	local result = 1
	if profile == "bursty" then
		result = burstyMultiplier(params, now)
	elseif profile == "stalker" then
		result = stalkerMultiplier(params, playerIdleSeconds)
	elseif profile == "blinker" then
		result = param(params, "baseMultiplier", 0.8)
	elseif profile == "roarer" then
		result = roarerMultiplier(params, now)
	end
	return math.max(result, 0)
end

--[[
	Extra studs the chaser jumps forward this tick. Only the blinker blinks: it returns params.blinkStuds
	(default 25) exactly once per params.blinkPeriod (default 6) seconds, on the tick whose (t - dt, t]
	interval crosses a period boundary (t = 6, 12, 18, ...). A tick that spans several boundaries
	(lag spike) still blinks only once. Everything else, dt <= 0 and t <= 0 return 0.
]]
function ChaseProfiles.blinkStep(profile: ChaseProfileName, params: Params, t: number, dt: number): number
	if profile ~= "blinker" then
		return 0
	end
	local now = clock(t)
	local step = clock(dt)
	if step <= 0 then
		return 0
	end
	local blinkPeriod = period(params, "blinkPeriod", 6)
	local before = math.floor(math.max(now - step, 0) / blinkPeriod)
	local after = math.floor(now / blinkPeriod)
	if after > before then
		return duration(params, "blinkStuds", 25)
	end
	return 0
end

--[[
	True while the client should play a warning effect: for the blinker during the last
	params.telegraphSeconds (default 0.8) before each blink, for the roarer during the roar window.
	Every other profile returns false.
]]
function ChaseProfiles.telegraph(profile: ChaseProfileName, params: Params, t: number): boolean
	local now = clock(t)
	if profile == "blinker" then
		local blinkPeriod = period(params, "blinkPeriod", 6)
		local telegraphSeconds = math.min(duration(params, "telegraphSeconds", 0.8), blinkPeriod)
		if telegraphSeconds <= 0 then
			return false
		end
		return now % blinkPeriod >= blinkPeriod - telegraphSeconds
	elseif profile == "roarer" then
		local phase, roarSeconds = roarPhase(params, now)
		return phase < roarSeconds
	end
	return false
end

type HoverDefaults = { height: number, amplitude: number, bobPeriod: number }

local FLYING: HoverDefaults = { height = 8, amplitude = 1.5, bobPeriod = 2 }
local SWIMMING: HoverDefaults = { height = -2, amplitude = 0.5, bobPeriod = 4 }
local HOVERING: HoverDefaults = { height = 3, amplitude = 0.75, bobPeriod = 3 }
local GROUNDED: HoverDefaults = { height = 0, amplitude = 0, bobPeriod = 2 }

-- Keyed by profile name and, for convenience, by Locomotion name so a renderer can pass either.
local HOVER_DEFAULTS: { [string]: HoverDefaults } = table.freeze({
	flyer = FLYING,
	flying = FLYING,
	swimmer = SWIMMING,
	swimming = SWIMMING,
	hovering = HOVERING,
})

--[[
	Render-only vertical offset (studs) above the path point, so movement stays a straight scalar
	along the path and only the visual bobs. flyer hovers at params.hoverHeight (default 8) with a
	sine bob of params.bobAmplitude (default 1.5) over params.bobPeriod (default 2 s); swimmer sits at
	-2 with a slow, small bob; "hovering" (locomotion) sits at 3; everything else is 0. Any profile
	may override hoverHeight / bobAmplitude / bobPeriod through params. At t = 0 the offset is exactly
	the hover height.
]]
function ChaseProfiles.verticalOffset(profile: ChaseProfileName | Locomotion, params: Params, t: number): number
	local defaults = HOVER_DEFAULTS[profile] or GROUNDED
	local height = param(params, "hoverHeight", defaults.height)
	local amplitude = param(params, "bobAmplitude", defaults.amplitude)
	if amplitude == 0 then
		return height
	end
	local bobPeriod = period(params, "bobPeriod", defaults.bobPeriod)
	return height + math.sin(clock(t) / bobPeriod * TWO_PI) * amplitude
end

return table.freeze(ChaseProfiles)
