--!strict
-- Minimal JSON for tooling and tests (pure Luau, both runtimes): encode
-- tables to compact JSON, decode it back. Arrays are tables with a [1] (or
-- empty tables marked with Json.array()); everything else is an object with
-- keys written in sorted order, so output is deterministic. Numbers are
-- written with up to `digits` decimals (default 3) and no trailing zeros.

local Json = {}

local ARRAY_MARK = setmetatable({}, { __mode = "k" }) :: { [any]: boolean }

-- An empty table that encodes as [] instead of {}.
function Json.array(t: { any }?): { any }
	local a = t or {}
	ARRAY_MARK[a] = true
	return a
end

local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encodeString(s: string): string
	return '"' .. string.gsub(s, '[%c"\\]', function(c)
		return ESC[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

local function encodeNumber(n: number, digits: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		error("Json: cannot encode NaN or infinity", 3)
	end
	if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
		return string.format("%d", n)
	end
	local s = string.format(`%.{digits}f`, n)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end

local function encodeValue(v: any, digits: number, out: { string })
	local kind = type(v)
	if kind == "nil" then
		table.insert(out, "null")
	elseif kind == "boolean" then
		table.insert(out, if v then "true" else "false")
	elseif kind == "number" then
		table.insert(out, encodeNumber(v, digits))
	elseif kind == "string" then
		table.insert(out, encodeString(v))
	elseif kind == "table" then
		if v[1] ~= nil or ARRAY_MARK[v] then
			table.insert(out, "[")
			for i = 1, #v do
				if i > 1 then
					table.insert(out, ",")
				end
				encodeValue(v[i], digits, out)
			end
			table.insert(out, "]")
		else
			local keys = {}
			for k in v do
				if type(k) ~= "string" then
					error(`Json: object keys must be strings, got {type(k)}`, 3)
				end
				table.insert(keys, k)
			end
			table.sort(keys)
			table.insert(out, "{")
			for i, k in keys do
				if i > 1 then
					table.insert(out, ",")
				end
				table.insert(out, encodeString(k))
				table.insert(out, ":")
				encodeValue(v[k], digits, out)
			end
			table.insert(out, "}")
		end
	else
		error(`Json: cannot encode a {kind}`, 3)
	end
end

function Json.encode(v: any, digits: number?): string
	local out = {}
	encodeValue(v, digits or 3, out)
	return table.concat(out)
end

-- Decoder (for tests): returns the value or errors with a position.
function Json.decode(s: string): any
	local i = 1
	local function fail(msg: string): never
		error(`Json: {msg} at {i}`, 0)
	end
	local function ws()
		i = string.find(s, "[^ \t\r\n]", i) or #s + 1
	end
	local value: () -> any
	local function str(): string
		i += 1
		local parts = {}
		while true do
			local c = string.sub(s, i, i)
			if c == "" then
				fail("unterminated string")
			elseif c == '"' then
				i += 1
				return table.concat(parts)
			elseif c == "\\" then
				local e = string.sub(s, i + 1, i + 1)
				local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if e == "u" then
					table.insert(parts, utf8.char(tonumber(string.sub(s, i + 2, i + 5), 16) :: number))
					i += 6
				elseif map[e] then
					table.insert(parts, map[e])
					i += 2
				else
					fail("bad escape")
				end
			else
				table.insert(parts, c)
				i += 1
			end
		end
	end
	value = function(): any
		ws()
		local c = string.sub(s, i, i)
		if c == "{" then
			i += 1
			local obj = {}
			ws()
			if string.sub(s, i, i) == "}" then
				i += 1
				return obj
			end
			while true do
				ws()
				if string.sub(s, i, i) ~= '"' then
					fail("expected a key")
				end
				local k = str()
				ws()
				if string.sub(s, i, i) ~= ":" then
					fail("expected ':'")
				end
				i += 1
				obj[k] = value()
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "}" then
					return obj
				elseif d ~= "," then
					fail("expected ',' or '}'")
				end
			end
		elseif c == "[" then
			i += 1
			local arr = Json.array()
			ws()
			if string.sub(s, i, i) == "]" then
				i += 1
				return arr
			end
			while true do
				table.insert(arr, value())
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "]" then
					return arr
				elseif d ~= "," then
					fail("expected ',' or ']'")
				end
			end
		elseif c == '"' then
			return str()
		elseif string.sub(s, i, i + 3) == "true" then
			i += 4
			return true
		elseif string.sub(s, i, i + 4) == "false" then
			i += 5
			return false
		elseif string.sub(s, i, i + 3) == "null" then
			i += 4
			return nil
		else
			local num = string.match(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", i)
			if num == nil or num == "" then
				fail("unexpected character")
			end
			i += #(num :: string)
			return tonumber(num)
		end
	end
	local v = value()
	ws()
	if i <= #s then
		fail("trailing characters")
	end
	return v
end

return Json
