--!strict
--[[
	DataService
	Owns player persistence: loading a PlayerData profile from DataStoreService with retries, keeping a
	per-session cache, autosaving dirty profiles, saving on leave and on server close, and keeping the
	leaderstats folder in sync. A profile that fails to load is served from defaults in READ-ONLY mode so
	a DataStore outage can never overwrite real progress with a fresh profile.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData

type Session = {
	data: PlayerData,
	dirty: boolean,
	readOnly: boolean,
	saving: boolean,
}

local RETRY_DELAYS = { 1, 2, 4, 8, 16 }
local CLOSE_SAVE_TIMEOUT = 25

local DataService = {}
DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

function DataService.Default(): PlayerData
	return {
		stage = 1,
		deaths = 0,
		tamed = {},
		eggsHatched = {},
		settings = { skipCutscenes = false, musicVolume = 0.6, sfxVolume = 0.8, showGap = true },
		purchases = {},
		biomeBestTimes = {},
		equippedPet = nil,
	}
end

-- Loaded values win; missing fields (new keys added in later versions) are filled from the defaults.
local function deepMerge(default: any, loaded: any): any
	if type(loaded) ~= "table" then
		return default
	end
	local out: { [any]: any } = {}
	for k, v in pairs(loaded) do
		out[k] = v
	end
	for k, v in pairs(default) do
		if type(v) == "table" and next(v) ~= nil then
			out[k] = deepMerge(v, loaded[k])
		elseif out[k] == nil then
			out[k] = v
		end
	end
	return out
end

local function sanitize(data: PlayerData): PlayerData
	data.stage = math.clamp(math.floor(tonumber(data.stage) or 1), 1, GameConfig.TotalStages + 1)
	data.deaths = math.max(0, math.floor(tonumber(data.deaths) or 0))
	return data
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T?)
	for attempt = 1, #RETRY_DELAYS + 1 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} failed (attempt {attempt}): {result}`)
		local delay = RETRY_DELAYS[attempt]
		if not delay then
			break
		end
		task.wait(delay)
	end
	return false, nil
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
		return result
	end
	warn(`[DataService] DataStore unavailable: {result}`)
	return nil
end

local function load(player: Player)
	local session: Session = { data = DataService.Default(), dirty = false, readOnly = false, saving = false }
	local ds = getStore()
	if ds then
		local ok, raw = withRetries(`load {player.Name}`, function()
			return ds:GetAsync(keyFor(player))
		end)
		if ok then
			session.data = sanitize(deepMerge(DataService.Default(), raw))
		else
			session.readOnly = true
			warn(`[DataService] {player.Name} is READ-ONLY this session; progress will not be saved`)
		end
	else
		session.readOnly = true
	end
	if not player.Parent then
		return
	end
	sessions[player] = session
	DataService.Loaded:Fire(player, session.data)
end

local function save(player: Player, session: Session): boolean
	if session.readOnly or session.saving then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	session.saving = true
	local snapshot = session.data
	local ok = withRetries(`save {player.Name}`, function()
		return ds:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	session.saving = false
	if ok then
		session.dirty = false
	end
	return ok
end

function DataService.Get(player: Player): PlayerData?
	local session = sessions[player]
	return if session then session.data else nil
end

--- Yields until the player's data is loaded (or the timeout elapses).
function DataService.WaitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while os.clock() < deadline do
		local data = DataService.Get(player)
		if data then
			return data
		end
		if not player.Parent then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.Update(player: Player, mutator: (PlayerData) -> ())
	local session = sessions[player]
	if not session then
		return
	end
	mutator(session.data)
	session.dirty = true
end

function DataService.Save(player: Player)
	local session = sessions[player]
	if session then
		save(player, session)
	end
end

function DataService.IsReadOnly(player: Player): boolean
	local session = sessions[player]
	return if session then session.readOnly else true
end

function DataService.RefreshLeaderstats(player: Player, biomeName: string?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local existing = player:FindFirstChild("leaderstats")
	local folder: Instance
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		local stage = Instance.new("IntValue")
		stage.Name = "Stage"
		stage.Parent = created
		local biome = Instance.new("StringValue")
		biome.Name = "Biome"
		biome.Parent = created
		created.Parent = player
		folder = created
	end
	local stageValue = folder:FindFirstChild("Stage")
	if stageValue and stageValue:IsA("IntValue") then
		stageValue.Value = math.min(data.stage, GameConfig.TotalStages)
	end
	local biomeValue = folder:FindFirstChild("Biome")
	if biomeValue and biomeValue:IsA("StringValue") and biomeName then
		biomeValue.Value = biomeName
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		sessions[player] = nil
		if session then
			save(player, session)
		end
	end)
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player, session in pairs(sessions) do
				if session.dirty then
					task.spawn(save, player, session)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player, session in pairs(sessions) do
			if session.dirty and not session.readOnly then
				pending += 1
				task.spawn(function()
					save(player, session)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 3 else CLOSE_SAVE_TIMEOUT)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
