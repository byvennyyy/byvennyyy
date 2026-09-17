-- Minimal Roblox datatype shims for running pure modules in the standalone luau CLI.
local V3 = {}
V3.__index = V3
local function v3(x: number?, y: number?, z: number?)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.new = v3
V3.zero = v3(0, 0, 0)
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
function V3:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function V3:Cross(b) return v3(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X) end
function V3:Lerp(b, t) return self + (b - self) * t end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); if m == 0 then return v3(0,0,0) end; return v3(t.X / m, t.Y / m, t.Z / m) end
	return V3[k]
end
local C3 = {}
C3.__index = C3
C3.new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
C3.fromRGB = function(r, g, b) return C3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
C3.fromHex = function(hex)
	hex = hex:gsub("#", "")
	return C3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function C3:ToHex() return string.format("%02X%02X%02X", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5)) end
function C3:Lerp(b, t) return C3.new(self.R + (b.R - self.R) * t, self.G + (b.G - self.G) * t, self.B + (b.B - self.B) * t) end

local CF = {}
CF.__index = CF
CF.new = function(x, y, z)
	if type(x) == "table" then return setmetatable({ Position = x }, CF) end
	return setmetatable({ Position = v3(x or 0, y or 0, z or 0) }, CF)
end
CF.lookAt = function(at, target) return setmetatable({ Position = at, LookVector = (target - at).Unit }, CF) end
CF.__mul = function(a, b) return setmetatable({ Position = a.Position + b.Position }, CF) end
local taskShim = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) fn(...) end,
	delay = function(_, fn, ...) fn(...) end,
	wait = function(t) return t or 0 end,
	cancel = function() end,
}
return { Vector3 = V3, Color3 = C3, CFrame = CF, task = taskShim }
