--!strict
-- Specs for Shared/ChaseProfiles: every profile at several t values, blink cadence over a simulated
-- run, the roarer timeline, the stalker cap, telegraph windows, vertical offsets and bad input.
local T = require("./assert")
local ChaseProfiles = require("./ChaseProfiles")

local NONE: { [string]: number } = {}
local DT = 1 / 15

T.test("Names lists the seven profiles in roster order and is frozen", function()
	T.eq(#ChaseProfiles.Names, 7)
	local expected = { "steady", "bursty", "stalker", "flyer", "swimmer", "blinker", "roarer" }
	for i, name in expected do
		T.eq(ChaseProfiles.Names[i], name, "Names[" .. i .. "]")
	end
	T.truthy(table.isfrozen(ChaseProfiles.Names), "Names frozen")
	T.throws(function()
		(ChaseProfiles.Names :: any)[8] = "extra"
	end, "writing to Names throws")
end)

T.test("steady, flyer and swimmer are always 1 whatever t or idle time", function()
	for _, profile in { "steady", "flyer", "swimmer" } do
		for _, t in { 0, 0.5, 2, 7.25, 60, 1234.5 } do
			for _, idle in { 0, 3, 99 } do
				T.eq(ChaseProfiles.multiplier(profile :: any, NONE, t, idle), 1, profile .. " t=" .. t)
			end
		end
	end
end)

T.test("bursty alternates burst 1.5 for 2 s and rest 0.6 for 3 s", function()
	T.near(ChaseProfiles.multiplier("bursty", NONE, 0, 0), 1.5, 1e-9, "t=0")
	T.near(ChaseProfiles.multiplier("bursty", NONE, 1.99, 0), 1.5, 1e-9, "t=1.99")
	T.near(ChaseProfiles.multiplier("bursty", NONE, 2, 0), 0.6, 1e-9, "t=2")
	T.near(ChaseProfiles.multiplier("bursty", NONE, 4.99, 0), 0.6, 1e-9, "t=4.99")
	T.near(ChaseProfiles.multiplier("bursty", NONE, 5, 0), 1.5, 1e-9, "t=5 (next cycle)")
	T.near(ChaseProfiles.multiplier("bursty", NONE, 7.5, 0), 0.6, 1e-9, "t=7.5")
	T.near(ChaseProfiles.multiplier("bursty", NONE, 100.5, 0), 1.5, 1e-9, "t=100.5")
	-- Custom timings and multipliers are honoured.
	local custom = { burstMultiplier = 2, burstSeconds = 1, restMultiplier = 0.5, restSeconds = 1 }
	T.near(ChaseProfiles.multiplier("bursty", custom, 0.5, 0), 2, 1e-9, "custom burst")
	T.near(ChaseProfiles.multiplier("bursty", custom, 1.5, 0), 0.5, 1e-9, "custom rest")
	T.near(ChaseProfiles.multiplier("bursty", custom, 2.5, 0), 2, 1e-9, "custom burst again")
end)

T.test("stalker grows with idle time and caps at idleCap", function()
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, 0), 1, 1e-9, "idle 0")
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, 1), 1.35, 1e-9, "idle 1")
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, 2), 1.7, 1e-9, "idle 2")
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, 4), 2.4, 1e-9, "idle 4 (cap)")
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, 4.5), 2.4, 1e-9, "idle 4.5 capped")
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, 1000), 2.4, 1e-9, "idle 1000 capped")
	T.near(ChaseProfiles.multiplier("stalker", NONE, 10, -5), 1, 1e-9, "negative idle clamps to 0")
	local custom = { idleCap = 2, idleGain = 1 }
	T.near(ChaseProfiles.multiplier("stalker", custom, 0, 1), 2, 1e-9, "custom gain")
	T.near(ChaseProfiles.multiplier("stalker", custom, 0, 50), 3, 1e-9, "custom cap")
end)

T.test("blinker multiplier is baseMultiplier (default 0.8) and independent of t", function()
	for _, t in { 0, 3, 5.9, 6, 12.5 } do
		T.near(ChaseProfiles.multiplier("blinker", NONE, t, 0), 0.8, 1e-9, "t=" .. t)
	end
	T.near(ChaseProfiles.multiplier("blinker", { baseMultiplier = 0.5 }, 4, 0), 0.5, 1e-9, "custom")
end)

T.test("roarer timeline: roar 0 for 1.2 s, sprint 1.6 for 2.5 s, then 1 until the next roar at 9 s", function()
	local timeline = {
		{ 0, 0 },
		{ 0.6, 0 },
		{ 1.19, 0 },
		{ 1.2, 1.6 },
		{ 2.5, 1.6 },
		{ 3.69, 1.6 },
		{ 3.7, 1 },
		{ 6, 1 },
		{ 8.99, 1 },
		{ 9, 0 },
		{ 10.1, 0 },
		{ 10.5, 1.6 },
		{ 13, 1 },
		{ 18.5, 0 },
		{ 21, 1.6 },
		{ 26, 1 },
	}
	for _, row in timeline do
		T.near(ChaseProfiles.multiplier("roarer", NONE, row[1], 0), row[2], 1e-9, "t=" .. row[1])
	end
	local custom = { roarEvery = 4, roarSeconds = 1, sprintSeconds = 1, sprintMultiplier = 3 }
	T.near(ChaseProfiles.multiplier("roarer", custom, 0.5, 0), 0, 1e-9, "custom roar")
	T.near(ChaseProfiles.multiplier("roarer", custom, 1.5, 0), 3, 1e-9, "custom sprint")
	T.near(ChaseProfiles.multiplier("roarer", custom, 2.5, 0), 1, 1e-9, "custom normal")
	T.near(ChaseProfiles.multiplier("roarer", custom, 4.5, 0), 0, 1e-9, "custom second roar")
end)

T.test("blink fires exactly once per 6 s period over a simulated 30 s at dt 1/15", function()
	local blinks = 0
	local total = 0
	local blinkTicks = {}
	for k = 1, 450 do
		local t = k / 15
		local step = ChaseProfiles.blinkStep("blinker", NONE, t, DT)
		if step ~= 0 then
			T.eq(step, 25, "blink size at t=" .. t)
			blinks += 1
			table.insert(blinkTicks, k)
		end
		total += step
	end
	T.eq(blinks, 5, "blinks in (0, 30]")
	T.eq(total, 125, "total studs")
	-- Each blink lands on the tick that reaches the period boundary (6, 12, 18, 24, 30 s).
	for i, k in blinkTicks do
		T.eq(k, i * 90, "blink " .. i .. " tick")
	end
end)

T.test("blink count stays exact when time is accumulated with floating error", function()
	local t = 0
	local blinks = 0
	for _ = 1, 465 do -- about 31 s
		local previous = t
		t += DT
		local step = ChaseProfiles.blinkStep("blinker", NONE, t, t - previous)
		if step > 0 then
			blinks += 1
		end
	end
	T.eq(blinks, 5, "blinks in about 31 s")
end)

T.test("blinkStep edge cases: first tick, exact boundary, lag spike, custom params, other profiles", function()
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, DT, DT), 0, "first tick never blinks")
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, 0, DT), 0, "t=0 never blinks")
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, 6, DT), 25, "tick reaching t=6 blinks")
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, 6 + DT, DT), 0, "tick after the boundary does not")
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, 5.99, DT), 0, "just before the boundary does not")
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, 6, 0), 0, "dt 0 cannot cross")
	T.eq(ChaseProfiles.blinkStep("blinker", NONE, 13, 8), 25, "a lag spike over two boundaries blinks once")
	local custom = { blinkPeriod = 2, blinkStuds = 10 }
	T.eq(ChaseProfiles.blinkStep("blinker", custom, 2, DT), 10, "custom period and studs")
	T.eq(ChaseProfiles.blinkStep("blinker", custom, 3, DT), 0, "custom mid-period")
	T.eq(ChaseProfiles.blinkStep("blinker", custom, 4, DT), 10, "custom second blink")
	for _, profile in { "steady", "bursty", "stalker", "flyer", "swimmer", "roarer" } do
		for k = 1, 450 do
			T.eq(ChaseProfiles.blinkStep(profile :: any, NONE, k / 15, DT), 0, profile .. " never blinks")
		end
	end
end)

T.test("telegraph is true for the last 0.8 s before a blink", function()
	T.falsy(ChaseProfiles.telegraph("blinker", NONE, 0), "t=0")
	T.falsy(ChaseProfiles.telegraph("blinker", NONE, 3), "t=3")
	T.falsy(ChaseProfiles.telegraph("blinker", NONE, 5.19), "t=5.19")
	T.truthy(ChaseProfiles.telegraph("blinker", NONE, 5.21), "t=5.21")
	T.truthy(ChaseProfiles.telegraph("blinker", NONE, 5.99), "t=5.99")
	T.falsy(ChaseProfiles.telegraph("blinker", NONE, 6), "t=6 (blink just happened)")
	T.truthy(ChaseProfiles.telegraph("blinker", NONE, 11.5), "t=11.5")
	T.falsy(ChaseProfiles.telegraph("blinker", NONE, 12.5), "t=12.5")
	local custom = { blinkPeriod = 4, telegraphSeconds = 2 }
	T.falsy(ChaseProfiles.telegraph("blinker", custom, 1.9), "custom before window")
	T.truthy(ChaseProfiles.telegraph("blinker", custom, 2.1), "custom in window")
	T.falsy(ChaseProfiles.telegraph("blinker", { telegraphSeconds = 0 }, 5.9), "telegraphSeconds 0 never warns")
end)

T.test("telegraph is true during a roar and false for every other profile", function()
	T.truthy(ChaseProfiles.telegraph("roarer", NONE, 0), "roar start")
	T.truthy(ChaseProfiles.telegraph("roarer", NONE, 1.19), "roar end")
	T.falsy(ChaseProfiles.telegraph("roarer", NONE, 1.2), "sprint")
	T.falsy(ChaseProfiles.telegraph("roarer", NONE, 5), "normal")
	T.truthy(ChaseProfiles.telegraph("roarer", NONE, 9.5), "second roar")
	T.falsy(ChaseProfiles.telegraph("roarer", NONE, 17.9), "before third roar")
	for _, profile in { "steady", "bursty", "stalker", "flyer", "swimmer" } do
		for k = 0, 300 do
			T.falsy(ChaseProfiles.telegraph(profile :: any, NONE, k / 10), profile .. " never telegraphs")
		end
	end
end)

T.test("verticalOffset: flyer hovers at 8 with a 1.5 bob, swimmer -2, hovering 3, others 0", function()
	T.near(ChaseProfiles.verticalOffset("flyer", NONE, 0), 8, 1e-9, "flyer t=0")
	T.near(ChaseProfiles.verticalOffset("flyer", NONE, 0.5), 9.5, 1e-9, "flyer peak")
	T.near(ChaseProfiles.verticalOffset("flyer", NONE, 1.5), 6.5, 1e-9, "flyer trough")
	T.near(ChaseProfiles.verticalOffset("flyer", NONE, 2), 8, 1e-9, "flyer full period")
	T.near(ChaseProfiles.verticalOffset("swimmer", NONE, 0), -2, 1e-9, "swimmer t=0")
	local swimMin, swimMax = math.huge, -math.huge
	for k = 0, 80 do
		local y = ChaseProfiles.verticalOffset("swimmer", NONE, k / 10)
		swimMin = math.min(swimMin, y)
		swimMax = math.max(swimMax, y)
	end
	T.near(swimMin, -2.5, 1e-6, "swimmer bob low")
	T.near(swimMax, -1.5, 1e-6, "swimmer bob high")
	T.near(ChaseProfiles.verticalOffset("hovering", NONE, 0), 3, 1e-9, "hovering t=0")
	for _, profile in { "steady", "bursty", "stalker", "blinker", "roarer", "ground" } do
		for _, t in { 0, 0.5, 1, 7.3 } do
			T.eq(ChaseProfiles.verticalOffset(profile :: any, NONE, t), 0, profile .. " t=" .. t)
		end
	end
	local custom = { hoverHeight = 3, bobAmplitude = 1, bobPeriod = 4 }
	T.near(ChaseProfiles.verticalOffset("steady", custom, 0), 3, 1e-9, "override height")
	T.near(ChaseProfiles.verticalOffset("steady", custom, 1), 4, 1e-9, "override bob")
	T.near(ChaseProfiles.verticalOffset("flyer", { bobAmplitude = 0 }, 0.5), 8, 1e-9, "flyer bob off")
end)

T.test("unknown profile falls back to neutral values and never errors", function()
	local bogus = "bogus" :: any
	T.eq(ChaseProfiles.multiplier(bogus, NONE, 3, 2), 1, "multiplier")
	T.eq(ChaseProfiles.blinkStep(bogus, NONE, 6, DT), 0, "blinkStep")
	T.falsy(ChaseProfiles.telegraph(bogus, NONE, 5.5), "telegraph")
	T.eq(ChaseProfiles.verticalOffset(bogus, NONE, 1), 0, "verticalOffset")
	local weirdParams = { blinkPeriod = 0, roarEvery = -3, burstSeconds = 0 / 0, hoverHeight = math.huge }
	local nilParams = nil :: any
	local nan = 0 / 0
	for _, profile in { "steady", "bursty", "stalker", "flyer", "swimmer", "blinker", "roarer", "bogus" } do
		for _, params in { NONE, weirdParams, nilParams } do
			for _, t in { -5, 0, nan, math.huge, -math.huge, nil :: any, 1e12 } do
				local ok, err = pcall(function()
					local m = ChaseProfiles.multiplier(profile :: any, params, t, t)
					T.truthy(m == m and m >= 0, "finite non-negative multiplier")
					ChaseProfiles.blinkStep(profile :: any, params, t, t)
					ChaseProfiles.telegraph(profile :: any, params, t)
					local y = ChaseProfiles.verticalOffset(profile :: any, params, t)
					T.truthy(y == y, "finite offset")
				end)
				T.truthy(ok, profile .. " errored: " .. tostring(err))
			end
		end
	end
end)

T.test("bad multipliers in params never produce a negative speed", function()
	T.eq(ChaseProfiles.multiplier("bursty", { burstMultiplier = -3 }, 1, 0), 0, "negative burst clamps to 0")
	T.eq(ChaseProfiles.multiplier("blinker", { baseMultiplier = -1 }, 1, 0), 0, "negative base clamps to 0")
	T.eq(ChaseProfiles.multiplier("stalker", { idleGain = -1 }, 1, 100), 0, "negative gain clamps to 0")
	T.eq(ChaseProfiles.multiplier("roarer", { sprintMultiplier = -2 }, 2, 0), 0, "negative sprint clamps to 0")
end)

return T.finish()
