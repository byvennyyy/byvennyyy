--!strict
--[[
	Client bootstrap. Wires the remotes into ClientState (biome info, stage, chaser ticks and events,
	player data), projects the local character onto the biome path every frame, and boots every
	controller (Init then Start), each wrapped so one failure never takes the HUD down.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local GameConfig = require(Shared.Config.GameConfig)
local PathUtil = require(Shared.PathUtil)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ClientState = require(script.ClientState)

type Controller = { Init: () -> (), Start: () -> () }

local Controllers = script.Controllers
local controllers: { { name: string, controller: Controller } } = {
	{ name = "ChaserRenderer", controller = require(Controllers.ChaserRenderer) :: Controller },
	{ name = "CutsceneController", controller = require(Controllers.CutsceneController) :: Controller },
	{ name = "ProgressBarController", controller = require(Controllers.ProgressBarController) :: Controller },
	{ name = "HUDController", controller = require(Controllers.HUDController) :: Controller },
	{ name = "MusicController", controller = require(Controllers.MusicController) :: Controller },
	{ name = "EggDexController", controller = require(Controllers.EggDexController) :: Controller },
	{ name = "SettingsController", controller = require(Controllers.SettingsController) :: Controller },
}

local player = Players.LocalPlayer

local function biomeForStage(stage: number): number
	return math.clamp(math.ceil(stage / GameConfig.StagesPerBiome), 1, GameConfig.BiomeCount)
end

local loadingBiome: number? = nil

local function loadBiome(index: number)
	if ClientState.biomeIndex == index or loadingBiome == index then
		return
	end
	loadingBiome = index
	local ok, info = pcall(function()
		return Remotes.func(Remotes.Names.GetBiomeInfo):InvokeServer(index)
	end)
	loadingBiome = nil
	if not ok or type(info) ~= "table" then
		warn(`[Client] could not load biome {index}: {info}`)
		return
	end
	local biomeInfo = info :: Types.ClientBiomeInfo
	ClientState.biome = biomeInfo
	ClientState.biomeDef = Biomes[index]
	ClientState.path = PathUtil.build(biomeInfo.points)
	ClientState.biomeIndex = index
	ClientState.chaserS = biomeInfo.checkpointS[1] or 0
	ClientState.playerS = ClientState.chaserS
	ClientState.BiomeChanged:Fire(biomeInfo, Biomes[index])
end

local function wireRemotes()
	Remotes.event(Remotes.Names.StageChanged).OnClientEvent
		:Connect(function(stage: number, biome: number, stageInBiome: number)
			ClientState.stage = stage
			ClientState.stageInBiome = stageInBiome
			if ClientState.data then
				ClientState.data.stage = stage
			end
			task.spawn(loadBiome, biome)
			ClientState.StageChanged:Fire(stage, biome, stageInBiome)
		end)
	Remotes.unreliable(Remotes.Names.ChaserTick).OnClientEvent:Connect(function(s: number, mode: Types.ChaserMode)
		if type(s) ~= "number" then
			return
		end
		ClientState.chaserS = s
		ClientState.chaserMode = mode
		ClientState.Tick:Fire(s, mode)
	end)
	Remotes.event(Remotes.Names.ChaserEvent).OnClientEvent
		:Connect(function(kind: Types.ChaserEventKind, biome: number, extra)
			if kind == "Hatched" then
				ClientState.chaseStartedAt = os.clock()
				ClientState.chaserMode = "chasing"
			elseif kind == "Defeated" then
				ClientState.chaserMode = "defeated"
				if ClientState.data and type(extra) == "table" and type(extra.animal) == "string" then
					ClientState.data.tamed[extra.animal] = true
				end
			elseif kind == "Reset" then
				ClientState.chaserMode = "frozen"
			end
			ClientState.ChaserEvent:Fire(kind, biome, extra)
		end)
	Remotes.event(Remotes.Names.BiomeEntered).OnClientEvent
		:Connect(function(biome: number, animal: string, firstTimeEver: boolean)
			task.spawn(function()
				loadBiome(biome)
				ClientState.chaserAnimal = animal
				ClientState.chaserMode = "frozen"
				if ClientState.data then
					ClientState.data.eggsHatched[tostring(biome)] = true
				end
				ClientState.BiomeEntered:Fire(biome, animal, firstTimeEver)
			end)
		end)
end

local function loadData()
	local ok, data = pcall(function()
		return Remotes.func(Remotes.Names.GetPlayerData):InvokeServer()
	end)
	if ok and type(data) == "table" then
		ClientState.data = data :: Types.PlayerData
		ClientState.stage = (data :: Types.PlayerData).stage
		ClientState.stageInBiome = (ClientState.stage - 1) % GameConfig.StagesPerBiome + 1
		ClientState.DataLoaded:Fire(data :: Types.PlayerData)
		loadBiome(biomeForStage(ClientState.stage))
	else
		warn(`[Client] player data unavailable: {data}`)
	end
end

local function projectPlayer()
	local path = ClientState.path
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not path or not root or not root:IsA("BasePart") then
		return
	end
	ClientState.playerS = PathUtil.project(path, root.Position, ClientState.playerS, GameConfig.ProjectionWindow)
end

for _, entry in controllers do
	local ok, err = pcall(function()
		entry.controller.Init()
	end)
	if not ok then
		warn(`[Client] {entry.name}.Init failed: {err}`)
	end
end
wireRemotes()
for _, entry in controllers do
	local ok, err = pcall(function()
		entry.controller.Start()
	end)
	if not ok then
		warn(`[Client] {entry.name}.Start failed: {err}`)
	end
end
task.spawn(loadData)
RunService.RenderStepped:Connect(projectPlayer)
