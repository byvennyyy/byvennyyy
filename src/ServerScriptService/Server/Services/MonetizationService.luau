--!strict
--[[
	MonetizationService
	Owns gamepass ownership caching, developer-product receipts (idempotent through a purchase ledger),
	purchase prompts requested by the client, and the passive gamepass effects (coils). Products are
	granted through handlers registered by other services (CheckpointService registers the skips).
	Ids of 0 in GameConfig.Monetization mean "not configured yet" and are ignored safely.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

type ProductHandler = (Player) -> boolean

local LEDGER_STORE = "PurchaseLedger_v1"
local SPEED_COIL_WALKSPEED = 24
local GRAVITY_COIL_JUMP_POWER = 65

local MonetizationService = {}

local ownershipCache: { [Player]: { [string]: boolean } } = {}
local productHandlers: { [string]: ProductHandler } = {}
local ledger: DataStore? = nil

local function gamepassKeyForId(id: number): string?
	for key, passId in pairs(GameConfig.Monetization.Gamepasses) do
		if passId == id then
			return key
		end
	end
	return nil
end

local function productKeyForId(id: number): string?
	for key, productId in pairs(GameConfig.Monetization.Products) do
		if productId == id then
			return key
		end
	end
	return nil
end

local function applyPassiveEffects(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if MonetizationService.Owns(player, "SpeedCoil") then
		humanoid.WalkSpeed = SPEED_COIL_WALKSPEED
	end
	if MonetizationService.Owns(player, "GravityCoil") then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = GRAVITY_COIL_JUMP_POWER
	end
end

function MonetizationService.RegisterProduct(key: string, handler: ProductHandler)
	productHandlers[key] = handler
end

--- Cached ownership; the first query per player and pass goes to MarketplaceService.
function MonetizationService.Owns(player: Player, gamepassKey: string): boolean
	local passId = GameConfig.Monetization.Gamepasses[gamepassKey]
	if not passId or passId == 0 then
		return false
	end
	local cache = ownershipCache[player]
	if not cache then
		cache = {}
		ownershipCache[player] = cache
	end
	local cached = cache[gamepassKey]
	if cached ~= nil then
		return cached
	end
	local data = DataService.Get(player)
	if data and data.purchases[gamepassKey] then
		cache[gamepassKey] = true
		return true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	local result = ok and owns == true
	cache[gamepassKey] = result
	return result
end

local function grantGamepass(player: Player, key: string)
	local cache = ownershipCache[player]
	if cache then
		cache[key] = true
	end
	DataService.Update(player, function(data)
		data.purchases[key] = true
	end)
	if player.Character then
		applyPassiveEffects(player, player.Character)
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = productKeyForId(receipt.ProductId)
	local handler = key and productHandlers[key]
	if not key or not handler then
		warn(`[Monetization] no handler for product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ledgerKey = tostring(receipt.PurchaseId)
	if ledger then
		local ok, already = pcall(function()
			return (ledger :: DataStore):GetAsync(ledgerKey)
		end)
		if ok and already then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local granted = false
	local ok, err = pcall(function()
		granted = handler(player)
	end)
	if not ok then
		warn(`[Monetization] handler {key} errored: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if ledger then
		pcall(function()
			(ledger :: DataStore):SetAsync(ledgerKey, true)
		end)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onPurchaseRequest(player: Player, kind: unknown, key: unknown)
	if type(kind) ~= "string" or type(key) ~= "string" then
		return
	end
	if kind == "gamepass" then
		local id = GameConfig.Monetization.Gamepasses[key]
		if id and id ~= 0 then
			pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, id)
		end
	elseif kind == "product" then
		local id = GameConfig.Monetization.Products[key]
		if id and id ~= 0 then
			pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, id)
		end
	end
end

function MonetizationService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(LEDGER_STORE)
	end)
	if ok then
		ledger = result
	end
	Players.PlayerRemoving:Connect(function(player)
		ownershipCache[player] = nil
	end)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = gamepassKeyForId(passId)
		if purchased and key then
			grantGamepass(player, key)
		end
	end)
	Remotes.event(Remotes.Names.PurchaseRequest).OnServerEvent:Connect(onPurchaseRequest)
	Remotes.event(Remotes.Names.RequestSkipStage).OnServerEvent:Connect(function(player)
		onPurchaseRequest(player, "product", "SkipStage")
	end)
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(applyPassiveEffects, player, character)
		end)
		if player.Character then
			applyPassiveEffects(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
end

return MonetizationService
