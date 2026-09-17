--!strict
--[[
	Chunks
	Owns the greybox obstacle builders used by StageBuilder. Every chunk is a pure builder:
	`Chunks[key](ctx) -> nextCursor`. The cursor is a CFrame whose position is the floor level at the
	end of the previous chunk and whose LookVector is the direction of travel. Chunks create Anchored
	parts under ctx.folder, append walkable waypoints (3 studs above every safe platform) to
	ctx.waypoints, tag lethal parts "KillBrick", and register any animated parts with the Movers driver.
	Sizes, gaps, speeds and timings come from ctx.difficulty so the same chunk gets harder per biome.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Movers = require(script.Parent.Movers)

export type ChunkContext = {
	cframe: CFrame,
	rng: Random,
	difficulty: Types.DifficultyDef,
	folder: Folder,
	waypoints: { Vector3 },
	palette: Types.Palette,
	biomeIndex: number,
	forcedTurn: number?, -- +1 left / -1 right; set by StageBuilder to steer back inside the cell
}

type Chunk = (ChunkContext) -> CFrame

local KILL_TAG = "KillBrick"
local WAYPOINT_HEIGHT = 3
local PLATFORM_THICKNESS = 1
local KILL_COLOR = Color3.fromRGB(255, 40, 40)

local Chunks: { [string]: Chunk } = {}

-- ---------------------------------------------------------------- helpers

local function makePart(
	ctx: ChunkContext,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color or ctx.palette.primary
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = ctx.folder
	return part
end

local function markKill(part: BasePart)
	part.Color = KILL_COLOR
	part.Material = Enum.Material.Neon
	CollectionService:AddTag(part, KILL_TAG)
end

local function addWaypoint(ctx: ChunkContext, position: Vector3)
	table.insert(ctx.waypoints, position + Vector3.new(0, WAYPOINT_HEIGHT, 0))
end

-- Move the cursor `forward` studs along its look direction and `up` studs vertically.
local function advance(cursor: CFrame, forward: number, up: number?): CFrame
	return cursor * CFrame.new(0, up or 0, -forward)
end

-- A platform whose top surface centre is at `top`; returns the part.
local function platform(
	ctx: ChunkContext,
	top: CFrame,
	width: number,
	depth: number,
	color: Color3?,
	material: Enum.Material?
): Part
	local part = makePart(
		ctx,
		"Platform",
		Vector3.new(width, PLATFORM_THICKNESS, depth),
		top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
		color,
		material
	)
	addWaypoint(ctx, top.Position)
	return part
end

local function platformSize(ctx: ChunkContext): number
	local d = ctx.difficulty
	return ctx.rng:NextNumber(d.platformMin, d.platformMax)
end

local function gapSize(ctx: ChunkContext): number
	local d = ctx.difficulty
	return ctx.rng:NextNumber(d.gapMin, d.gapMax)
end

local function drift(ctx: ChunkContext): number
	local v = ctx.difficulty.heightVariance
	return ctx.rng:NextNumber(-v * 0.5, v * 0.5)
end

local function killTouch(part: BasePart, onTouch: (Model, Humanoid) -> ())
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			onTouch(character :: Model, humanoid)
		end
	end)
end

-- Pushes the character that touched `part` with a short-lived LinearVelocity (works for client-owned
-- characters because constraints replicate and are simulated by the owner).
local function impulse(character: Model, velocity: Vector3, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if root:FindFirstChild("ChunkImpulse") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ChunkImpulseAttachment"
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ChunkImpulse"
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.Parent = root
	task.delay(seconds, function()
		lv:Destroy()
		attachment:Destroy()
	end)
end

-- ---------------------------------------------------------------- basic chunks

Chunks.platformRun = function(ctx)
	local cursor = ctx.cframe
	local count = ctx.rng:NextInteger(3, 5)
	for _ = 1, count do
		local size = platformSize(ctx)
		cursor = advance(cursor, size / 2)
		platform(ctx, cursor, size, size)
		cursor = advance(cursor, size / 2 + ctx.difficulty.gapMin * 0.6, drift(ctx) * 0.5)
	end
	return cursor
end

Chunks.gapJump = function(ctx)
	local cursor = ctx.cframe
	local jumps = ctx.rng:NextInteger(2, 3)
	for _ = 1, jumps do
		local size = platformSize(ctx)
		cursor = advance(cursor, size / 2)
		platform(ctx, cursor, size, size)
		cursor = advance(cursor, size / 2 + gapSize(ctx), drift(ctx))
	end
	local size = platformSize(ctx)
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	return advance(cursor, size / 2)
end

Chunks.killLane = function(ctx)
	-- 3 columns x N rows of tiles; exactly one safe column per row, moving at most one column per row.
	local cursor = ctx.cframe
	local rows = ctx.rng:NextInteger(4, 7)
	local tile = math.max(4, ctx.difficulty.platformMin * 0.6)
	local safe = ctx.rng:NextInteger(1, 3)
	for _ = 1, rows do
		cursor = advance(cursor, tile / 2)
		for col = 1, 3 do
			local offset = (col - 2) * tile
			local top = cursor * CFrame.new(offset, 0, 0)
			local part = makePart(
				ctx,
				"Tile",
				Vector3.new(tile, PLATFORM_THICKNESS, tile),
				top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0)
			)
			if col == safe then
				addWaypoint(ctx, top.Position)
			elseif ctx.rng:NextNumber() < 0.35 + ctx.difficulty.killDensity then
				markKill(part)
			end
		end
		cursor = advance(cursor, tile / 2)
		safe = math.clamp(safe + ctx.rng:NextInteger(-1, 1), 1, 3)
	end
	return cursor
end

Chunks.movingPlatform = function(ctx)
	local cursor = ctx.cframe
	local size = platformSize(ctx)
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	local startEdge = advance(cursor, size / 2)
	local travel = gapSize(ctx) * 2 + size
	local moverSize = math.max(4, size * 0.7)
	local from = advance(startEdge, moverSize / 2 + 1)
	local to = advance(startEdge, travel - moverSize / 2 - 1)
	local mover = makePart(
		ctx,
		"Mover",
		Vector3.new(moverSize, PLATFORM_THICKNESS, moverSize),
		from * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
		ctx.palette.accent
	)
	addWaypoint(ctx, from.Position)
	addWaypoint(ctx, to.Position)
	local seconds = math.max(1, (travel - moverSize) / ctx.difficulty.moverSpeed)
	local tween = TweenService:Create(
		mover,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = to * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0) }
	)
	tween:Play()
	local landing = advance(startEdge, travel + size / 2)
	platform(ctx, landing, size, size)
	return advance(landing, size / 2)
end

Chunks.spinner = function(ctx)
	local cursor = ctx.cframe
	local radius = math.max(8, platformSize(ctx) * 1.2)
	local center = advance(cursor, radius)
	local disc = makePart(
		ctx,
		"SpinnerDisc",
		Vector3.new(PLATFORM_THICKNESS, radius * 2, radius * 2),
		center * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0)
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = disc.CFrame * CFrame.Angles(0, 0, math.rad(90))
	local post = makePart(ctx, "SpinnerPost", Vector3.new(2, 6, 2), center * CFrame.new(0, 3, 0), ctx.palette.secondary)
	post.Name = "SpinnerPost"
	local bar = makePart(ctx, "SpinnerBar", Vector3.new(radius * 2 - 1, 1.5, 1.5), center * CFrame.new(0, 1.5, 0))
	markKill(bar)
	local speed = math.rad(40 + ctx.difficulty.moverSpeed * 4)
	Movers.rotate(bar, center * CFrame.new(0, 1.5, 0), speed, ctx.rng:NextNumber(0, math.pi * 2))
	addWaypoint(ctx, advance(cursor, 2).Position)
	addWaypoint(ctx, center.Position)
	addWaypoint(ctx, advance(center, radius - 2).Position)
	return advance(center, radius)
end

Chunks.conveyor = function(ctx)
	local cursor = ctx.cframe
	local length = ctx.rng:NextNumber(24, 40)
	local width = math.max(5, platformSize(ctx) * 0.8)
	local top = advance(cursor, length / 2)
	local belt = makePart(
		ctx,
		"Conveyor",
		Vector3.new(width, PLATFORM_THICKNESS, length),
		top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
		ctx.palette.secondary,
		Enum.Material.DiamondPlate
	)
	local backwards = ctx.rng:NextNumber() < 0.4
	local speed = ctx.difficulty.moverSpeed * (if backwards then -0.8 else 1)
	belt.AssemblyLinearVelocity = cursor.LookVector * speed
	addWaypoint(ctx, advance(cursor, 2).Position)
	addWaypoint(ctx, top.Position)
	addWaypoint(ctx, advance(cursor, length - 2).Position)
	if ctx.biomeIndex >= 8 then
		-- side rails become lethal in later biomes
		for _, side in { -1, 1 } do
			local rail =
				makePart(ctx, "Rail", Vector3.new(1, 1, length), top * CFrame.new(side * (width / 2 + 0.5), 0, 0))
			markKill(rail)
		end
	end
	return advance(cursor, length)
end

Chunks.trussClimb = function(ctx)
	local cursor = ctx.cframe
	local height = ctx.rng:NextNumber(12, 18 + ctx.difficulty.heightVariance)
	local width = math.max(6, platformSize(ctx))
	local base = advance(cursor, width / 2)
	platform(ctx, base, width, width)
	local wallCenter = advance(base, width / 2 + 1) * CFrame.new(0, height / 2, 0)
	makePart(ctx, "ClimbWall", Vector3.new(width, height, 2), wallCenter, ctx.palette.ground)
	local truss = Instance.new("TrussPart")
	truss.Name = "Truss"
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = advance(base, width / 2 - 1) * CFrame.new(0, height / 2, 0)
	truss.Anchored = true
	truss.Color = ctx.palette.accent
	truss.Parent = ctx.folder
	addWaypoint(ctx, truss.CFrame.Position - Vector3.new(0, height / 2 - 1, 0))
	addWaypoint(ctx, truss.CFrame.Position + Vector3.new(0, height / 2 - 1, 0))
	local top = advance(base, width / 2 + 2 + width / 2, height)
	platform(ctx, top, width, width)
	return advance(top, width / 2)
end

Chunks.wallHop = function(ctx)
	local cursor = ctx.cframe
	local steps = ctx.rng:NextInteger(4, 6)
	local ledge = math.max(3, ctx.difficulty.platformMin * 0.5)
	local rise = 5
	for i = 1, steps do
		local side = if i % 2 == 0 then 1 else -1
		cursor = advance(cursor, ledge + 1.5, rise)
		local top = cursor * CFrame.new(side * ledge * 0.9, 0, 0)
		platform(ctx, top, ledge, ledge, ctx.palette.secondary)
	end
	local size = platformSize(ctx)
	cursor = advance(cursor, size / 2 + 2)
	platform(ctx, cursor, size, size)
	return advance(cursor, size / 2)
end

Chunks.icePatch = function(ctx)
	local cursor = ctx.cframe
	local length = ctx.rng:NextNumber(20, 34)
	local width = math.max(5, platformSize(ctx))
	local top = advance(cursor, length / 2)
	local ice = makePart(
		ctx,
		"Ice",
		Vector3.new(width, PLATFORM_THICKNESS, length),
		top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
		Color3.fromRGB(180, 230, 255),
		Enum.Material.Ice
	)
	ice.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.02, 0.2, 100, 1)
	addWaypoint(ctx, advance(cursor, 2).Position)
	addWaypoint(ctx, top.Position)
	addWaypoint(ctx, advance(cursor, length - 2).Position)
	cursor = advance(cursor, length + gapSize(ctx) * 0.8)
	local size = platformSize(ctx)
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	return advance(cursor, size / 2)
end

Chunks.windTunnel = function(ctx)
	local cursor = ctx.cframe
	local length = ctx.rng:NextNumber(24, 36)
	local width = math.max(8, platformSize(ctx) * 1.2)
	local top = advance(cursor, length / 2)
	local floor = makePart(
		ctx,
		"WindFloor",
		Vector3.new(width, PLATFORM_THICKNESS, length),
		top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
		ctx.palette.secondary
	)
	local side = if ctx.rng:NextNumber() < 0.5 then 1 else -1
	floor.AssemblyLinearVelocity = cursor.RightVector * side * ctx.difficulty.moverSpeed * 0.9
	local rail = makePart(ctx, "WindEdge", Vector3.new(1, 1, length), top * CFrame.new(side * (width / 2 + 0.5), 0, 0))
	markKill(rail)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Wind"
	emitter.Rate = 20
	emitter.Lifetime = NumberRange.new(1, 1.5)
	emitter.Speed = NumberRange.new(ctx.difficulty.moverSpeed)
	emitter.EmissionDirection = if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	emitter.Transparency = NumberSequence.new(0.6)
	emitter.Parent = floor
	addWaypoint(ctx, advance(cursor, 2).Position)
	addWaypoint(ctx, top.Position)
	addWaypoint(ctx, advance(cursor, length - 2).Position)
	return advance(cursor, length)
end

Chunks.turn = function(ctx)
	local cursor = ctx.cframe
	local size = math.max(8, platformSize(ctx))
	local center = advance(cursor, size / 2)
	platform(ctx, center, size, size, ctx.palette.accent)
	local direction = ctx.forcedTurn or (if ctx.rng:NextNumber() < 0.5 then 1 else -1)
	ctx.forcedTurn = nil
	-- rotate 90 degrees around Y and step to the edge of the corner platform
	local turned = center * CFrame.Angles(0, direction * math.rad(90), 0)
	return advance(turned, size / 2)
end

-- ---------------------------------------------------------------- advanced chunks

Chunks.darkCorridor = function(ctx)
	local cursor = ctx.cframe
	local length = ctx.rng:NextNumber(30, 44)
	local width = math.max(8, platformSize(ctx) * 1.3)
	local height = 12
	local dark = Color3.fromRGB(12, 12, 16)
	local center = advance(cursor, length / 2)
	local floor = makePart(
		ctx,
		"DarkFloor",
		Vector3.new(width, PLATFORM_THICKNESS, length),
		center * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
		dark
	)
	markKill(floor)
	makePart(ctx, "DarkCeiling", Vector3.new(width, 1, length), center * CFrame.new(0, height, 0), dark)
	for _, side in { -1, 1 } do
		makePart(
			ctx,
			"DarkWall",
			Vector3.new(1, height, length),
			center * CFrame.new(side * (width / 2 + 0.5), height / 2, 0),
			dark
		)
	end
	local step = math.max(3.5, ctx.difficulty.platformMin * 0.55)
	local travelled = 2
	local lateral = 0
	while travelled < length - 2 do
		local top = advance(cursor, travelled + step / 2) * CFrame.new(lateral, 0.6, 0)
		local pad = platform(ctx, top, step, step, ctx.palette.accent, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = step * 1.6
		light.Brightness = 1.5
		light.Color = ctx.palette.accent
		light.Parent = pad
		travelled += step + gapSize(ctx) * 0.6
		lateral = math.clamp(lateral + ctx.rng:NextNumber(-step, step), -(width / 2 - step / 2), width / 2 - step / 2)
	end
	return advance(cursor, length)
end

Chunks.risingLava = function(ctx)
	local cursor = ctx.cframe
	local pillars = ctx.rng:NextInteger(4, 6)
	local size = math.max(4, platformSize(ctx) * 0.7)
	local rise = 5
	local length = pillars * (size + ctx.difficulty.gapMin * 0.8) + 4
	local center = advance(cursor, length / 2)
	local lava = makePart(
		ctx,
		"Lava",
		Vector3.new(size * 3 + 8, 2, length),
		center * CFrame.new(0, -6, 0),
		Color3.fromRGB(255, 90, 20),
		Enum.Material.Neon
	)
	markKill(lava)
	local topHeight = pillars * rise
	local period = math.max(4, topHeight / (ctx.difficulty.moverSpeed * 0.35))
	local tween = TweenService:Create(
		lava,
		TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = lava.CFrame * CFrame.new(0, topHeight - 4, 0) }
	)
	tween:Play()
	for i = 1, pillars do
		cursor = advance(cursor, size / 2 + (if i == 1 then 2 else ctx.difficulty.gapMin * 0.8), rise)
		platform(ctx, cursor, size, size, ctx.palette.secondary)
		cursor = advance(cursor, size / 2)
	end
	return advance(cursor, 2)
end

Chunks.fallingFloor = function(ctx)
	local cursor = ctx.cframe
	local tiles = ctx.rng:NextInteger(5, 8)
	local tile = math.max(4, platformSize(ctx) * 0.6)
	for _ = 1, tiles do
		cursor = advance(cursor, tile / 2)
		local part = platform(ctx, cursor, tile, tile, ctx.palette.secondary)
		local falling = false
		killTouch(part, function()
			if falling then
				return
			end
			falling = true
			task.delay(0.4, function()
				part.CanCollide = false
				part.Transparency = 0.8
			end)
			task.delay(3.4, function()
				part.CanCollide = true
				part.Transparency = 0
				falling = false
			end)
		end)
		cursor = advance(cursor, tile / 2 + 0.5)
	end
	return cursor
end

Chunks.teleportPad = function(ctx)
	local cursor = ctx.cframe
	local size = math.max(6, platformSize(ctx))
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	local padA = makePart(
		ctx,
		"TeleportPad",
		Vector3.new(size * 0.6, 0.4, size * 0.6),
		cursor * CFrame.new(0, 0.2, 0),
		ctx.palette.accent,
		Enum.Material.Neon
	)
	local jump = ctx.rng:NextNumber(30, 50)
	local landing = advance(cursor, size / 2 + jump + size / 2, ctx.rng:NextNumber(-4, 8))
	platform(ctx, landing, size, size)
	local padB = makePart(
		ctx,
		"TeleportPadExit",
		Vector3.new(size * 0.6, 0.4, size * 0.6),
		landing * CFrame.new(0, 0.2, 0),
		ctx.palette.accent,
		Enum.Material.Neon
	)
	padB.Transparency = 0.4
	local cooldown: { [Model]: number } = {}
	killTouch(padA, function(character)
		local now = os.clock()
		if (cooldown[character] or 0) > now then
			return
		end
		cooldown[character] = now + 1.5
		character:PivotTo(landing * CFrame.new(0, 3, 0))
	end)
	return advance(landing, size / 2)
end

Chunks.fanLaunch = function(ctx)
	local cursor = ctx.cframe
	local size = math.max(6, platformSize(ctx))
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	local fan = makePart(
		ctx,
		"Fan",
		Vector3.new(size * 0.7, 0.5, size * 0.7),
		cursor * CFrame.new(0, 0.25, 0),
		ctx.palette.accent,
		Enum.Material.Neon
	)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(25)
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = fan
	local height = ctx.rng:NextNumber(14, 20 + ctx.difficulty.heightVariance)
	local forward = size / 2 + ctx.rng:NextNumber(6, 10) + size / 2
	local landing = advance(cursor, forward, height)
	platform(ctx, landing, size, size)
	killTouch(fan, function(character)
		impulse(character, Vector3.new(0, 70, 0) + cursor.LookVector * 18, 0.35)
	end)
	return advance(landing, size / 2)
end

Chunks.shrinkingPlatform = function(ctx)
	local cursor = ctx.cframe
	local count = ctx.rng:NextInteger(3, 5)
	for _ = 1, count do
		local size = platformSize(ctx)
		cursor = advance(cursor, size / 2)
		local part = platform(ctx, cursor, size, size, ctx.palette.secondary)
		local original = part.CFrame
		local sinking = false
		killTouch(part, function()
			if sinking then
				return
			end
			sinking = true
			local down = TweenService:Create(
				part,
				TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = original * CFrame.new(0, -6, 0) }
			)
			down:Play()
			task.delay(3.5, function()
				part.CFrame = original
				sinking = false
			end)
		end)
		cursor = advance(cursor, size / 2 + gapSize(ctx) * 0.8)
	end
	local size = platformSize(ctx)
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	return advance(cursor, size / 2)
end

Chunks.rotatingBar = function(ctx)
	local cursor = ctx.cframe
	local size = math.max(6, platformSize(ctx))
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	local length = ctx.rng:NextNumber(22, 30)
	local center = advance(cursor, size / 2 + length / 2)
	local bar = makePart(
		ctx,
		"RotatingBar",
		Vector3.new(3, 1, length),
		center * CFrame.new(0, -0.5, 0),
		ctx.palette.accent,
		Enum.Material.Wood
	)
	Movers.rotate(bar, center * CFrame.new(0, -0.5, 0), math.rad(18 + ctx.difficulty.moverSpeed), 0)
	addWaypoint(ctx, center.Position)
	local landing = advance(center, length / 2 + size / 2)
	platform(ctx, landing, size, size)
	return advance(landing, size / 2)
end

Chunks.narrowBeam = function(ctx)
	local cursor = ctx.cframe
	local segments = ctx.rng:NextInteger(2, 4)
	for _ = 1, segments do
		local length = ctx.rng:NextNumber(10, 18)
		local top = advance(cursor, length / 2)
		makePart(
			ctx,
			"Beam",
			Vector3.new(1.2, PLATFORM_THICKNESS, length),
			top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0),
			ctx.palette.secondary
		)
		addWaypoint(ctx, top.Position)
		cursor = advance(cursor, length)
		local bend = ctx.rng:NextNumber(-25, 25)
		cursor = cursor * CFrame.Angles(0, math.rad(bend), 0)
	end
	local size = platformSize(ctx)
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	return advance(cursor, size / 2)
end

Chunks.bouncePad = function(ctx)
	local cursor = ctx.cframe
	local size = math.max(6, platformSize(ctx))
	cursor = advance(cursor, size / 2)
	platform(ctx, cursor, size, size)
	local pad = makePart(
		ctx,
		"BouncePad",
		Vector3.new(size * 0.6, 0.6, size * 0.6),
		cursor * CFrame.new(0, 0.3, 0),
		ctx.palette.accent,
		Enum.Material.Neon
	)
	local forward = size / 2 + ctx.rng:NextNumber(10, 14) + size / 2
	local height = ctx.rng:NextNumber(6, 10)
	local landing = advance(cursor, forward, height)
	platform(ctx, landing, size, size)
	local cooldown: { [Model]: number } = {}
	killTouch(pad, function(character)
		local now = os.clock()
		if (cooldown[character] or 0) > now then
			return
		end
		cooldown[character] = now + 1
		impulse(character, Vector3.new(0, 55, 0) + cursor.LookVector * 22, 0.3)
	end)
	return advance(landing, size / 2)
end

Chunks.laserGrid = function(ctx)
	local cursor = ctx.cframe
	local length = ctx.rng:NextNumber(26, 40)
	local width = math.max(6, platformSize(ctx))
	local top = advance(cursor, length / 2)
	makePart(
		ctx,
		"LaserFloor",
		Vector3.new(width, PLATFORM_THICKNESS, length),
		top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0)
	)
	addWaypoint(ctx, advance(cursor, 2).Position)
	local spacing = 7
	local travelled = spacing
	local index = 0
	while travelled < length - 3 do
		local beamCF = advance(cursor, travelled) * CFrame.new(0, 2.5, 0)
		local beam = makePart(ctx, "Laser", Vector3.new(width, 0.4, 0.4), beamCF, KILL_COLOR, Enum.Material.Neon)
		markKill(beam)
		Movers.toggle(beam, ctx.difficulty.timingWindow, ctx.difficulty.timingWindow * 0.8, index * 0.6)
		addWaypoint(ctx, advance(cursor, travelled + spacing / 2).Position)
		travelled += spacing
		index += 1
	end
	return advance(cursor, length)
end

Chunks.crusher = function(ctx)
	local cursor = ctx.cframe
	local length = ctx.rng:NextNumber(24, 34)
	local width = math.max(6, platformSize(ctx))
	local top = advance(cursor, length / 2)
	makePart(
		ctx,
		"CrusherFloor",
		Vector3.new(width, PLATFORM_THICKNESS, length),
		top * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0)
	)
	addWaypoint(ctx, advance(cursor, 2).Position)
	local spacing = 9
	local travelled = spacing
	local index = 0
	while travelled < length - 4 do
		local restCF = advance(cursor, travelled) * CFrame.new(0, 11, 0)
		local block =
			makePart(ctx, "Crusher", Vector3.new(width, 4, 5), restCF, ctx.palette.ground, Enum.Material.Slate)
		markKill(block)
		local period = math.max(1.6, ctx.difficulty.timingWindow * 1.6)
		Movers.slam(block, restCF, restCF * CFrame.new(0, -9, 0), period, index * 0.5)
		addWaypoint(ctx, advance(cursor, travelled + spacing / 2).Position)
		travelled += spacing
		index += 1
	end
	return advance(cursor, length)
end

return table.freeze(Chunks)
