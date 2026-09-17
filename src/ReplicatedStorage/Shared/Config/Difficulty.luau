--!strict
--[[
	Difficulty
	Owns the per-biome difficulty scalars used by the greybox generator and the order in which
	obstacle mechanics (chunk keys) are unlocked. `Get(i)` linearly interpolates every scalar between
	biome 1 and biome 20 (indices are rounded and clamped to 1..20) and returns a frozen, cached
	DifficultyDef. `MechanicsFor(i)` lists the chunk keys allowed at biome i: the first i keys of
	MechanicOrder plus "turn", which is always allowed. Pure data/functions; runs under the CLI harness.
]]

local Types = require(script.Parent.Parent.Types)

type DifficultyDef = Types.DifficultyDef

local BIOME_COUNT = 20
local TURN_KEY = "turn"

local Difficulty = {}

--- One chunk key per biome, in the order biomes introduce them. Biome i introduces MechanicOrder[i].
Difficulty.MechanicOrder = table.freeze({
	"platformRun",
	"gapJump",
	"killLane",
	"movingPlatform",
	"spinner",
	"conveyor",
	"trussClimb",
	"wallHop",
	"icePatch",
	"windTunnel",
	"darkCorridor",
	"risingLava",
	"fallingFloor",
	"teleportPad",
	"fanLaunch",
	"shrinkingPlatform",
	"rotatingBar",
	"narrowBeam",
	"bouncePad",
	"laserGrid",
}) :: { string }

--- The chunk key that is allowed in every biome regardless of unlocks.
Difficulty.TurnKey = TURN_KEY

-- { first biome value, last biome value } for every scalar.
local CURVE = {
	gapMin = { 3, 8 },
	gapMax = { 5, 11 },
	platformMin = { 8, 2.5 },
	platformMax = { 12, 4 },
	killDensity = { 0.05, 0.55 },
	moverSpeed = { 6, 22 },
	timingWindow = { 2.2, 0.7 },
	chunksPerStage = { 8, 16 },
	heightVariance = { 1, 8 },
}

local cache: { [number]: DifficultyDef } = {}

local function clampIndex(biomeIndex: number): number
	if biomeIndex ~= biomeIndex then -- NaN guard
		return 1
	end
	return math.clamp(math.round(biomeIndex), 1, BIOME_COUNT)
end

local function lerp(range: { number }, t: number): number
	local value = range[1] + (range[2] - range[1]) * t
	return math.round(value * 1000) / 1000
end

--- Interpolated difficulty scalars for a biome (rounded and clamped to 1..20). The result is frozen.
function Difficulty.Get(biomeIndex: number): DifficultyDef
	local index = clampIndex(biomeIndex)
	local cached = cache[index]
	if cached ~= nil then
		return cached
	end
	local t = (index - 1) / (BIOME_COUNT - 1)
	local def: DifficultyDef = table.freeze({
		gapMin = lerp(CURVE.gapMin, t),
		gapMax = lerp(CURVE.gapMax, t),
		platformMin = lerp(CURVE.platformMin, t),
		platformMax = lerp(CURVE.platformMax, t),
		killDensity = lerp(CURVE.killDensity, t),
		moverSpeed = lerp(CURVE.moverSpeed, t),
		timingWindow = lerp(CURVE.timingWindow, t),
		chunksPerStage = math.round(lerp(CURVE.chunksPerStage, t)),
		heightVariance = lerp(CURVE.heightVariance, t),
	})
	cache[index] = def
	return def
end

--- Every chunk key unlocked at or before this biome, plus "turn". Returns a fresh array each call.
function Difficulty.MechanicsFor(biomeIndex: number): { string }
	local count = clampIndex(biomeIndex)
	local keys: { string } = table.create(count + 1)
	for index = 1, count do
		keys[index] = Difficulty.MechanicOrder[index]
	end
	keys[count + 1] = TURN_KEY
	return keys
end

return Difficulty
