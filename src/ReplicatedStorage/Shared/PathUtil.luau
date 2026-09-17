--!strict
--[[
	PathUtil
	Pure polyline math for biome paths. A path is an ordered list of waypoints; "s" is the distance in
	studs travelled along it. The chaser lives entirely in s-space, the player is projected onto the path
	each tick, and the progress bar is just s / length. No Instances, so this runs under the CLI harness.
]]

local Types = require(script.Parent.Types)

type PathData = Types.PathData

local PathUtil = {}

local DEFAULT_WINDOW = 120 -- studs searched either side of the hint when projecting
local MIN_SEGMENT = 1e-4

--- Builds a path from waypoints, dropping zero-length segments. cumulative[1] is always 0.
function PathUtil.build(points: { Vector3 }): PathData
	assert(#points >= 2, "PathUtil.build needs at least 2 points")
	local cleaned: { Vector3 } = { points[1] }
	local cumulative: { number } = { 0 }
	local total = 0
	for i = 2, #points do
		local prev = cleaned[#cleaned]
		local d = (points[i] - prev).Magnitude
		if d > MIN_SEGMENT then
			table.insert(cleaned, points[i])
			total += d
			table.insert(cumulative, total)
		end
	end
	assert(#cleaned >= 2, "PathUtil.build needs at least 2 distinct points")
	return { points = cleaned, cumulative = cumulative, length = total }
end

function PathUtil.clamp(path: PathData, s: number): number
	return math.clamp(s, 0, path.length)
end

--- Index i of the segment [points[i], points[i + 1]] that contains s (binary search over cumulative).
function PathUtil.segmentIndexAt(path: PathData, s: number): number
	local target = PathUtil.clamp(path, s)
	local lo, hi = 1, #path.points - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if path.cumulative[mid] <= target then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

--- World position and unit tangent at distance s along the path.
function PathUtil.positionAt(path: PathData, s: number): (Vector3, Vector3)
	local target = PathUtil.clamp(path, s)
	local i = PathUtil.segmentIndexAt(path, target)
	local a, b = path.points[i], path.points[i + 1]
	local segLen = path.cumulative[i + 1] - path.cumulative[i]
	local t = (target - path.cumulative[i]) / segLen
	local tangent = (b - a) / segLen
	return a:Lerp(b, t), tangent
end

--- s of the closest point on the path to `point`. With a hint, only segments within `window` studs of
--- hintS are considered, so a folded path never snaps the projection onto a distant parallel leg.
--- Ties resolve to the smaller s.
function PathUtil.project(path: PathData, point: Vector3, hintS: number?, window: number?): number
	local startIndex, endIndex = 1, #path.points - 1
	if hintS then
		local w = window or DEFAULT_WINDOW
		startIndex = PathUtil.segmentIndexAt(path, hintS - w)
		endIndex = PathUtil.segmentIndexAt(path, hintS + w)
	end
	local bestS, bestDistance = path.cumulative[startIndex], math.huge
	for i = startIndex, endIndex do
		local a, b = path.points[i], path.points[i + 1]
		local ab = b - a
		local segLen = path.cumulative[i + 1] - path.cumulative[i]
		local t = math.clamp((point - a):Dot(ab) / (segLen * segLen), 0, 1)
		local closest = a + ab * t
		local d = (point - closest).Magnitude
		if d < bestDistance - 1e-6 then
			bestDistance = d
			bestS = path.cumulative[i] + t * segLen
		end
	end
	return bestS
end

function PathUtil.distanceBetween(_path: PathData, sA: number, sB: number): number
	return math.abs(sB - sA)
end

--- Points only; the receiver rebuilds with PathUtil.build.
function PathUtil.serialize(path: PathData): { Vector3 }
	return table.clone(path.points)
end

return table.freeze(PathUtil)
