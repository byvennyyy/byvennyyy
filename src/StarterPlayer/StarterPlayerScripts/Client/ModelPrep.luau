--!strict
--[[
	ModelPrep
	Owns turning an animal or egg model into a purely visual client-side prop: every part anchored and
	non-colliding, a PrimaryPart guaranteed, oversized rigs scaled down, plus animation lookup
	(Animator + Animation objects named Run/Walk/Idle anywhere in the model).
]]

local MAX_HEIGHT = 12

local ModelPrep = {}

export type Prepared = {
	model: Model,
	baseScale: number, -- scale factor applied to fit MAX_HEIGHT (1 = untouched)
	halfHeight: number, -- half of the (scaled) bounding box height
	tracks: { [string]: AnimationTrack },
}

local function ensurePrimaryPart(model: Model)
	if model.PrimaryPart then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		return
	end
	local biggest: BasePart? = nil
	local biggestVolume = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local v = part.Size.X * part.Size.Y * part.Size.Z
			if v > biggestVolume then
				biggest, biggestVolume = part, v
			end
		end
	end
	model.PrimaryPart = biggest
end

local function findTracks(model: Model): { [string]: AnimationTrack }
	local tracks: { [string]: AnimationTrack } = {}
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local host = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
		if host then
			local created = Instance.new("Animator")
			created.Parent = host
			animator = created
		end
	end
	if not animator then
		return tracks
	end
	for _, obj in model:GetDescendants() do
		if obj:IsA("Animation") and obj.AnimationId ~= "" then
			local key = string.lower(obj.Name)
			local slot = if string.find(key, "run")
				then "run"
				elseif string.find(key, "walk") then "walk"
				elseif string.find(key, "idle") then "idle"
				elseif string.find(key, "fly") or string.find(key, "swim") then "run"
				else nil
			if slot and not tracks[slot] then
				local ok, track = pcall(function()
					return (animator :: Animator):LoadAnimation(obj)
				end)
				if ok then
					tracks[slot] = track
				end
			end
		end
	end
	if not tracks.run and tracks.walk then
		tracks.run = tracks.walk
	end
	return tracks
end

function ModelPrep.prepare(source: Model): Prepared
	local model = source:Clone()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		elseif part:IsA("Script") or part:IsA("LocalScript") then
			part:Destroy()
		end
	end
	ensurePrimaryPart(model)
	local extents = model:GetExtentsSize()
	local baseScale = 1
	if extents.Y > MAX_HEIGHT then
		baseScale = MAX_HEIGHT / extents.Y
		model:ScaleTo(baseScale)
		extents = model:GetExtentsSize()
	end
	return { model = model, baseScale = baseScale, halfHeight = extents.Y / 2, tracks = findTracks(model) }
end

function ModelPrep.play(prepared: Prepared, slot: string)
	for name, track in pairs(prepared.tracks) do
		if name == slot then
			if not track.IsPlaying then
				track:Play(0.2)
			end
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

return ModelPrep
