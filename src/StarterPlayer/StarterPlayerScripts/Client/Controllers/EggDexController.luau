--!strict
--[[
	EggDexController
	Owns the Egg Dex panel: a 4 x 5 grid of the 20 biomes showing each egg (tinted with the biome
	palette), the animal name, and its state (unhatched / hatched / tamed / equipped). Tamed animals
	can be equipped as the follower pet, which is persisted through the settings remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local EggDexController = {}

local panel: Frame? = nil
local grid: Frame? = nil
local progress: TextLabel? = nil

local function cellState(index: number): (string, Color3)
	local data = ClientState.data
	local def = Biomes[index]
	if not data then
		return "?", Color3.fromRGB(90, 90, 100)
	end
	if data.equippedPet == def.animal then
		return "EQUIPPED", Color3.fromRGB(120, 220, 255)
	elseif data.tamed[def.animal] then
		return "TAMED", Color3.fromRGB(255, 205, 70)
	elseif data.eggsHatched[tostring(index)] then
		return "HATCHED", Color3.fromRGB(160, 230, 160)
	end
	return "???", Color3.fromRGB(90, 90, 100)
end

local function refresh()
	local g = grid
	if not g then
		return
	end
	for _, child in g:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local hatched, tamed = 0, 0
	local data = ClientState.data
	for index, def in ipairs(Biomes) do
		local state, color = cellState(index)
		if data and data.eggsHatched[tostring(index)] then
			hatched += 1
		end
		if data and data.tamed[def.animal] then
			tamed += 1
		end
		local known = state ~= "???"
		local cell = UI.make("Frame", {
			Name = `Cell{index}`,
			BackgroundColor3 = Color3.fromRGB(34, 39, 50),
			BorderSizePixel = 0,
			LayoutOrder = index,
			ZIndex = 22,
			Parent = g,
		}) :: Frame
		UI.corner(10).Parent = cell
		UI.stroke(color, if state == "TAMED" or state == "EQUIPPED" then 3 else 1).Parent = cell
		local egg = UI.make("Frame", {
			Name = "Egg",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.new(0.34, 0, 0.42, 0),
			BackgroundColor3 = if known then def.palette.secondary else Color3.fromRGB(60, 60, 70),
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = cell,
		}) :: Frame
		UI.corner(999).Parent = egg
		UI.make("UIAspectRatioConstraint", { AspectRatio = 0.78, Parent = egg })
		UI.text({
			Name = "Name",
			Size = UDim2.new(1, -8, 0.18, 0),
			Position = UDim2.new(0, 4, 0.5, 0),
			Text = if known then def.animal else `Biome {index}`,
			ZIndex = 23,
			Parent = cell,
		})
		UI.text({
			Name = "State",
			Size = UDim2.new(1, -8, 0.14, 0),
			Position = UDim2.new(0, 4, 0.69, 0),
			Text = state,
			Font = UI.BodyFont,
			TextColor3 = color,
			ZIndex = 23,
			Parent = cell,
		})
		if state == "TAMED" or state == "EQUIPPED" then
			local button = UI.button({
				Name = "Equip",
				Size = UDim2.new(0.8, 0, 0.14, 0),
				Position = UDim2.new(0.1, 0, 0.84, 0),
				Text = if state == "EQUIPPED" then "Unequip" else "Equip",
				BackgroundColor3 = if state == "EQUIPPED"
					then Color3.fromRGB(90, 90, 110)
					else Color3.fromRGB(46, 125, 80),
				ZIndex = 23,
				Parent = cell,
			})
			button.Activated:Connect(function()
				local d = ClientState.data
				if not d then
					return
				end
				Sfx.play("click", 0.6)
				local equip = d.equippedPet ~= def.animal
				d.equippedPet = if equip then def.animal else nil
				Remotes.event(Remotes.Names.SettingsChanged)
					:FireServer({ equippedPet = if equip then def.animal else "" })
				refresh()
			end)
		end
	end
	if progress then
		progress.Text = `{hatched} / {GameConfig.BiomeCount} hatched, {tamed} tamed`
	end
end

function EggDexController.Init()
	local p, content = UI.panel("EggDex", "Egg Dex")
	panel = p
	progress = UI.text({
		Name = "Progress",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		Font = UI.BodyFont,
		ZIndex = 22,
		Parent = content,
	})
	local g = UI.make("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -30),
		Position = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = content,
	}) :: Frame
	UI.make("UIGridLayout", {
		CellSize = UDim2.new(0.2, -6, 0.25, -6),
		CellPadding = UDim2.fromOffset(6, 6),
		FillDirectionMaxCells = 5,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = g,
	})
	grid = g
end

function EggDexController.Toggle()
	if UI.togglePanel("EggDex") then
		refresh()
	end
end

function EggDexController.Start()
	ClientState.ToggleEggDex.Event:Connect(EggDexController.Toggle)
	ClientState.DataLoaded:Connect(refresh)
	ClientState.BiomeEntered:Connect(function()
		if panel and panel.Visible then
			refresh()
		end
	end)
	ClientState.ChaserEvent:Connect(function(kind)
		if kind == "Defeated" and panel and panel.Visible then
			refresh()
		end
	end)
end

return EggDexController
