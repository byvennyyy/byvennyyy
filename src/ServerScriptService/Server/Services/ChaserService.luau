--!strict
--[[
	ChaserService
	Owns the server-authoritative animal chaser for every player. The chaser is a scalar `s` (studs
	along the biome path). Each Heartbeat the player is projected onto the path, the chaser advances by
	the biome's base speed times the chase-profile multiplier times the rubber band, catches are
	detected (along-path distance AND 3D radius, or sustained contact), deaths reset the chaser behind
	the checkpoint with a fresh head start, and finishing a biome defeats and tames the animal. The
	position is streamed to the owning player at GameConfig.ChaserTickRate through an unreliable remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BadgeService = game:GetService("BadgeService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ChaseProfiles = require(Shared.ChaseProfiles)
local PathUtil = require(Shared.PathUtil)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local BiomeRegistry = require(script.Parent.BiomeRegistry)
local CheckpointService = require(script.Parent.CheckpointService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

export type ChaserState = {
	biome: number,
	s: number,
	mode: Types.ChaserMode,
	frozenUntil: number,
	startedAt: number,
	biomeStartedAt: number,
	playerS: number,
	lastPlayerPos: Vector3?,
	idleSeconds: number,
	progressRate: number, -- smoothed studs/s of forward progress
	contactSeconds: number,
	tickAccumulator: number,
}

local MERCY_MIN_RATE = 4 -- studs/s of forward progress that counts as "playing well"
local IDLE_RATE = 2 -- studs/s below which the player counts as idle
local CONTACT_CATCH_SECONDS = 1.0
local DEFEATED_LINGER = 3

local ChaserService = {}

local states: { [Player]: ChaserState } = {}

local function now(): number
	return os.clock()
end

local function sendEvent(player: Player, kind: Types.ChaserEventKind, biome: number, extra: { [string]: any }?)
	Remotes.event(Remotes.Names.ChaserEvent):FireClient(player, kind, biome, extra)
end

local function awardBadge(player: Player, id: number)
	if id == 0 then
		return
	end
	task.spawn(function()
		pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
	end)
end

local function onBiomeEntered(player: Player, biome: number)
	local runtime = BiomeRegistry.Get(biome)
	local chase = runtime.def.chase
	local data = DataService.Get(player)
	local key = tostring(biome)
	local firstTimeEver = not (data and data.eggsHatched[key])
	local headStart = chase.headStart * (if MonetizationService.Owns(player, "DoubleHeadStart") then 2 else 1)
	local startS = PathUtil.project(runtime.path, runtime.eggPedestal.Position)
	states[player] = {
		biome = biome,
		s = startS,
		mode = "frozen",
		frozenUntil = now() + GameConfig.Cutscene.totalSeconds + headStart,
		startedAt = 0,
		biomeStartedAt = now(),
		playerS = BiomeRegistry.CheckpointS(CheckpointService.GetStage(player)),
		lastPlayerPos = nil,
		idleSeconds = 0,
		progressRate = 0,
		contactSeconds = 0,
		tickAccumulator = 0,
	}
	DataService.Update(player, function(d)
		d.eggsHatched[key] = true
	end)
	if firstTimeEver and biome == 1 then
		awardBadge(player, GameConfig.Badges.FirstHatch)
	end
	Remotes.event(Remotes.Names.BiomeEntered):FireClient(player, biome, runtime.def.animal, firstTimeEver)
end

local function onBiomeCompleted(player: Player, biome: number)
	local state = states[player]
	if not state or state.biome ~= biome then
		return
	end
	local runtime = BiomeRegistry.Get(biome)
	state.mode = "defeated"
	local elapsed = now() - state.biomeStartedAt
	DataService.Update(player, function(d)
		d.tamed[runtime.def.animal] = true
		local key = tostring(biome)
		local best = d.biomeBestTimes[key]
		if not best or elapsed < best then
			d.biomeBestTimes[key] = math.floor(elapsed * 100) / 100
		end
	end)
	sendEvent(player, "Defeated", biome, { animal = runtime.def.animal, seconds = elapsed })
	task.delay(DEFEATED_LINGER, function()
		if states[player] == state then
			states[player] = nil
		end
	end)
end

local function resetBehindCheckpoint(player: Player, state: ChaserState)
	local stage = CheckpointService.GetStage(player)
	if BiomeRegistry.BiomeForStage(stage) ~= state.biome or stage > GameConfig.TotalStages then
		return
	end
	local chase = BiomeRegistry.Get(state.biome).def.chase
	local checkpointS = BiomeRegistry.CheckpointS(stage)
	state.s = math.max(0, checkpointS - chase.resetGap)
	state.playerS = checkpointS
	state.mode = "frozen"
	state.frozenUntil = now() + Players.RespawnTime + chase.respawnHeadStart
	state.contactSeconds = 0
	state.idleSeconds = 0
	state.progressRate = 0
	state.lastPlayerPos = nil
	sendEvent(player, "Reset", state.biome)
end

local function onCutsceneDone(player: Player)
	local state = states[player]
	if not state or state.mode ~= "frozen" then
		return
	end
	local chase = BiomeRegistry.Get(state.biome).def.chase
	local headStart = chase.headStart * (if MonetizationService.Owns(player, "DoubleHeadStart") then 2 else 1)
	state.frozenUntil = math.min(state.frozenUntil, now() + math.max(1, headStart))
end

local function catchPlayer(player: Player, state: ChaserState, humanoid: Humanoid)
	humanoid.Health = 0
	sendEvent(player, "Caught", state.biome)
end

local function step(dt: number)
	local t0 = now()
	for player, state in pairs(states) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local runtime = BiomeRegistry.Get(state.biome)
		local chase = runtime.def.chase
		local path = runtime.path

		-- player projection, idle and progress tracking
		local newS = PathUtil.project(path, root.Position, state.playerS, GameConfig.ProjectionWindow)
		local moved = if state.lastPlayerPos then (root.Position - state.lastPlayerPos).Magnitude else 0
		if moved / dt < IDLE_RATE then
			state.idleSeconds += dt
		else
			state.idleSeconds = 0
		end
		local instantRate = (newS - state.playerS) / dt
		state.progressRate += (instantRate - state.progressRate) * math.min(1, dt * 4)
		state.playerS = newS
		state.lastPlayerPos = root.Position

		if state.mode == "frozen" and t0 >= state.frozenUntil then
			state.mode = "chasing"
			state.startedAt = t0
			sendEvent(player, "Hatched", state.biome)
		end

		if state.mode == "chasing" then
			local elapsed = t0 - state.startedAt
			local multiplier = ChaseProfiles.multiplier(chase.profile, chase.params, elapsed, state.idleSeconds)
			local gap = state.playerS - state.s
			local speed = chase.baseSpeed * multiplier
			if gap > chase.maxGap then
				speed *= chase.catchUpMultiplier
			elseif gap < chase.mercyGap and state.progressRate >= MERCY_MIN_RATE then
				speed = math.min(speed * chase.mercyMultiplier, state.progressRate * 0.9)
			end
			state.s += speed * dt + ChaseProfiles.blinkStep(chase.profile, chase.params, elapsed, dt)
			state.s = math.min(state.s, state.playerS)
			gap = state.playerS - state.s
			if gap <= chase.catchDistance and not character:GetAttribute("Invulnerable") then
				state.contactSeconds += dt
				local chaserPosition = PathUtil.positionAt(path, state.s)
				local close = (root.Position - chaserPosition).Magnitude <= chase.catchRadius
				if close or state.contactSeconds >= CONTACT_CATCH_SECONDS then
					catchPlayer(player, state, humanoid)
				end
			else
				state.contactSeconds = 0
			end
			player:SetAttribute("ChaserGap", math.floor(gap))
		end

		state.tickAccumulator += dt
		if state.tickAccumulator >= 1 / GameConfig.ChaserTickRate then
			state.tickAccumulator = 0
			Remotes.unreliable(Remotes.Names.ChaserTick):FireClient(player, state.s, state.mode)
		end
	end
end

function ChaserService.GetState(player: Player): ChaserState?
	return states[player]
end

function ChaserService.Init() end

function ChaserService.Start()
	CheckpointService.BiomeEntered:Connect(onBiomeEntered)
	CheckpointService.BiomeCompleted:Connect(onBiomeCompleted)
	Remotes.event(Remotes.Names.CutsceneDone).OnServerEvent:Connect(onCutsceneDone)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					local state = states[player]
					if state and state.mode ~= "defeated" then
						resetBehindCheckpoint(player, state)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return ChaserService
