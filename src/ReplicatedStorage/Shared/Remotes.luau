--!strict
--[[
	Remotes
	Owns the ReplicatedStorage/Remotes folder and every RemoteEvent, UnreliableRemoteEvent and
	RemoteFunction the game uses. The kind of a remote is decided purely by its name:
	ChaserTick is unreliable, GetBiomeInfo / GetPlayerData are functions, everything else is an event.

	Server: the folder and the remotes are created lazily, the first time any remote is requested.
	That first access creates every named remote at once, so a client can never wait forever on a
	remote the server simply never touched. Client: WaitForChild, warning periodically while waiting.
	Asking for a remote with the wrong accessor (e.g. Remotes.event("ChaserTick")) errors immediately.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteKind = "event" | "unreliable" | "func"

local FOLDER_NAME = "Remotes"
local WAIT_WARN_SECONDS = 10

local Remotes = {}

--- Every remote name; use these instead of string literals.
Remotes.Names = table.freeze({
	BiomeEntered = "BiomeEntered",
	ChaserTick = "ChaserTick",
	ChaserEvent = "ChaserEvent",
	CutsceneDone = "CutsceneDone",
	RequestSkipStage = "RequestSkipStage",
	SettingsChanged = "SettingsChanged",
	StageChanged = "StageChanged",
	GetBiomeInfo = "GetBiomeInfo",
	GetPlayerData = "GetPlayerData",
	PurchaseRequest = "PurchaseRequest",
})

-- Creation order on the server (also the canonical list of names).
local ORDER: { string } = {
	Remotes.Names.BiomeEntered,
	Remotes.Names.ChaserTick,
	Remotes.Names.ChaserEvent,
	Remotes.Names.CutsceneDone,
	Remotes.Names.RequestSkipStage,
	Remotes.Names.SettingsChanged,
	Remotes.Names.StageChanged,
	Remotes.Names.GetBiomeInfo,
	Remotes.Names.GetPlayerData,
	Remotes.Names.PurchaseRequest,
}

local KIND_FOR_NAME: { [string]: RemoteKind } = {
	[Remotes.Names.ChaserTick] = "unreliable",
	[Remotes.Names.GetBiomeInfo] = "func",
	[Remotes.Names.GetPlayerData] = "func",
}
for _, name in ORDER do
	if KIND_FOR_NAME[name] == nil then
		KIND_FOR_NAME[name] = "event"
	end
end

local CLASS_FOR_KIND: { [RemoteKind]: string } = {
	event = "RemoteEvent",
	unreliable = "UnreliableRemoteEvent",
	func = "RemoteFunction",
}

--- name -> kind, for code that wants to introspect (frozen).
Remotes.Kinds = table.freeze(KIND_FOR_NAME)

local folderCache: Folder? = nil
local instanceCache: { [string]: Instance } = {}

local function isServer(): boolean
	return RunService:IsServer()
end

--- The kind a named remote must have. Errors for unknown names.
function Remotes.kindOf(name: string): RemoteKind
	local kind: RemoteKind? = KIND_FOR_NAME[name]
	if kind == nil then
		error(("Remotes: unknown remote name %q"):format(tostring(name)), 3)
	end
	return kind
end

local function waitForChildForever(parent: Instance, childName: string): Instance
	local found: Instance? = parent:WaitForChild(childName, WAIT_WARN_SECONDS)
	while found == nil do
		warn(("Remotes: still waiting for %s.%s"):format(parent:GetFullName(), childName))
		found = parent:WaitForChild(childName, WAIT_WARN_SECONDS)
	end
	return found :: Instance
end

local function createAll(folder: Folder)
	for _, name in ORDER do
		if folder:FindFirstChild(name) == nil then
			local instance = Instance.new(CLASS_FOR_KIND[KIND_FOR_NAME[name]])
			instance.Name = name
			instance.Parent = folder
		end
	end
end

local function getFolder(): Folder
	local cached = folderCache
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	local folder: Folder
	if isServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing ~= nil and existing:IsA("Folder") then
			folder = existing :: Folder
		else
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		createAll(folder)
	else
		local found = waitForChildForever(ReplicatedStorage, FOLDER_NAME)
		if not found:IsA("Folder") then
			error(("Remotes: ReplicatedStorage.%s is a %s, expected a Folder"):format(FOLDER_NAME, found.ClassName))
		end
		folder = found :: Folder
	end
	folderCache = folder
	return folder
end

local function getRemote(name: string, kind: RemoteKind): Instance
	local expected = Remotes.kindOf(name)
	if expected ~= kind then
		error(("Remotes: %q is a %s remote, use Remotes.%s(...)"):format(name, expected, expected), 3)
	end
	local cached: Instance? = instanceCache[name]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	local folder = getFolder()
	local className = CLASS_FOR_KIND[kind]
	local instance: Instance
	if isServer() then
		local existing = folder:FindFirstChild(name)
		if existing == nil then
			local created = Instance.new(className)
			created.Name = name
			created.Parent = folder
			instance = created
		else
			instance = existing
		end
	else
		instance = waitForChildForever(folder, name)
	end
	if instance.ClassName ~= className then
		error(("Remotes: %s.%s is a %s, expected a %s"):format(FOLDER_NAME, name, instance.ClassName, className), 3)
	end
	instanceCache[name] = instance
	return instance
end

--- A RemoteEvent by name (errors if the name belongs to another kind).
function Remotes.event(name: string): RemoteEvent
	return getRemote(name, "event") :: RemoteEvent
end

--- An UnreliableRemoteEvent by name (only ChaserTick).
function Remotes.unreliable(name: string): UnreliableRemoteEvent
	return getRemote(name, "unreliable") :: UnreliableRemoteEvent
end

--- A RemoteFunction by name (GetBiomeInfo, GetPlayerData).
function Remotes.func(name: string): RemoteFunction
	return getRemote(name, "func") :: RemoteFunction
end

return Remotes
