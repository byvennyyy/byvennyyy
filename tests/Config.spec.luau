--!nonstrict
-- Spec for Shared/Config/{GameConfig,Biomes,Difficulty}.luau under the standalone luau CLI.
local T = require("./assert")
local GameConfig = require("./GameConfig")
local Biomes = require("./Biomes")
local Difficulty = require("./Difficulty")

local PROFILES =
	{ steady = true, bursty = true, stalker = true, flyer = true, swimmer = true, blinker = true, roarer = true }
local LOCOMOTION = { ground = true, flying = true, swimming = true, hovering = true }
-- Keys ChaseProfiles.luau reads for each profile; anything else in params would be dead data.
local KNOWN_PARAMS = {
	steady = {},
	bursty = { burstSeconds = true, restSeconds = true, burstMultiplier = true, restMultiplier = true },
	stalker = { idleCap = true, idleGain = true },
	flyer = { hoverHeight = true, bobAmplitude = true, bobPeriod = true },
	swimmer = { hoverHeight = true, bobAmplitude = true, bobPeriod = true },
	blinker = { blinkPeriod = true, blinkStuds = true, telegraphSeconds = true, baseMultiplier = true },
	roarer = { roarEvery = true, roarSeconds = true, sprintSeconds = true, sprintMultiplier = true },
}
local FOLDERS = { Animal = true, BaseAnimals = true }
local EXPECTED_ANIMALS = {
	"Capybara",
	"GoldenRetriver",
	"Cat",
	"Tanuki",
	"Quokka",
	"Kangaroo",
	"HoneyBadger",
	"Cassowary",
	"Gorilla",
	"Shark",
	"Crocodile",
	"Mamoth",
	"SABER_TOOTHED_TIGER",
	"QUETZALCOATLUS",
	"MEGALODON",
	"MINOTAUR",
	"CERBERUS",
	"KRAKEN",
	"FIREPHOENIX",
	"CLASSICDRAGON",
}
local CUSTOM_FOLDER = { Tanuki = true, Quokka = true, HoneyBadger = true, Cassowary = true }

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n += 1
	end
	return n
end

T.test("GameConfig is frozen and internally consistent", function()
	T.truthy(table.isfrozen(GameConfig))
	T.truthy(table.isfrozen(GameConfig.Monetization))
	T.truthy(table.isfrozen(GameConfig.Cutscene))
	T.eq(GameConfig.BiomeCount, 20)
	T.eq(GameConfig.StagesPerBiome, 10)
	T.eq(GameConfig.TotalStages, GameConfig.BiomeCount * GameConfig.StagesPerBiome)
	T.eq(GameConfig.DataStoreName, "PlayerData_v1")
	T.eq(GameConfig.ChaserTickRate, 15)
	T.eq(GameConfig.Grid.columns, 4)
	T.near(GameConfig.Cutscene.totalSeconds, 5.2)
	T.eq(GameConfig.Cutscene.skippableAfterFirstView, true)
	local c = GameConfig.Cutscene
	local beats = c.cameraInSeconds
		+ c.wobbleSeconds
		+ c.burstSeconds
		+ c.cardSeconds
		+ c.cameraOutSeconds
		+ c.runTextSeconds
	T.near(beats, c.totalSeconds, 1e-6, "cutscene beats add up to totalSeconds")
	T.eq(GameConfig.Monetization.Gamepasses.VIP, 0)
	T.eq(GameConfig.Monetization.Products.SkipStage, 0)
	T.eq(GameConfig.Badges.Finished, 0)
end)

T.test("TierColors has the 14 standard tiers in order", function()
	T.eq(count(GameConfig.TierColors), 14)
	T.eq(#GameConfig.TierOrder, 14)
	T.eq(GameConfig.TierOrder[1], "Easy")
	T.eq(GameConfig.TierOrder[14], "Nil")
	for _, tier in GameConfig.TierOrder do
		T.truthy(GameConfig.TierColors[tier], "colour for " .. tier)
	end
	T.eq(GameConfig.TierColors.Catastrophic:ToHex(), "FFFFFF")
end)

T.test("there are exactly 20 biomes and indexes match positions", function()
	T.eq(#Biomes, 20)
	T.truthy(table.isfrozen(Biomes))
	for position, def in ipairs(Biomes) do
		T.eq(def.index, position, "index of biome " .. position)
		T.truthy(table.isfrozen(def), "biome " .. position .. " frozen")
		T.truthy(table.isfrozen(def.chase), "chase " .. position .. " frozen")
		T.truthy(table.isfrozen(def.palette), "palette " .. position .. " frozen")
	end
end)

T.test("animals, names and tiers are unique and match the roster order", function()
	local seenAnimal, seenName, seenTier = {}, {}, {}
	for position, def in ipairs(Biomes) do
		T.eq(def.animal, EXPECTED_ANIMALS[position], "animal at " .. position)
		T.falsy(seenAnimal[def.animal], "duplicate animal " .. def.animal)
		T.falsy(seenName[def.name], "duplicate biome name " .. def.name)
		T.falsy(seenTier[def.tier], "duplicate tier " .. def.tier)
		seenAnimal[def.animal] = true
		seenName[def.name] = true
		seenTier[def.tier] = true
	end
	T.eq(Biomes[1].tier, "Easy")
	T.eq(Biomes[14].tier, "Nil")
	T.eq(Biomes[4].animal, "Tanuki")
	T.eq(Biomes[4].animalFolder, "Animal")
end)

T.test("every biome has valid enums, folder, colour, palette and hazards", function()
	local seenPalette = {}
	for _, def in ipairs(Biomes) do
		T.truthy(PROFILES[def.chase.profile], "profile " .. tostring(def.chase.profile))
		T.truthy(LOCOMOTION[def.locomotion], "locomotion " .. tostring(def.locomotion))
		T.truthy(FOLDERS[def.animalFolder], "folder " .. tostring(def.animalFolder))
		T.eq(def.animalFolder, if CUSTOM_FOLDER[def.animal] then "Animal" else "BaseAnimals", def.animal .. " folder")
		T.truthy(def.tierColor, "tierColor " .. def.name)
		T.truthy(def.tierColor.ToHex, "tierColor is a Color3")
		if GameConfig.TierColors[def.tier] then
			T.eq(def.tierColor:ToHex(), GameConfig.TierColors[def.tier]:ToHex(), "standard tier colour " .. def.tier)
		end
		local key = def.palette.primary:ToHex() .. def.palette.secondary:ToHex() .. def.palette.accent:ToHex()
		T.falsy(seenPalette[key], "duplicate palette for " .. def.name)
		seenPalette[key] = true
		T.truthy(#def.hazards >= 1, "hazards for " .. def.name)
		T.eq(def.eggModel, nil)
		T.eq(def.music, nil)
		T.eq(type(def.theme), "string")
		T.eq(type(def.chase.params), "table")
		T.truthy(table.isfrozen(def.chase.params), "params frozen for " .. def.name)
		for key, value in pairs(def.chase.params) do
			T.truthy(KNOWN_PARAMS[def.chase.profile][key], def.name .. " has unknown param " .. tostring(key))
			T.eq(type(value), "number", def.name .. " param " .. tostring(key))
		end
	end
end)

T.test("chase configs ramp monotonically from biome 1 to 20", function()
	T.near(Biomes[1].chase.baseSpeed, 9)
	T.near(Biomes[20].chase.baseSpeed, 20)
	T.truthy(Biomes[1].chase.headStart >= 10, "biome 1 head start is generous")
	for i = 2, 20 do
		local prev, cur = Biomes[i - 1].chase, Biomes[i].chase
		T.truthy(cur.baseSpeed >= prev.baseSpeed, "baseSpeed non-decreasing at " .. i)
		T.truthy(cur.headStart >= 8, "headStart never below 8 s at " .. i)
	end
	for _, def in ipairs(Biomes) do
		local c = def.chase
		T.truthy(c.respawnHeadStart >= 2 and c.respawnHeadStart <= 5, "respawnHeadStart range " .. def.name)
		T.truthy(c.resetGap >= 20 and c.resetGap <= 60, "resetGap range " .. def.name)
		T.eq(c.catchDistance, 3)
		T.eq(c.catchRadius, 6)
		T.truthy(c.maxGap > c.mercyGap, "maxGap above mercyGap " .. def.name)
		T.truthy(c.catchUpMultiplier > 1, "catchUp above 1 " .. def.name)
		T.truthy(c.mercyMultiplier < 1 and c.mercyMultiplier > 0, "mercy below 1 " .. def.name)
	end
end)

T.test("every profile is used at least once", function()
	local used = {}
	for _, def in ipairs(Biomes) do
		used[def.chase.profile] = true
	end
	for profile in pairs(PROFILES) do
		T.truthy(used[profile], "profile " .. profile .. " unused")
	end
end)

T.test("biome mechanics follow Difficulty.MechanicOrder", function()
	T.eq(#Difficulty.MechanicOrder, 20)
	local seen = {}
	for i, key in ipairs(Difficulty.MechanicOrder) do
		T.falsy(seen[key], "duplicate mechanic " .. key)
		seen[key] = true
		T.eq(Biomes[i].mechanic, key, "mechanic of biome " .. i)
	end
	T.eq(Difficulty.MechanicOrder[1], "gapJump")
	T.eq(Difficulty.MechanicOrder[20], "laserGrid")
	T.truthy(table.isfrozen(Difficulty.MechanicOrder))
end)

T.test("Difficulty curve endpoints, clamping and freezing", function()
	local first, last = Difficulty.Get(1), Difficulty.Get(20)
	T.near(first.gapMin, 3)
	T.near(first.gapMax, 5)
	T.near(first.platformMin, 8)
	T.near(first.platformMax, 12)
	T.near(first.killDensity, 0.05)
	T.near(first.moverSpeed, 6)
	T.near(first.timingWindow, 2.2)
	T.eq(first.chunksPerStage, 8)
	T.near(first.heightVariance, 1)
	T.near(last.gapMin, 8)
	T.near(last.gapMax, 11)
	T.near(last.platformMin, 2.5)
	T.near(last.platformMax, 4)
	T.near(last.killDensity, 0.55)
	T.near(last.moverSpeed, 22)
	T.near(last.timingWindow, 0.7)
	T.eq(last.chunksPerStage, 16)
	T.near(last.heightVariance, 8)
	T.eq(Difficulty.Get(0), first, "clamped low")
	T.eq(Difficulty.Get(-5), first)
	T.eq(Difficulty.Get(99), last, "clamped high")
	T.eq(Difficulty.Get(1), first, "cached")
	T.truthy(table.isfrozen(first))
	T.throws(function()
		first.gapMin = 100
	end, "DifficultyDef is frozen")
end)

T.test("Difficulty curve is monotonic across 1..20", function()
	for i = 2, 20 do
		local a, b = Difficulty.Get(i - 1), Difficulty.Get(i)
		T.truthy(b.gapMin >= a.gapMin, "gapMin at " .. i)
		T.truthy(b.gapMax >= a.gapMax, "gapMax at " .. i)
		T.truthy(b.platformMin <= a.platformMin, "platformMin at " .. i)
		T.truthy(b.platformMax <= a.platformMax, "platformMax at " .. i)
		T.truthy(b.killDensity >= a.killDensity, "killDensity at " .. i)
		T.truthy(b.moverSpeed >= a.moverSpeed, "moverSpeed at " .. i)
		T.truthy(b.timingWindow <= a.timingWindow, "timingWindow at " .. i)
		T.truthy(b.chunksPerStage >= a.chunksPerStage, "chunksPerStage at " .. i)
		T.truthy(b.heightVariance >= a.heightVariance, "heightVariance at " .. i)
		T.truthy(b.gapMin < b.gapMax, "gapMin < gapMax at " .. i)
		T.truthy(b.platformMin < b.platformMax, "platformMin < platformMax at " .. i)
		T.eq(b.chunksPerStage, math.floor(b.chunksPerStage), "integer chunksPerStage at " .. i)
	end
end)

T.test("MechanicsFor unlocks the first i keys plus turn", function()
	local one = Difficulty.MechanicsFor(1)
	T.eq(#one, 3)
	T.eq(one[1], "platformRun")
	T.eq(one[2], "gapJump")
	T.eq(one[3], "turn")
	local five = Difficulty.MechanicsFor(5)
	T.eq(#five, 7)
	T.eq(five[6], "conveyor")
	T.eq(five[7], "turn")
	local all = Difficulty.MechanicsFor(20)
	T.eq(#all, 22)
	for _, key in ipairs(Difficulty.MechanicOrder) do
		T.truthy(table.find(all, key), "MechanicsFor(20) contains " .. key)
	end
	T.truthy(table.find(all, "turn"))
	T.eq(#Difficulty.MechanicsFor(0), 3, "clamped low")
	T.eq(#Difficulty.MechanicsFor(50), 22, "clamped high")
	all[1] = "mutated"
	T.eq(Difficulty.MechanicsFor(20)[1], "platformRun", "returns a fresh array")
end)

return T.finish()
