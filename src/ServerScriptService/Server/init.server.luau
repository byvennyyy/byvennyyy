--!strict
--[[
	Server bootstrap. Requires every service, calls Init on all of them in dependency order, then
	Start in the same order. Each step is wrapped so one failing service leaves the rest running.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

type Service = { Init: () -> (), Start: () -> () }

local Services = script.Services
local order: { { name: string, service: Service } } = {
	{ name = "DataService", service = require(Services.DataService) :: Service },
	{ name = "MonetizationService", service = require(Services.MonetizationService) :: Service },
	{ name = "BiomeRegistry", service = require(Services.BiomeRegistry) :: Service },
	{ name = "CheckpointService", service = require(Services.CheckpointService) :: Service },
	{ name = "ChaserService", service = require(Services.ChaserService) :: Service },
	{ name = "SettingsService", service = require(Services.SettingsService) :: Service },
}

-- create every remote up front so clients never wait on a late service
for _, name in pairs(Remotes.Names) do
	local kind = Remotes.kindOf(name)
	if kind == "func" then
		Remotes.func(name)
	elseif kind == "unreliable" then
		Remotes.unreliable(name)
	else
		Remotes.event(name)
	end
end

local started = os.clock()
for _, entry in order do
	local ok, err = pcall(function()
		entry.service.Init()
	end)
	if not ok then
		warn(`[Server] {entry.name}.Init failed: {err}`)
	end
end
for _, entry in order do
	local ok, err = pcall(function()
		entry.service.Start()
	end)
	if not ok then
		warn(`[Server] {entry.name}.Start failed: {err}`)
	end
end

local BiomeRegistry = require(Services.BiomeRegistry)
local total = 0
for index = 1, GameConfig.BiomeCount do
	local ok, runtime = pcall(BiomeRegistry.Get, index)
	if ok then
		total += runtime.path.length
	end
end
print(
	string.format(
		"[Server] ready in %.1f s: %d biomes, %d stages, %.0f studs of path",
		os.clock() - started,
		GameConfig.BiomeCount,
		GameConfig.TotalStages,
		total
	)
)
