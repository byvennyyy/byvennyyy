local T = require("./assert")
local PathUtil = require("./PathUtil")
local V = require("./_shim").Vector3

local straight = PathUtil.build({ V.new(0, 0, 0), V.new(10, 0, 0), V.new(20, 0, 0) })
local lshape = PathUtil.build({ V.new(0, 0, 0), V.new(10, 0, 0), V.new(10, 0, 10) })
-- hairpin: two parallel legs 4 studs apart
local hairpin = PathUtil.build({ V.new(0, 0, 0), V.new(50, 0, 0), V.new(50, 0, 4), V.new(0, 0, 4) })

T.test("build computes cumulative and length", function()
	T.eq(#straight.points, 3)
	T.eq(straight.cumulative[1], 0)
	T.near(straight.cumulative[3], 20)
	T.near(straight.length, 20)
end)
T.test("build skips zero-length segments", function()
	local p = PathUtil.build({ V.new(0, 0, 0), V.new(0, 0, 0), V.new(5, 0, 0), V.new(5, 0, 0), V.new(5, 5, 0) })
	T.eq(#p.points, 3)
	T.near(p.length, 10)
end)
T.test("build rejects fewer than two distinct points", function()
	T.throws(function() PathUtil.build({ V.new(0, 0, 0) }) end)
	T.throws(function() PathUtil.build({ V.new(1, 1, 1), V.new(1, 1, 1) }) end)
end)
T.test("positionAt interpolates and clamps", function()
	local p = PathUtil.positionAt(straight, 5)
	T.near(p.X, 5)
	local lo = PathUtil.positionAt(straight, -7)
	T.near(lo.X, 0)
	local hi = PathUtil.positionAt(straight, 99)
	T.near(hi.X, 20)
end)
T.test("positionAt at exact vertices", function()
	local p, tan = PathUtil.positionAt(lshape, 10)
	T.near(p.X, 10); T.near(p.Z, 0)
	T.near(tan.Z, 1, 1e-4, "tangent belongs to the second leg at the shared vertex")
	local p2 = PathUtil.positionAt(lshape, 20)
	T.near(p2.Z, 10)
end)
T.test("tangent direction per leg", function()
	local _, t1 = PathUtil.positionAt(lshape, 3)
	T.near(t1.X, 1); T.near(t1.Z, 0)
	local _, t2 = PathUtil.positionAt(lshape, 15)
	T.near(t2.X, 0); T.near(t2.Z, 1)
end)
T.test("project on a straight line", function()
	T.near(PathUtil.project(straight, V.new(7, 3, 2)), 7)
	T.near(PathUtil.project(straight, V.new(-5, 0, 0)), 0)
	T.near(PathUtil.project(straight, V.new(50, 0, 0)), 20)
end)
T.test("project at exactly a vertex", function()
	T.near(PathUtil.project(lshape, V.new(10, 0, 0)), 10)
end)
T.test("project without a hint picks the true nearest leg", function()
	-- a point 1 stud from the return leg (z = 4) is nearest to the return leg
	local s = PathUtil.project(hairpin, V.new(25, 0, 3))
	T.near(s, 50 + 4 + 25)
end)
T.test("project with a hint stays on the current leg of a hairpin", function()
	local s = PathUtil.project(hairpin, V.new(25, 0, 3), 24, 20)
	T.near(s, 25, 1e-4, "hint on the first leg must keep the projection on the first leg")
end)
T.test("window limits the search range", function()
	-- hint at start, window 10: only the first segment is searched, so a point near the end projects to s <= 50
	local s = PathUtil.project(hairpin, V.new(5, 0, 4), 0, 10)
	T.near(s, 5)
end)
T.test("segmentIndexAt matches brute force on a long path", function()
	local pts = {}
	for i = 0, 199 do
		table.insert(pts, V.new(i * 3, math.sin(i) * 2, math.cos(i * 0.5) * 5))
	end
	local p = PathUtil.build(pts)
	for k = 1, 60 do
		local s = (k / 60) * p.length
		local want = 1
		for i = 1, #p.points - 1 do
			if p.cumulative[i] <= s then want = i end
		end
		T.eq(PathUtil.segmentIndexAt(p, s), want, "segment for s=" .. s)
	end
end)
T.test("project agrees with brute force on a long path", function()
	local pts = {}
	for i = 0, 199 do
		table.insert(pts, V.new(i * 3, math.sin(i) * 2, math.cos(i * 0.5) * 5))
	end
	local p = PathUtil.build(pts)
	for k = 1, 30 do
		local q = V.new(k * 19, math.sin(k) * 3, math.cos(k) * 4)
		local bestS, bestD = 0, math.huge
		for i = 1, #p.points - 1 do
			local a, b = p.points[i], p.points[i + 1]
			local ab = b - a
			local len = p.cumulative[i + 1] - p.cumulative[i]
			local t = math.clamp((q - a):Dot(ab) / (len * len), 0, 1)
			local d = (q - (a + ab * t)).Magnitude
			if d < bestD - 1e-6 then bestD = d; bestS = p.cumulative[i] + t * len end
		end
		T.near(PathUtil.project(p, q), bestS, 1e-3)
	end
end)
T.test("serialize returns a copy", function()
	local pts = PathUtil.serialize(straight)
	T.eq(#pts, 3)
	pts[1] = V.new(99, 99, 99)
	T.near(straight.points[1].X, 0)
end)
T.test("distanceBetween", function()
	T.near(PathUtil.distanceBetween(straight, 3, 8), 5)
end)
return T.finish()
