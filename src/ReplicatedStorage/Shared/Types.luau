--!strict
--[[
	Types
	Owns every shared type used by the server, the client and the config modules. This module holds
	only type exports and returns an empty frozen table; require it for its types and never redeclare
	them elsewhere: `local Types = require(Shared.Types)` then `type BiomeDef = Types.BiomeDef`.
]]

export type ChaseProfileName = "steady" | "bursty" | "stalker" | "flyer" | "swimmer" | "blinker" | "roarer"

export type Locomotion = "ground" | "flying" | "swimming" | "hovering"

export type Palette = { primary: Color3, secondary: Color3, accent: Color3, ground: Color3 }

export type ChaseConfig = {
	profile: ChaseProfileName,
	baseSpeed: number, -- studs/s
	headStart: number, -- seconds frozen after hatch
	respawnHeadStart: number, -- seconds frozen after a catch/death reset
	resetGap: number, -- studs behind the checkpoint the chaser resets to
	catchDistance: number, -- along-path studs that count as a catch
	catchRadius: number, -- 3D studs; both conditions required
	maxGap: number, -- beyond this gap the chaser gets catchUpMultiplier
	catchUpMultiplier: number,
	mercyGap: number, -- within this gap, a player moving well gets mercyMultiplier
	mercyMultiplier: number,
	params: { [string]: number }, -- profile-specific (burstPeriod, blinkStuds, roarEvery, ...)
}

export type BiomeDef = {
	index: number,
	name: string, -- player-facing biome name
	tier: string, -- difficulty label
	tierColor: Color3,
	theme: string,
	animal: string, -- exact model name
	animalFolder: "Animal" | "BaseAnimals",
	locomotion: Locomotion,
	eggModel: string?, -- name under Assets/Eggs, nil = procedural egg
	renderImage: string?, -- optional rbxassetid for the progress-bar marker
	palette: Palette,
	chase: ChaseConfig,
	mechanic: string, -- chunk key this biome introduces (see Chunks)
	hazards: { string },
	music: string?, -- rbxassetid
	musicChase: string?, -- optional intensity layer
}

export type DifficultyDef = {
	gapMin: number,
	gapMax: number, -- horizontal jump gaps in studs
	platformMin: number,
	platformMax: number, -- platform side length
	killDensity: number, -- 0..1 fraction of lanes that are kill bricks
	moverSpeed: number, -- studs/s for moving platforms
	timingWindow: number, -- seconds the safe window stays open
	chunksPerStage: number, -- stage length in chunks
	heightVariance: number, -- studs of vertical drift between chunks
}

export type PathData = { points: { Vector3 }, cumulative: { number }, length: number }

export type ClientBiomeInfo = {
	index: number,
	points: { Vector3 },
	checkpointS: { number },
	length: number,
	eggPedestal: CFrame,
}

export type ChaserMode = "inactive" | "frozen" | "chasing" | "defeated"

export type ChaserEventKind = "Hatched" | "Caught" | "Defeated" | "Reset"

export type PlayerSettings = { skipCutscenes: boolean, musicVolume: number, sfxVolume: number, showGap: boolean }

export type PlayerData = {
	stage: number, -- 1..200 (201 = finished)
	deaths: number,
	tamed: { [string]: boolean }, -- animal name -> true
	eggsHatched: { [string]: boolean }, -- tostring(biomeIndex) -> true (DataStore keys must be strings)
	settings: PlayerSettings,
	purchases: { [string]: boolean }, -- gamepass key -> true
	biomeBestTimes: { [string]: number },
	equippedPet: string?,
}

return table.freeze({})
