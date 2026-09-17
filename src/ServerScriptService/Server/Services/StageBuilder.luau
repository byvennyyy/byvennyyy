--!strict
--[[
	StageBuilder
	Owns greybox generation of a whole biome: Biome_XX folder on the world grid, EggPedestal, ten
	Stage_YY folders each starting with a Checkpoint, obstacle chunks chosen from the mechanics unlocked
	at that biome (the biome's own new mechanic appears at least twice per stage), turns that keep the
	route inside the biome's grid cell, a Finish part after biome 20, and a Path folder of WP_nnnn
	waypoints. Level designers replace generated stages with hand-built ones by keeping the same names.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Difficulty = require(Shared.Config.Difficulty)
local Types = require(Shared.Types)
local Chunks = require(script.Parent.Chunks)
local Movers = require(script.Parent.Movers)

type BiomeDef = Types.BiomeDef
type ChunkContext = Chunks.ChunkContext

local CELL_MARGIN = 220
local PEDESTAL_LEAD = 24
local TURN_KEY = Difficulty.TurnKey

local StageBuilder = {}

local function cellCenter(index: number): Vector3
	local grid = GameConfig.Grid
	local col = (index - 1) % grid.columns
	local row = (index - 1) // grid.columns
	return Vector3.new(col * grid.cellSize, row * grid.altitudeStep + (index - 1) * 12, row * grid.cellSize)
end

local function makeCheckpoint(def: BiomeDef, stageFolder: Folder, cursor: CFrame, globalStage: number): Part
	local pad = Instance.new("Part")
	pad.Name = "Checkpoint"
	pad.Size = Vector3.new(7, 1, 7)
	pad.CFrame = cursor * CFrame.new(0, -0.5, 0)
	pad.Anchored = true
	pad.Color = def.tierColor
	pad.Material = Enum.Material.Neon
	pad:SetAttribute("Stage", globalStage)
	local pole = Instance.new("Part")
	pole.Name = "FlagPole"
	pole.Size = Vector3.new(0.4, 7, 0.4)
	pole.CFrame = cursor * CFrame.new(3, 3.5, -3)
	pole.Anchored = true
	pole.CanCollide = false
	pole.Color = Color3.fromRGB(230, 230, 230)
	pole.Parent = stageFolder
	local flag = Instance.new("Part")
	flag.Name = "Flag"
	flag.Size = Vector3.new(2.4, 1.4, 0.2)
	flag.CFrame = cursor * CFrame.new(1.8, 6.2, -3)
	flag.Anchored = true
	flag.CanCollide = false
	flag.Color = def.tierColor
	flag.Parent = stageFolder
	local gui = Instance.new("BillboardGui")
	gui.Name = "StageLabel"
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(globalStage)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = pad
	pad.Parent = stageFolder
	return pad
end

local function makePedestal(def: BiomeDef, biomeFolder: Folder, cursor: CFrame): Part
	local base = Instance.new("Part")
	base.Name = "EggPedestalBase"
	base.Size = Vector3.new(12, 2, 12)
	base.CFrame = cursor * CFrame.new(0, -1, 0)
	base.Anchored = true
	base.Color = def.palette.ground
	base.Material = Enum.Material.Slate
	base.Parent = biomeFolder
	local pedestal = Instance.new("Part")
	pedestal.Name = "EggPedestal"
	pedestal.Size = Vector3.new(4, 1.5, 4)
	pedestal.CFrame = cursor * CFrame.new(0, 0.75, -3)
	pedestal.Anchored = true
	pedestal.Color = def.palette.accent
	pedestal.Material = Enum.Material.Marble
	pedestal.Parent = biomeFolder
	return pedestal
end

local function makeFinish(def: BiomeDef, biomeFolder: Folder, cursor: CFrame): Part
	local plate = Instance.new("Part")
	plate.Name = "FinishPlatform"
	plate.Size = Vector3.new(16, 1, 16)
	plate.CFrame = cursor * CFrame.new(0, -0.5, -8)
	plate.Anchored = true
	plate.Color = Color3.fromRGB(255, 200, 40)
	plate.Material = Enum.Material.Neon
	plate.Parent = biomeFolder
	local finish = Instance.new("Part")
	finish.Name = "Finish"
	finish.Size = Vector3.new(12, 8, 1)
	finish.CFrame = cursor * CFrame.new(0, 4, -12)
	finish.Anchored = true
	finish.CanCollide = false
	finish.Transparency = 0.5
	finish.Color = Color3.fromRGB(255, 230, 120)
	finish.Material = Enum.Material.ForceField
	finish:SetAttribute("Stage", GameConfig.TotalStages + 1)
	finish.Parent = biomeFolder
	return finish
end

local function makePathFolder(biomeFolder: Folder, waypoints: { Vector3 })
	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "Path"
	for i, position in ipairs(waypoints) do
		local wp = Instance.new("Part")
		wp.Name = string.format("WP_%04d", i)
		wp.Size = Vector3.new(1, 1, 1)
		wp.CFrame = CFrame.new(position)
		wp.Anchored = true
		wp.CanCollide = false
		wp.CanQuery = false
		wp.CanTouch = false
		wp.Transparency = 1
		wp.Parent = pathFolder
	end
	pathFolder.Parent = biomeFolder
end

local function outsideCell(position: Vector3, center: Vector3): boolean
	local half = GameConfig.Grid.cellSize / 2 - CELL_MARGIN
	return math.abs(position.X - center.X) > half or math.abs(position.Z - center.Z) > half
end

-- +1 (left) or -1 (right): whichever 90-degree turn points the cursor more toward the cell centre.
local function turnToward(cursor: CFrame, center: Vector3): number
	local toCenter = (Vector3.new(center.X, cursor.Position.Y, center.Z) - cursor.Position).Unit
	local left = (cursor * CFrame.Angles(0, math.rad(90), 0)).LookVector
	local right = (cursor * CFrame.Angles(0, math.rad(-90), 0)).LookVector
	return if left:Dot(toCenter) >= right:Dot(toCenter) then 1 else -1
end

local function pickSequence(def: BiomeDef, rng: Random, count: number): { string }
	local allowed = Difficulty.MechanicsFor(def.index)
	local pool: { string } = {}
	for _, key in allowed do
		if key ~= TURN_KEY and Chunks[key] then
			table.insert(pool, key)
		end
	end
	local sequence: { string } = table.create(count)
	for i = 1, count do
		sequence[i] = pool[rng:NextInteger(1, #pool)]
	end
	-- the biome's own mechanic at least twice per stage
	local own = def.mechanic
	local present = 0
	for _, key in sequence do
		if key == own then
			present += 1
		end
	end
	while present < 2 and Chunks[own] do
		local slot = rng:NextInteger(1, count)
		if sequence[slot] ~= own then
			sequence[slot] = own
			present += 1
		end
	end
	-- a turn every 4-6 chunks keeps the biome snaking inside its cell
	local out: { string } = {}
	local untilTurn = rng:NextInteger(4, 6)
	for _, key in sequence do
		table.insert(out, key)
		untilTurn -= 1
		if untilTurn <= 0 then
			table.insert(out, TURN_KEY)
			untilTurn = rng:NextInteger(4, 6)
		end
	end
	return out
end

-- Three platforms stepping down, used when a stage has climbed too high above the biome floor.
local function descend(ctx: ChunkContext): CFrame
	local cursor = ctx.cframe
	for _ = 1, 3 do
		local size = math.max(5, ctx.difficulty.platformMin)
		cursor = cursor * CFrame.new(0, -5, -(size / 2 + 3))
		local part = Instance.new("Part")
		part.Name = "Step"
		part.Size = Vector3.new(size, 1, size)
		part.CFrame = cursor * CFrame.new(0, -0.5, 0)
		part.Anchored = true
		part.Color = ctx.palette.primary
		part.Parent = ctx.folder
		table.insert(ctx.waypoints, cursor.Position + Vector3.new(0, 3, 0))
		cursor = cursor * CFrame.new(0, 0, -size / 2)
	end
	return cursor
end

function StageBuilder.BuildBiome(def: BiomeDef, parent: Folder): Folder
	local started = os.clock()
	local center = cellCenter(def.index)
	local half = GameConfig.Grid.cellSize / 2
	local biomeFolder = Instance.new("Folder")
	biomeFolder.Name = string.format("Biome_%02d", def.index)
	local difficulty = Difficulty.Get(def.index)
	local waypoints: { Vector3 } = {}
	local cursor = CFrame.new(center.X - half + CELL_MARGIN, center.Y, center.Z + half - CELL_MARGIN)
	local pedestal = makePedestal(def, biomeFolder, cursor)
	table.insert(waypoints, pedestal.Position + Vector3.new(0, 3, 0))
	cursor = cursor * CFrame.new(0, 0, -PEDESTAL_LEAD)
	for stage = 1, GameConfig.StagesPerBiome do
		local globalStage = (def.index - 1) * GameConfig.StagesPerBiome + stage
		local stageFolder = Instance.new("Folder")
		stageFolder.Name = string.format("Stage_%02d", stage)
		local rng = Random.new(def.index * 1000 + stage)
		makeCheckpoint(def, stageFolder, cursor, globalStage)
		table.insert(waypoints, cursor.Position + Vector3.new(0, 3, 0))
		cursor = cursor * CFrame.new(0, 0, -4)
		local ctx: ChunkContext = {
			cframe = cursor,
			rng = rng,
			difficulty = difficulty,
			folder = stageFolder,
			waypoints = waypoints,
			palette = def.palette,
			biomeIndex = def.index,
			forcedTurn = nil,
		}
		for _, key in pickSequence(def, rng, difficulty.chunksPerStage) do
			ctx.cframe = cursor
			if ctx.cframe.Position.Y > center.Y + 70 then
				cursor = descend(ctx)
				ctx.cframe = cursor
			end
			cursor = Chunks[key](ctx)
			if outsideCell(cursor.Position, center) then
				ctx.cframe = cursor
				ctx.forcedTurn = turnToward(cursor, center)
				cursor = Chunks[TURN_KEY](ctx)
			end
		end
		-- breathing room before the next checkpoint
		cursor = cursor * CFrame.new(0, 0, -4)
		stageFolder.Parent = biomeFolder
	end
	if def.index == GameConfig.BiomeCount then
		local finish = makeFinish(def, biomeFolder, cursor)
		table.insert(waypoints, finish.Position)
	else
		-- the next biome's first checkpoint is far away on the grid; end this path at a landing pad
		local landing = Instance.new("Part")
		landing.Name = "BiomeExit"
		landing.Size = Vector3.new(10, 1, 10)
		landing.CFrame = cursor * CFrame.new(0, -0.5, -5)
		landing.Anchored = true
		landing.Color = def.tierColor
		landing.Material = Enum.Material.Neon
		landing:SetAttribute("Stage", def.index * GameConfig.StagesPerBiome + 1)
		landing.Parent = biomeFolder
		table.insert(waypoints, landing.Position + Vector3.new(0, 3, 0))
	end
	makePathFolder(biomeFolder, waypoints)
	biomeFolder.Parent = parent
	print(
		string.format(
			"[StageBuilder] built %s (%d waypoints) in %.0f ms",
			biomeFolder.Name,
			#waypoints,
			(os.clock() - started) * 1000
		)
	)
	return biomeFolder
end

--- Installs the lethal Touched handler on every KillBrick, now and as new ones appear.
function StageBuilder.InstallKillBricks()
	local function install(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		instance.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not character:GetAttribute("Invulnerable") then
				humanoid.Health = 0
			end
		end)
	end
	for _, part in CollectionService:GetTagged("KillBrick") do
		install(part)
	end
	CollectionService:GetInstanceAddedSignal("KillBrick"):Connect(install)
	Movers.Start()
end

return StageBuilder
