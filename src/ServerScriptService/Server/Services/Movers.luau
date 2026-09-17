--!strict
--[[
	Movers
	Owns one shared Heartbeat driver for every animated greybox part: rotating kill bars, timed
	laser toggles and slamming crushers. One connection updates all registered parts, which is far
	cheaper than a thread per part across 200 stages. Parts are Anchored and moved by the server, so
	their motion replicates to every client.
]]

local RunService = game:GetService("RunService")

type Rotator = { part: BasePart, center: CFrame, speed: number, phase: number }
type Toggler = { part: BasePart, onSeconds: number, offSeconds: number, offset: number, wasOn: boolean }
type Slammer = { part: BasePart, up: CFrame, down: CFrame, period: number, offset: number }

local rotators: { Rotator } = {}
local togglers: { Toggler } = {}
local slammers: { Slammer } = {}
local started = false

local Movers = {}

--- Rotates `part` around the Y axis of `center` at `speed` radians per second.
function Movers.rotate(part: BasePart, center: CFrame, speed: number, phase: number)
	table.insert(rotators, { part = part, center = center, speed = speed, phase = phase })
end

--- Alternates the part between lethal-visible (onSeconds) and harmless-hidden (offSeconds).
function Movers.toggle(part: BasePart, onSeconds: number, offSeconds: number, offset: number)
	table.insert(
		togglers,
		{ part = part, onSeconds = onSeconds, offSeconds = offSeconds, offset = offset, wasOn = true }
	)
end

--- Slams the part from `up` to `down` (fast) and back (slow) once per `period` seconds.
function Movers.slam(part: BasePart, up: CFrame, down: CFrame, period: number, offset: number)
	table.insert(slammers, { part = part, up = up, down = down, period = period, offset = offset })
end

local function step()
	local now = os.clock()
	for _, r in rotators do
		r.part.CFrame = r.center * CFrame.Angles(0, r.phase + now * r.speed, 0)
	end
	for _, t in togglers do
		local cycle = t.onSeconds + t.offSeconds
		local phase = (now + t.offset) % cycle
		local on = phase < t.onSeconds
		if on ~= t.wasOn then
			t.wasOn = on
			t.part.CanTouch = on
			t.part.Transparency = if on then 0 else 0.85
		end
	end
	for _, s in slammers do
		local phase = ((now + s.offset) % s.period) / s.period
		-- 0..0.15 slam down, 0.15..0.35 rest down, 0.35..1 rise slowly
		local alpha
		if phase < 0.15 then
			alpha = phase / 0.15
		elseif phase < 0.35 then
			alpha = 1
		else
			alpha = 1 - (phase - 0.35) / 0.65
		end
		s.part.CFrame = s.up:Lerp(s.down, alpha)
	end
end

function Movers.Start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(step)
end

function Movers.Counts(): (number, number, number)
	return #rotators, #togglers, #slammers
end

return Movers
