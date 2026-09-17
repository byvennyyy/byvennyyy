--!strict
--[[
	GameConfig
	Owns every global tunable that is not per-biome: stage counts, chaser tick rate, data store
	names, world grid layout, cutscene beat timings, monetization ids, badge ids and the standard
	difficulty-chart tier colours. The table (and every nested table) is frozen; nothing here is
	mutated at runtime. Pure data, so it also loads under the CLI test harness.
]]

-- The 14 standard community difficulty-chart tiers, in order, with their usual colours.
local TIER_ORDER: { string } = {
	"Easy",
	"Medium",
	"Hard",
	"Difficult",
	"Challenging",
	"Intense",
	"Remorseless",
	"Insane",
	"Extreme",
	"Terrifying",
	"Catastrophic",
	"Horrific",
	"Unreal",
	"Nil",
}

local TIER_COLORS: { [string]: Color3 } = {
	Easy = Color3.fromRGB(117, 243, 71),
	Medium = Color3.fromRGB(255, 254, 0),
	Hard = Color3.fromRGB(253, 124, 0),
	Difficult = Color3.fromRGB(255, 0, 0),
	Challenging = Color3.fromRGB(192, 0, 0),
	Intense = Color3.fromRGB(25, 34, 45),
	Remorseless = Color3.fromRGB(200, 0, 200),
	Insane = Color3.fromRGB(0, 0, 255),
	Extreme = Color3.fromRGB(3, 137, 255),
	Terrifying = Color3.fromRGB(0, 255, 255),
	Catastrophic = Color3.fromRGB(255, 255, 255),
	Horrific = Color3.fromRGB(150, 149, 255),
	Unreal = Color3.fromRGB(99, 0, 145),
	Nil = Color3.fromRGB(101, 102, 109),
}

local GameConfig = {
	StagesPerBiome = 10,
	BiomeCount = 20,
	TotalStages = 200,
	GenerateMissingBiomes = true,
	ChaserTickRate = 15, -- Hz
	ProjectionWindow = 120, -- studs searched around the last s when projecting
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 60, -- seconds

	-- Biomes are laid out on a columns x rows grid of square cells, each biome one step higher.
	Grid = table.freeze({ columns = 4, cellSize = 2500, altitudeStep = 60 }),

	-- Egg-hatch cutscene beats (seconds). The beat timings add up to totalSeconds.
	Cutscene = table.freeze({
		totalSeconds = 5.2,
		skippableAfterFirstView = true,
		cameraInSeconds = 0.6, -- tween to the 3/4 pedestal view
		wobbleSeconds = 1.4, -- egg wobbles with growing amplitude
		wobbleCount = 3,
		burstSeconds = 0.45, -- flash, shell burst, animal scales in with overshoot
		cardSeconds = 1.75, -- biome name / tier card hold
		cameraOutSeconds = 0.5, -- tween back to the player
		runTextSeconds = 0.5, -- "RUN!" text hold after control returns
		shakeMagnitude = 0.6, -- camera shake studs at the burst
		shellFragmentLifetime = 2, -- seconds before Debris removes shell fragments
	}),

	-- All ids are 0 until the products exist; services treat 0 as "not configured".
	Monetization = table.freeze({
		Gamepasses = table.freeze({ SpeedCoil = 0, GravityCoil = 0, DoubleHeadStart = 0, VIP = 0, PetFollow = 0 }),
		Products = table.freeze({ SkipStage = 0, SkipBiome = 0, ReviveHere = 0 }),
	}),

	Badges = table.freeze({ FirstHatch = 0, HalfWay = 0, Finished = 0 }),

	-- Standard difficulty-chart tiers (Easy .. Nil) and their community colours.
	TierOrder = table.freeze(TIER_ORDER),
	TierColors = table.freeze(TIER_COLORS),
}

return table.freeze(GameConfig)
