--!strict
--[[
	ClientState
	Owns the client's view of the game: the current biome (path, checkpoints, egg pedestal, def),
	stage numbers, the last chaser position/mode from the server, the locally projected player
	position along the path, the loaded PlayerData, and the signals controllers subscribe to.
	init.client.luau is the only writer; controllers read and listen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local ClientState = {
	biome = nil :: Types.ClientBiomeInfo?,
	biomeDef = nil :: Types.BiomeDef?,
	path = nil :: Types.PathData?,
	biomeIndex = 0,
	stage = 1,
	stageInBiome = 1,
	chaserS = 0,
	chaserMode = "inactive" :: Types.ChaserMode,
	chaserAnimal = "",
	chaseStartedAt = 0, -- os.clock() when the server said Hatched (chase began)
	playerS = 0,
	data = nil :: Types.PlayerData?,
	cutsceneActive = false,

	BiomeChanged = Signal.new() :: Signal.Signal<Types.ClientBiomeInfo, Types.BiomeDef>,
	StageChanged = Signal.new() :: Signal.Signal<number, number, number>,
	Tick = Signal.new() :: Signal.Signal<number, Types.ChaserMode>,
	ChaserEvent = Signal.new() :: Signal.Signal<Types.ChaserEventKind, number, { [string]: any }?>,
	BiomeEntered = Signal.new() :: Signal.Signal<number, string, boolean>,
	DataLoaded = Signal.new() :: Signal.Signal<Types.PlayerData>,
	SettingsChanged = Signal.new() :: Signal.Signal<Types.PlayerSettings>,

	ToggleEggDex = Instance.new("BindableEvent"),
	ToggleSettings = Instance.new("BindableEvent"),
	ToggleShop = Instance.new("BindableEvent"),
}

--- Along-path gap between the player and the chaser in studs (positive = chaser behind).
function ClientState.Gap(): number
	return ClientState.playerS - ClientState.chaserS
end

return ClientState
