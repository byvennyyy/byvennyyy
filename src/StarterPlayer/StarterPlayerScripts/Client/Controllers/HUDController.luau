--!strict
--[[
	HUDController
	Owns the always-on HUD: biome card (name, tier badge, biome number), stage card (global stage and
	stage-in-biome), deaths and biome timer, the bottom-right buttons (Egg Dex, Settings, Shop), the
	shop panel, toasts, and the big CAUGHT / TAMED flashes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local HUDController = {}

type Hud = {
	biomeName: TextLabel,
	tierBadge: TextLabel,
	biomeNumber: TextLabel,
	stageLabel: TextLabel,
	stageInBiome: TextLabel,
	deaths: TextLabel,
	timer: TextLabel,
	toasts: Frame,
	flash: TextLabel,
}
local hud: Hud? = nil
local biomeStartedAt = 0
local timerRunning = false

local SHOP_ITEMS = {
	{
		kind = "product",
		key = "SkipStage",
		title = "Skip Stage",
		blurb = "Teleport to the next checkpoint. The animal moves with you.",
	},
	{ kind = "product", key = "SkipBiome", title = "Skip Biome", blurb = "Jump straight to the next egg." },
	{ kind = "product", key = "ReviveHere", title = "Revive Here", blurb = "Come back where you fell, 3 s of safety." },
	{ kind = "gamepass", key = "SpeedCoil", title = "Speed Coil", blurb = "Walk 50% faster, forever." },
	{ kind = "gamepass", key = "GravityCoil", title = "Gravity Coil", blurb = "Higher jumps, forever." },
	{
		kind = "gamepass",
		key = "DoubleHeadStart",
		title = "Double Head Start",
		blurb = "Every egg gives you twice the time.",
	},
	{ kind = "gamepass", key = "VIP", title = "VIP", blurb = "Chat tag, trail and daily skips." },
	{ kind = "gamepass", key = "PetFollow", title = "Pet Follow", blurb = "Your tamed animals follow you as pets." },
}

local function card(name: string, position: UDim2, anchor: Vector2): Frame
	local frame = UI.make("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(230, 74),
		BackgroundColor3 = Color3.fromRGB(18, 20, 26),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = UI.screen(),
	}) :: Frame
	UI.corner(12).Parent = frame
	return frame
end

local function build(): Hud
	local screen = UI.screen()
	local biomeCard = card("BiomeCard", UDim2.fromOffset(12, 44), Vector2.new(0, 0))
	local biomeName = UI.text({
		Name = "Name",
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = biomeCard,
	})
	local tierBadge = UI.text({
		Name = "Tier",
		Size = UDim2.fromOffset(110, 24),
		Position = UDim2.fromOffset(8, 40),
		Text = "",
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(80, 80, 80),
		ZIndex = 5,
		Parent = biomeCard,
	})
	UI.corner(8).Parent = tierBadge
	local biomeNumber = UI.text({
		Name = "Number",
		Size = UDim2.fromOffset(96, 24),
		Position = UDim2.fromOffset(126, 40),
		Text = "",
		Font = UI.BodyFont,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
		Parent = biomeCard,
	})

	local stageCard = card("StageCard", UDim2.new(1, -12, 0, 44), Vector2.new(1, 0))
	local stageLabel = UI.text({
		Name = "Stage",
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
		Parent = stageCard,
	})
	local stageInBiome = UI.text({
		Name = "StageInBiome",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 42),
		Text = "",
		Font = UI.BodyFont,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
		Parent = stageCard,
	})

	local statsCard = card("StatsCard", UDim2.new(0, 12, 1, -12), Vector2.new(0, 1))
	statsCard.Size = UDim2.fromOffset(200, 60)
	local deaths = UI.text({
		Name = "Deaths",
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		Text = "💀 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = statsCard,
	})
	local timer = UI.text({
		Name = "Timer",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 32),
		Text = "⏱ 0:00",
		Font = UI.BodyFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = statsCard,
	})

	local buttons = UI.make("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(330, 48),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = screen,
	}) :: Frame
	UI.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttons,
	})
	local eggDex = UI.button({
		Name = "EggDex",
		Size = UDim2.fromOffset(104, 48),
		Text = "🥚 Egg Dex",
		LayoutOrder = 1,
		ZIndex = 5,
		Parent = buttons,
	})
	local shop = UI.button({
		Name = "Shop",
		Size = UDim2.fromOffset(104, 48),
		Text = "🛒 Shop",
		BackgroundColor3 = Color3.fromRGB(46, 125, 80),
		LayoutOrder = 2,
		ZIndex = 5,
		Parent = buttons,
	})
	local settings = UI.button({
		Name = "Settings",
		Size = UDim2.fromOffset(104, 48),
		Text = "⚙ Settings",
		LayoutOrder = 3,
		ZIndex = 5,
		Parent = buttons,
	})
	eggDex.Activated:Connect(function()
		Sfx.play("click", 0.6)
		ClientState.ToggleEggDex:Fire()
	end)
	settings.Activated:Connect(function()
		Sfx.play("click", 0.6)
		ClientState.ToggleSettings:Fire()
	end)
	shop.Activated:Connect(function()
		Sfx.play("click", 0.6)
		UI.togglePanel("Shop")
	end)

	local toasts = UI.make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(420, 160),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = screen,
	}) :: Frame
	UI.make("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toasts,
	})
	local flash = UI.text({
		Name = "Flash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.7, 0, 0.16, 0),
		Text = "",
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})

	-- shop panel
	local _, content = UI.panel("Shop", "Shop")
	local list = UI.make("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, #SHOP_ITEMS * 66),
		ZIndex = 22,
		Parent = content,
	}) :: ScrollingFrame
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for order, item in ipairs(SHOP_ITEMS) do
		local id = if item.kind == "gamepass"
			then GameConfig.Monetization.Gamepasses[item.key]
			else GameConfig.Monetization.Products[item.key]
		local row = UI.make("Frame", {
			Name = item.key,
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundColor3 = Color3.fromRGB(34, 39, 50),
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 22,
			Parent = list,
		}) :: Frame
		UI.corner(10).Parent = row
		UI.text({
			Size = UDim2.new(1, -150, 0, 28),
			Position = UDim2.fromOffset(12, 4),
			Text = item.title,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = row,
		})
		UI.text({
			Size = UDim2.new(1, -150, 0, 22),
			Position = UDim2.fromOffset(12, 32),
			Text = item.blurb,
			Font = UI.BodyFont,
			TextColor3 = Color3.fromRGB(190, 195, 205),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = row,
		})
		local buy = UI.button({
			Size = UDim2.fromOffset(120, 40),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Text = if id == 0 then "Soon" else "Buy",
			BackgroundColor3 = if id == 0 then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(46, 125, 80),
			ZIndex = 23,
			Parent = row,
		})
		buy.Activated:Connect(function()
			if id == 0 then
				HUDController.Toast("Not available yet", Color3.fromRGB(230, 200, 90))
				return
			end
			Remotes.event(Remotes.Names.PurchaseRequest):FireServer(item.kind, item.key)
		end)
	end

	return {
		biomeName = biomeName,
		tierBadge = tierBadge,
		biomeNumber = biomeNumber,
		stageLabel = stageLabel,
		stageInBiome = stageInBiome,
		deaths = deaths,
		timer = timer,
		toasts = toasts,
		flash = flash,
	}
end

function HUDController.Toast(text: string, color: Color3?)
	local h = hud
	if not h then
		return
	end
	local label = UI.text({
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		ZIndex = 9,
		Parent = h.toasts,
	})
	task.delay(2.2, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.55, function()
			label:Destroy()
		end)
	end)
end

local function flashText(text: string, color: Color3)
	local h = hud
	if not h then
		return
	end
	h.flash.Text = text
	h.flash.TextColor3 = color
	h.flash.TextTransparency = 0
	h.flash.TextStrokeTransparency = 0.3
	h.flash.Visible = true
	local scaler = Instance.new("UIScale")
	scaler.Scale = 1.5
	scaler.Parent = h.flash
	TweenService:Create(scaler, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(1.4, function()
		TweenService:Create(h.flash, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.5, function()
			h.flash.Visible = false
			scaler:Destroy()
		end)
	end)
end

local function refreshBiome(_info: Types.ClientBiomeInfo, def: Types.BiomeDef)
	local h = hud
	if not h then
		return
	end
	h.biomeName.Text = def.name
	h.tierBadge.Text = def.tier
	h.tierBadge.BackgroundColor3 = def.tierColor
	local _, _, v = def.tierColor:ToHSV()
	h.tierBadge.TextColor3 = if v > 0.7 then Color3.fromRGB(20, 20, 20) else Color3.new(1, 1, 1)
	h.biomeNumber.Text = `Biome {def.index} / {GameConfig.BiomeCount}`
end

local function refreshStage()
	local h = hud
	if not h then
		return
	end
	local stage = math.min(ClientState.stage, GameConfig.TotalStages)
	h.stageLabel.Text = if ClientState.stage > GameConfig.TotalStages
		then "FINISHED!"
		else `Stage {stage} / {GameConfig.TotalStages}`
	local def = ClientState.biomeDef
	h.stageInBiome.Text = if def then `{ClientState.stageInBiome} / {GameConfig.StagesPerBiome} in {def.name}` else ""
end

local function refreshDeaths()
	local h = hud
	if h and ClientState.data then
		h.deaths.Text = `💀 {ClientState.data.deaths}`
	end
end

function HUDController.Init()
	hud = build()
end

function HUDController.Start()
	ClientState.BiomeChanged:Connect(function(info, def)
		refreshBiome(info, def)
		refreshStage()
	end)
	ClientState.StageChanged:Connect(function()
		refreshStage()
		Sfx.play("checkpoint", 0.7)
		HUDController.Toast("Checkpoint!", Color3.fromRGB(120, 240, 150))
	end)
	ClientState.DataLoaded:Connect(function()
		refreshDeaths()
		refreshStage()
	end)
	ClientState.BiomeEntered:Connect(function()
		biomeStartedAt = os.clock()
		timerRunning = true
	end)
	ClientState.ChaserEvent:Connect(function(kind, _biome, extra)
		if kind == "Caught" then
			Sfx.play("caught", 1)
			flashText("CAUGHT!", Color3.fromRGB(255, 70, 70))
			if ClientState.data then
				ClientState.data.deaths += 1
			end
			refreshDeaths()
		elseif kind == "Defeated" then
			timerRunning = false
			Sfx.play("tamed", 1)
			local animal = if type(extra) == "table" and type(extra.animal) == "string"
				then extra.animal
				else "the animal"
			flashText(`TAMED {string.upper(animal)}!`, Color3.fromRGB(255, 210, 80))
		end
	end)
	RunService.Heartbeat:Connect(function()
		local h = hud
		if h and timerRunning then
			local elapsed = os.clock() - biomeStartedAt
			h.timer.Text = string.format("⏱ %d:%02d", math.floor(elapsed / 60), math.floor(elapsed % 60))
		end
	end)
	if ClientState.biome and ClientState.biomeDef then
		refreshBiome(ClientState.biome, ClientState.biomeDef)
	end
	refreshStage()
	refreshDeaths()
end

return HUDController
