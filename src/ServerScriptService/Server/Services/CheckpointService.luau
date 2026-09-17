--!strict
--[[
	CheckpointService
	Owns stage progression: which stage each player is on, accepting checkpoint touches strictly in
	order, spawning characters at their checkpoint facing along the path, the BiomeEntered /
	BiomeCompleted / StageChanged signals other services react to, death counting, the skip and
	revive products, and the two client RemoteFunctions (biome info, player data).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Biomes = require(Shared.Config.Biomes)
local PathUtil = require(Shared.PathUtil)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local BiomeRegistry = require(script.Parent.BiomeRegistry)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local SPAWN_HEIGHT = 4
local REVIVE_INVULNERABLE_SECONDS = 3

local CheckpointService = {}
CheckpointService.StageChanged = Signal.new() :: Signal.Signal<Player, number, number>
CheckpointService.BiomeEntered = Signal.new() :: Signal.Signal<Player, number>
CheckpointService.BiomeCompleted = Signal.new() :: Signal.Signal<Player, number>

local stageOf: { [Player]: number } = {}
local enteredOnce: { [Player]: boolean } = {}
local lastDeathPosition: { [Player]: Vector3 } = {}
local reviveAt: { [Player]: Vector3 } = {}
local touchDebounce: { [Player]: number } = {}

function CheckpointService.GetStage(player: Player): number
	local stage = stageOf[player]
	if stage then
		return stage
	end
	local data = DataService.Get(player)
	return if data then data.stage else 1
end

local function awardBadge(player: Player, id: number)
	if id == 0 then
		return
	end
	task.spawn(function()
		pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
	end)
end

function CheckpointService.SetStage(player: Player, stage: number, reason: string)
	stage = math.clamp(math.floor(stage), 1, GameConfig.TotalStages + 1)
	local old = CheckpointService.GetStage(player)
	if stage == old then
		return
	end
	stageOf[player] = stage
	local newBiome = BiomeRegistry.BiomeForStage(stage)
	local oldBiome = BiomeRegistry.BiomeForStage(old)
	DataService.Update(player, function(data)
		data.stage = stage
	end)
	DataService.RefreshLeaderstats(player, Biomes[newBiome].name)
	Remotes.event(Remotes.Names.StageChanged):FireClient(player, stage, newBiome, BiomeRegistry.StageInBiome(stage))
	CheckpointService.StageChanged:Fire(player, stage, old)
	if stage > GameConfig.TotalStages then
		CheckpointService.BiomeCompleted:Fire(player, GameConfig.BiomeCount)
		awardBadge(player, GameConfig.Badges.Finished)
	elseif newBiome ~= oldBiome then
		if newBiome > oldBiome then
			CheckpointService.BiomeCompleted:Fire(player, oldBiome)
			if newBiome > GameConfig.BiomeCount / 2 and oldBiome <= GameConfig.BiomeCount / 2 then
				awardBadge(player, GameConfig.Badges.HalfWay)
			end
		end
		CheckpointService.BiomeEntered:Fire(player, newBiome)
	end
	if reason == "product" then
		DataService.Save(player)
	end
end

local function placeCharacter(player: Player, character: Model)
	local stage = CheckpointService.GetStage(player)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then
		return
	end
	local revive = reviveAt[player]
	if revive then
		reviveAt[player] = nil
		character:PivotTo(CFrame.new(revive + Vector3.new(0, SPAWN_HEIGHT, 0)))
		character:SetAttribute("Invulnerable", true)
		task.delay(REVIVE_INVULNERABLE_SECONDS, function()
			if character.Parent then
				character:SetAttribute("Invulnerable", nil)
			end
		end)
		return
	end
	local checkpoint = BiomeRegistry.CheckpointPart(stage)
	local biome = BiomeRegistry.Get(BiomeRegistry.BiomeForStage(stage))
	local s = BiomeRegistry.CheckpointS(stage)
	local _, tangent = PathUtil.positionAt(biome.path, math.min(s + 2, biome.path.length))
	local position = checkpoint.Position + Vector3.new(0, checkpoint.Size.Y / 2 + SPAWN_HEIGHT, 0)
	local flat = Vector3.new(tangent.X, 0, tangent.Z)
	local look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	character:PivotTo(CFrame.lookAlong(position, look))
end

local function onCharacterAdded(player: Player, character: Model)
	local data = DataService.WaitForData(player, 30)
	if not data or not character.Parent then
		return
	end
	if stageOf[player] == nil then
		stageOf[player] = data.stage
	end
	placeCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				lastDeathPosition[player] = root.Position
			end
			DataService.Update(player, function(d)
				d.deaths += 1
			end)
		end)
	end
	if not enteredOnce[player] then
		enteredOnce[player] = true
		local biome = BiomeRegistry.BiomeForStage(CheckpointService.GetStage(player))
		DataService.RefreshLeaderstats(player, Biomes[biome].name)
		CheckpointService.BiomeEntered:Fire(player, biome)
	end
end

local function onCheckpointTouched(part: BasePart, hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local now = os.clock()
	if (touchDebounce[player] or 0) > now then
		return
	end
	touchDebounce[player] = now + 0.2
	local stage = part:GetAttribute("Stage")
	if type(stage) ~= "number" then
		return
	end
	local current = CheckpointService.GetStage(player)
	if stage == current + 1 then
		CheckpointService.SetStage(player, stage, "touch")
	end
end

function CheckpointService.Respawn(player: Player)
	if player.Parent then
		task.spawn(function()
			pcall(function()
				player:LoadCharacterAsync()
			end)
		end)
	end
end

local function registerProducts()
	MonetizationService.RegisterProduct("SkipStage", function(player)
		local current = CheckpointService.GetStage(player)
		if current > GameConfig.TotalStages then
			return false
		end
		CheckpointService.SetStage(player, current + 1, "product")
		CheckpointService.Respawn(player)
		return true
	end)
	MonetizationService.RegisterProduct("SkipBiome", function(player)
		local current = CheckpointService.GetStage(player)
		if current > GameConfig.TotalStages then
			return false
		end
		local nextBiome = BiomeRegistry.BiomeForStage(current) + 1
		local target = if nextBiome > GameConfig.BiomeCount
			then GameConfig.TotalStages + 1
			else (nextBiome - 1) * GameConfig.StagesPerBiome + 1
		CheckpointService.SetStage(player, target, "product")
		CheckpointService.Respawn(player)
		return true
	end)
	MonetizationService.RegisterProduct("ReviveHere", function(player)
		local position = lastDeathPosition[player]
		if not position then
			return false
		end
		reviveAt[player] = position
		CheckpointService.Respawn(player)
		return true
	end)
end

function CheckpointService.Init()
	Players.RespawnTime = 1.5
	registerProducts()
end

function CheckpointService.Start()
	for _, runtime in pairs(BiomeRegistry.All()) do
		for _, checkpoint in runtime.checkpoints do
			checkpoint.Touched:Connect(function(hit)
				onCheckpointTouched(checkpoint, hit)
			end)
		end
		if runtime.exit then
			local exit = runtime.exit
			exit.Touched:Connect(function(hit)
				onCheckpointTouched(exit, hit)
			end)
		end
	end

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(onCharacterAdded, player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stageOf[player] = nil
		enteredOnce[player] = nil
		lastDeathPosition[player] = nil
		reviveAt[player] = nil
		touchDebounce[player] = nil
	end)
	DataService.Loaded:Connect(function(player, data)
		if stageOf[player] == nil then
			stageOf[player] = data.stage
		end
		DataService.RefreshLeaderstats(player, Biomes[BiomeRegistry.BiomeForStage(data.stage)].name)
	end)

	Remotes.func(Remotes.Names.GetBiomeInfo).OnServerInvoke = function(_player, index: unknown)
		if type(index) ~= "number" or index ~= index or index < 1 or index > GameConfig.BiomeCount then
			return nil
		end
		return BiomeRegistry.ClientInfo(math.floor(index))
	end
	Remotes.func(Remotes.Names.GetPlayerData).OnServerInvoke = function(player)
		return DataService.WaitForData(player, 15)
	end
end

return CheckpointService
