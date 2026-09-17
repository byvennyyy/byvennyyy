--!strict
--[[
	AssetResolver
	Owns the lookup of animal and egg models under ReplicatedStorage/Assets and the procedural
	placeholder models used whenever a real model is missing, so the game always runs even with no
	assets imported. Lookups never yield (FindFirstChild only) and every returned Model has a
	PrimaryPart. Placeholders are unparented, fully anchored, non-colliding, non-queryable and
	non-touchable visual-only models tinted with the biome palette; the caller clones or parents them.
	Works on both server and client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

type Palette = Types.Palette

local ANIMAL_FOLDERS: { string } = { "Animal", "BaseAnimals" }
local PLACEHOLDER_TAG = "PlaceholderModel"
local EYE_COLOR = Color3.fromRGB(20, 20, 25)

local AssetResolver = {}

-- Lookup helpers --------------------------------------------------------------------------------

local function normalize(name: string): string
	return string.lower((string.gsub(name, "[^%w]", "")))
end

local function findPath(path: { string }): Instance?
	local current: Instance = ReplicatedStorage
	for _, segment in path do
		local child = current:FindFirstChild(segment)
		if child == nil then
			return nil
		end
		current = child
	end
	return current
end

--- Guarantees the model has a PrimaryPart (HumanoidRootPart first, else any BasePart); nil if it has no parts.
local function ensurePrimaryPart(model: Model): Model?
	if model.PrimaryPart ~= nil then
		return model
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		model.PrimaryPart = root
		return model
	end
	local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
	if anyPart ~= nil then
		model.PrimaryPart = anyPart
		return model
	end
	return nil
end

--- Exact-name match first; when `fuzzy`, a case-insensitive match ignoring spaces/underscores.
local function findModelIn(container: Instance, name: string, fuzzy: boolean): Model?
	local exact = container:FindFirstChild(name)
	if exact ~= nil and exact:IsA("Model") then
		return exact
	end
	if not fuzzy then
		return nil
	end
	local wanted = normalize(name)
	for _, child in container:GetChildren() do
		if child:IsA("Model") and normalize(child.Name) == wanted then
			return child
		end
	end
	return nil
end

--- Finds an animal model: Assets/Animals/<folder> first, then both folders, exact name before a
--- case-insensitive fallback. Returns nil when nothing matches (use placeholderAnimal then).
function AssetResolver.animal(name: string, folder: string?): Model?
	local animals = findPath({ "Assets", "Animals" })
	if animals == nil then
		return nil
	end
	local candidates: { Instance } = {}
	if folder ~= nil then
		local preferred = animals:FindFirstChild(folder)
		if preferred ~= nil then
			table.insert(candidates, preferred)
		end
	end
	for _, folderName in ANIMAL_FOLDERS do
		local container = animals:FindFirstChild(folderName)
		if container ~= nil and table.find(candidates, container) == nil then
			table.insert(candidates, container)
		end
	end
	table.insert(candidates, animals)
	for _, container in candidates do
		local model = findModelIn(container, name, false)
		if model ~= nil then
			return ensurePrimaryPart(model)
		end
	end
	for _, container in candidates do
		local model = findModelIn(container, name, true)
		if model ~= nil then
			return ensurePrimaryPart(model)
		end
	end
	return nil
end

--- Finds an egg model under Assets/Eggs (exact then case-insensitive). nil name or no match -> nil.
function AssetResolver.egg(name: string?): Model?
	if name == nil or name == "" then
		return nil
	end
	local eggs = findPath({ "Assets", "Eggs" })
	if eggs == nil then
		return nil
	end
	local model = findModelIn(eggs, name, true)
	if model == nil then
		return nil
	end
	return ensurePrimaryPart(model)
end

-- Placeholder builders ---------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function weldTo(root: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RootWeld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function addSphereMesh(part: BasePart, scale: Vector3)
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "Mesh"
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale
	mesh.Parent = part
end

local function addNameTag(head: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Adornee = head
	billboard.Size = UDim2.fromScale(6, 1.2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = EYE_COLOR
	label.TextStrokeTransparency = 0.3
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.Parent = billboard

	billboard.Parent = head
end

local function markPlaceholder(model: Model)
	model:SetAttribute("Placeholder", true)
	model:AddTag(PLACEHOLDER_TAG)
end

--- A rigless blocky stand-in animal. PrimaryPart "HumanoidRootPart" (2x2x1, invisible) sits at the
--- body centre, facing -Z. Body/Head use palette.primary, legs/ears/tail palette.secondary, a name
--- tag floats above the head. Every part is anchored + welded to the root, so PivotTo/ScaleTo work.
function AssetResolver.placeholderAnimal(name: string, palette: Palette): Model
	local model = Instance.new("Model")
	model.Name = name

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.identity, palette.primary, model)
	root.Transparency = 1
	root.CastShadow = false

	local body = makePart("Body", Vector3.new(2.4, 2, 4), CFrame.new(0, 0, 0.3), palette.primary, model)
	weldTo(root, body)

	local headCFrame = CFrame.new(0, 1.4, -2.3)
	local head = makePart("Head", Vector3.new(1.8, 1.8, 1.8), headCFrame, palette.primary, model)
	weldTo(root, head)

	local eyeSize = Vector3.new(0.35, 0.35, 0.2)
	local sides: { [string]: number } = { Left = -0.45, Right = 0.45 }
	for side, x in sides do
		local eye = makePart("Eye" .. side, eyeSize, headCFrame * CFrame.new(x, 0.25, -0.85), EYE_COLOR, model)
		weldTo(root, eye)
		local ear = makePart(
			"Ear" .. side,
			Vector3.new(0.4, 0.8, 0.3),
			headCFrame * CFrame.new(x * 1.3, 1.2, 0.2),
			palette.secondary,
			model
		)
		weldTo(root, ear)
	end

	local legSize = Vector3.new(0.7, 1.6, 0.7)
	local legRows: { number } = { -1.2, 1.5 }
	local legColumns: { number } = { -0.8, 0.8 }
	local legIndex = 0
	for _, z in legRows do
		for _, x in legColumns do
			legIndex += 1
			local leg = makePart("Leg" .. legIndex, legSize, CFrame.new(x, -1.8, z), palette.secondary, model)
			weldTo(root, leg)
		end
	end

	local tail = makePart("Tail", Vector3.new(0.4, 0.4, 1.2), CFrame.new(0, 0.5, 2.8), palette.secondary, model)
	weldTo(root, tail)

	addNameTag(head, name, palette.accent)
	model.PrimaryPart = root
	markPlaceholder(model)
	return model
end

--- A procedural egg: PrimaryPart "Shell" is a tall sphere mesh tinted palette.secondary with a few
--- accent spots, plus a "Top" cap part that a hatch animation can pop off. Fully anchored, visual only.
function AssetResolver.placeholderEgg(palette: Palette): Model
	local model = Instance.new("Model")
	model.Name = "Egg"

	local shell = makePart("Shell", Vector3.new(3, 3, 3), CFrame.identity, palette.secondary, model)
	addSphereMesh(shell, Vector3.new(1, 1.35, 1))

	local topColor = palette.secondary:Lerp(Color3.new(1, 1, 1), 0.15)
	local top = makePart("Top", Vector3.new(2.1, 1.4, 2.1), CFrame.new(0, 1.55, 0), topColor, model)
	addSphereMesh(top, Vector3.new(1, 1, 1))
	weldTo(shell, top)

	local spotSize = Vector3.new(0.6, 0.6, 0.6)
	local spotOffsets: { CFrame } = {
		CFrame.new(1.1, 0.2, 0.9),
		CFrame.new(-1.0, -0.4, 1.0),
		CFrame.new(0.2, -0.9, -1.35),
	}
	for index, offset in spotOffsets do
		local spot = makePart("Spot" .. index, spotSize, offset, palette.accent, model)
		addSphereMesh(spot, Vector3.new(1, 1, 1))
		weldTo(shell, spot)
	end

	model.PrimaryPart = shell
	markPlaceholder(model)
	return model
end

return AssetResolver
