--!strict
--[[
	Signal
	Minimal typed event used everywhere instead of BindableEvents. Owns connection bookkeeping
	(Connect / Once / Disconnect / DisconnectAll), dispatch (Fire runs every handler on its own thread
	via task.spawn, so a yielding handler never blocks the others) and Wait.

	Guarantees:
	- Handlers run in connection order.
	- A handler disconnected during a Fire is not called in that same dispatch; a handler connected
	  during a Fire is not called until the next one.
	- Fire preserves argument count, including nils in the middle.
	- After Destroy, Connect/Once return an already-disconnected connection and Fire is a no-op.
	Pure Luau (no Instances), so it also runs under the CLI test harness.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Handler = (...any) -> ()

type ConnectionRecord = {
	Connected: boolean,
	Disconnect: (self: ConnectionRecord) -> (),
	_fn: Handler,
	_signal: SignalRecord?,
	_once: boolean,
}

type SignalRecord = {
	_connections: { ConnectionRecord },
	_destroyed: boolean,
}

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: ConnectionRecord)
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	self._signal = nil
	if signal ~= nil then
		local list = signal._connections
		local index = table.find(list, self)
		if index ~= nil then
			table.remove(list, index)
		end
	end
end

local SignalClass = {}
SignalClass.__index = SignalClass

local function connect(self: SignalRecord, fn: Handler, once: boolean): Connection
	assert(type(fn) == "function", "Signal:Connect expects a function handler")
	local alive = not self._destroyed
	local record = {
		Connected = alive,
		_fn = fn,
		_signal = if alive then self else nil,
		_once = once,
	}
	local connection = (setmetatable(record, ConnectionClass) :: any) :: ConnectionRecord
	if alive then
		table.insert(self._connections, connection)
	end
	return (connection :: any) :: Connection
end

function SignalClass.Connect(self: SignalRecord, fn: Handler): Connection
	return connect(self, fn, false)
end

function SignalClass.Once(self: SignalRecord, fn: Handler): Connection
	return connect(self, fn, true)
end

function SignalClass.Fire(self: SignalRecord, ...: any)
	local list = self._connections
	local count = #list
	if count == 0 then
		return
	end
	-- Snapshot so connects/disconnects inside handlers cannot skip or double-call anyone.
	local snapshot = table.clone(list)
	for index = 1, count do
		local connection = snapshot[index]
		if connection.Connected then
			if connection._once then
				connection:Disconnect()
			end
			task.spawn(connection._fn, ...)
		end
	end
end

function SignalClass.Wait(self: SignalRecord): ...any
	if self._destroyed then
		error("Signal:Wait called on a destroyed signal", 2)
	end
	local thread = coroutine.running()
	connect(self, function(...)
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end, true)
	return coroutine.yield()
end

function SignalClass.DisconnectAll(self: SignalRecord)
	local list = self._connections
	for index = #list, 1, -1 do
		local connection = list[index]
		connection.Connected = false
		connection._signal = nil
		list[index] = nil
	end
end

function SignalClass.Destroy(self: SignalRecord)
	SignalClass.DisconnectAll(self)
	self._destroyed = true
end

local Signal = {}

--- Creates a new signal. `T...` is the parameter pack handlers receive, e.g. `Signal.new<Player, number>()`.
function Signal.new<T...>(): Signal<T...>
	local record: SignalRecord = { _connections = {}, _destroyed = false }
	return (setmetatable(record, SignalClass) :: any) :: Signal<T...>
end

--- True when `value` was created by `Signal.new`.
function Signal.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == SignalClass
end

return Signal
