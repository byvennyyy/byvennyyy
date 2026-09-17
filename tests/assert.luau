--!nonstrict
-- Tiny test helpers for the standalone luau CLI. Usage in a spec:
--   local T = require("./assert")
--   T.test("name", function() T.eq(1 + 1, 2) end)
--   return T.finish()
local T = { passed = 0, failed = 0, failures = {} }
local function fmt(v)
	if type(v) == "table" and getmetatable(v) and getmetatable(v).__tostring then return tostring(v) end
	if type(v) == "table" then
		local parts = {}
		for k, x in pairs(v) do table.insert(parts, tostring(k) .. "=" .. tostring(x)) end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end
function T.eq(actual, expected, msg)
	if actual ~= expected then error(("%s: expected %s, got %s"):format(msg or "eq", fmt(expected), fmt(actual)), 2) end
end
function T.near(actual, expected, tol, msg)
	if math.abs(actual - expected) > (tol or 1e-4) then error(("%s: expected %s +- %s, got %s"):format(msg or "near", fmt(expected), tostring(tol or 1e-4), fmt(actual)), 2) end
end
function T.truthy(v, msg) if not v then error((msg or "truthy") .. ": got " .. fmt(v), 2) end end
function T.falsy(v, msg) if v then error((msg or "falsy") .. ": got " .. fmt(v), 2) end end
function T.throws(fn, msg) local ok = pcall(fn); if ok then error((msg or "throws") .. ": did not throw", 2) end end
function T.test(name, fn)
	local ok, err = pcall(fn)
	if ok then T.passed += 1; print("  ok   " .. name)
	else T.failed += 1; table.insert(T.failures, name .. ": " .. tostring(err)); print("  FAIL " .. name .. "\n       " .. tostring(err)) end
end
function T.finish()
	print(("%d passed, %d failed"):format(T.passed, T.failed))
	if T.failed > 0 then error("tests failed", 0) end
	return true
end
return T
