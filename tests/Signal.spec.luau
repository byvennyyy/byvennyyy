--!nonstrict
-- Spec for Shared/Signal.luau under the standalone luau CLI.
local T = require("./assert")
local shim = require("./_shim")

-- The shared shim's task.spawn only accepts functions; Signal:Wait resumes a *thread* through
-- task.spawn (as Roblox allows), so this spec extends the shim in place to accept threads too.
-- The Signal module captured the same task table, so the patch reaches it.
local originalSpawn = shim.task.spawn
shim.task.spawn = function(target, ...)
	if type(target) == "thread" then
		local ok, err = coroutine.resume(target, ...)
		if not ok then
			error(err, 0)
		end
		return target
	end
	return originalSpawn(target, ...)
end

local Signal = require("./Signal")

T.test("connect + fire delivers arguments every time", function()
	local signal = Signal.new()
	local received = {}
	signal:Connect(function(a, b)
		table.insert(received, { a, b })
	end)
	signal:Fire(1, "x")
	signal:Fire(2, "y")
	T.eq(#received, 2)
	T.eq(received[1][1], 1)
	T.eq(received[1][2], "x")
	T.eq(received[2][1], 2)
	T.eq(received[2][2], "y")
end)

T.test("fire preserves argument count including nils", function()
	local signal = Signal.new()
	local count, third
	signal:Connect(function(...)
		count = select("#", ...)
		third = select(3, ...)
	end)
	signal:Fire(1, nil, 3)
	T.eq(count, 3)
	T.eq(third, 3)
end)

T.test("handlers run in connection order", function()
	local signal = Signal.new()
	local order = {}
	for i = 1, 5 do
		signal:Connect(function()
			table.insert(order, i)
		end)
	end
	signal:Fire()
	T.eq(table.concat(order, ","), "1,2,3,4,5")
end)

T.test("once fires exactly once and reports disconnected", function()
	local signal = Signal.new()
	local calls = 0
	local connection = signal:Once(function()
		calls += 1
	end)
	T.truthy(connection.Connected)
	signal:Fire()
	T.falsy(connection.Connected)
	signal:Fire()
	signal:Fire()
	T.eq(calls, 1)
end)

T.test("disconnect stops delivery and is idempotent", function()
	local signal = Signal.new()
	local calls = 0
	local connection = signal:Connect(function()
		calls += 1
	end)
	signal:Fire()
	connection:Disconnect()
	connection:Disconnect()
	T.falsy(connection.Connected)
	signal:Fire()
	T.eq(calls, 1)
end)

T.test("disconnecting a later handler during fire skips it in the same dispatch", function()
	local signal = Signal.new()
	local secondCalls = 0
	local second
	signal:Connect(function()
		second:Disconnect()
	end)
	second = signal:Connect(function()
		secondCalls += 1
	end)
	signal:Fire()
	signal:Fire()
	T.eq(secondCalls, 0)
end)

T.test("connecting during fire does not run until the next fire", function()
	local signal = Signal.new()
	local lateCalls = 0
	signal:Once(function()
		signal:Connect(function()
			lateCalls += 1
		end)
	end)
	signal:Fire()
	T.eq(lateCalls, 0)
	signal:Fire()
	T.eq(lateCalls, 1)
end)

T.test("wait resumes with the fired values in handler order", function()
	local signal = Signal.new()
	local order = {}
	signal:Connect(function()
		table.insert(order, "handler-before")
	end)
	local waited
	local waiter = coroutine.create(function()
		local a, b = signal:Wait()
		waited = { a, b }
		table.insert(order, "wait")
	end)
	coroutine.resume(waiter)
	T.eq(coroutine.status(waiter), "suspended")
	signal:Connect(function()
		table.insert(order, "handler-after")
	end)
	signal:Fire(7, "seven")
	T.eq(coroutine.status(waiter), "dead")
	T.eq(waited[1], 7)
	T.eq(waited[2], "seven")
	T.eq(table.concat(order, ","), "handler-before,wait,handler-after")
	-- Wait is one-shot: a second fire must not try to resume the dead thread.
	signal:Fire(8, "eight")
	T.eq(waited[1], 7)
end)

T.test("disconnectAll drops every handler", function()
	local signal = Signal.new()
	local calls = 0
	local c1 = signal:Connect(function()
		calls += 1
	end)
	local c2 = signal:Connect(function()
		calls += 1
	end)
	signal:DisconnectAll()
	T.falsy(c1.Connected)
	T.falsy(c2.Connected)
	signal:Fire()
	T.eq(calls, 0)
	signal:Connect(function()
		calls += 1
	end)
	signal:Fire()
	T.eq(calls, 1, "signal still usable after DisconnectAll")
end)

T.test("destroy disconnects and refuses new work", function()
	local signal = Signal.new()
	local calls = 0
	signal:Connect(function()
		calls += 1
	end)
	signal:Destroy()
	local dead = signal:Connect(function()
		calls += 1
	end)
	T.falsy(dead.Connected)
	signal:Fire()
	T.eq(calls, 0)
	T.throws(function()
		signal:Wait()
	end, "Wait on destroyed signal throws")
end)

T.test("firing with no connections is a no-op and Signal.is works", function()
	local signal = Signal.new()
	signal:Fire(1, 2, 3)
	T.truthy(Signal.is(signal))
	T.falsy(Signal.is({}))
	T.falsy(Signal.is(nil))
	T.throws(function()
		signal:Connect("not a function")
	end, "Connect rejects non-functions")
end)

return T.finish()
