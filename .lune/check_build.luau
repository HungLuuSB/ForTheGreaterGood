--!strict
-- Checks a built place (default build/place.rbxl, from `lune run build`):
--   * every script's source compiles (Luau syntax);
--   * no string require is left (`require("...")` / `require('...')`);
--   * every require is an Instance path darklua's convert_require emits
--     (script / game:GetService(...), then .Parent, :FindFirstChild(...),
--     :WaitForChild(...), .Name or ["Name"]) and it resolves, in the
--     place, to an existing ModuleScript.
--   lune run check_build [place file]
-- Exits with code 1 on any problem.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local PLACE = process.args[1] or "build/place.rbxl"
if not fs.isFile(PLACE) then
	print(`{PLACE} not found: run "lune run build" first`)
	process.exit(1)
end

local game = roblox.deserializePlace(fs.readFile(PLACE))

local problems: { string } = {}
local function problem(script: roblox.Instance, msg: string)
	table.insert(problems, `{script:GetFullName()}: {msg}`)
end

-- Finds `require(<argument>)` calls outside comments and strings; returns
-- the argument source texts.
local function requireCalls(src: string): { string }
	local out = {}
	local i, n = 1, #src
	local function skipLongBracket(at: number): number?
		-- at points to "[": returns the index after the matching close, or nil if not a long bracket
		local eq = string.match(src, "^%[(=*)%[", at)
		if eq == nil then
			return nil
		end
		local close = "]" .. eq .. "]"
		local e = string.find(src, close, at + #eq + 2, true)
		return if e then e + #close else n + 1
	end
	while i <= n do
		local c = string.sub(src, i, i)
		if c == "-" and string.sub(src, i, i + 1) == "--" then
			local after = skipLongBracket(i + 2)
			if after then
				i = after
			else
				local e = string.find(src, "\n", i, true)
				i = if e then e + 1 else n + 1
			end
		elseif c == "\"" or c == "'" or c == "`" then
			local j = i + 1
			while j <= n do
				local d = string.sub(src, j, j)
				if d == "\\" then
					j += 2
				elseif d == c then
					break
				else
					j += 1
				end
			end
			i = j + 1
		elseif c == "[" and skipLongBracket(i) then
			i = skipLongBracket(i) :: number
		elseif string.match(src, "^[%a_]", i) then
			local word = string.match(src, "^[%w_]+", i) :: string
			local prev = if i > 1 then string.sub(src, i - 1, i - 1) else ""
			if word == "require" and prev ~= "." and prev ~= ":" then
				local open = string.match(src, "^require%s*()%(", i)
				if open then
					-- balanced parentheses (requires never contain parens in strings here)
					local depth, j = 0, open :: number
					while j <= n do
						local d = string.sub(src, j, j)
						if d == "(" then
							depth += 1
						elseif d == ")" then
							depth -= 1
							if depth == 0 then
								break
							end
						end
						j += 1
					end
					table.insert(out, string.sub(src, (open :: number) + 1, j - 1))
					i = j + 1
					continue
				end
			end
			i += #word
		else
			i += 1
		end
	end
	return out
end

-- Resolves a converted require expression from `script`. Returns the
-- Instance, or nil and why not.
local function resolve(script: roblox.Instance, expr: string): (roblox.Instance?, string?)
	local s = string.gsub(expr, "%s+", "")
	local cur: roblox.Instance?
	local rest: string
	if string.sub(s, 1, 6) == "script" then
		cur, rest = script, string.sub(s, 7)
	else
		local service, after = string.match(s, "^game:GetService%(['\"]([%w_]+)['\"]%)()")
		if service == nil then
			return nil, "unsupported require expression"
		end
		cur = game:FindFirstChildOfClass(service :: string) or game:FindFirstChild(service :: string)
		if cur == nil then
			return nil, `service {service} not in the place`
		end
		rest = string.sub(s, after :: number)
	end
	while rest ~= "" do
		local name, after
		if string.sub(rest, 1, 7) == ".Parent" and not string.match(rest, "^%.Parent[%w_]") then
			cur = (cur :: roblox.Instance).Parent
			rest = string.sub(rest, 8)
			if cur == nil then
				return nil, "walks above the DataModel"
			end
			continue
		end
		name, after = string.match(rest, "^:FindFirstChild%(['\"]([^'\"]+)['\"]%)()")
		if name == nil then
			name, after = string.match(rest, "^:WaitForChild%(['\"]([^'\"]+)['\"]%)()")
		end
		if name == nil then
			name, after = string.match(rest, "^%[['\"]([^'\"]+)['\"]%]()")
		end
		if name == nil then
			name, after = string.match(rest, "^%.([%a_][%w_]*)()")
		end
		if name == nil then
			return nil, `unsupported require expression near "{rest}"`
		end
		local child = (cur :: roblox.Instance):FindFirstChild(name :: string)
		if child == nil then
			return nil, `{(cur :: roblox.Instance):GetFullName()} has no child "{name}"`
		end
		cur = child
		rest = string.sub(rest, after :: number)
	end
	return cur, nil
end

local scripts, requires = 0, 0
for _, inst in game:GetDescendants() do
	if not (inst:IsA("ModuleScript") or inst:IsA("Script") or inst:IsA("LocalScript")) then
		continue
	end
	scripts += 1
	local src = (inst :: any).Source :: string
	local ok, err = pcall(luau.compile, src)
	if not ok then
		local firstLine = string.match(tostring(err), "^[^\n]*") or tostring(err)
		problem(inst, `does not compile: {firstLine}`)
	end
	for _, arg in requireCalls(src) do
		requires += 1
		local trimmed = string.gsub(arg, "^%s+", "")
		local first = string.sub(trimmed, 1, 1)
		if first == "\"" or first == "'" or first == "`" then
			problem(inst, `string require left: require({arg})`)
			continue
		end
		local target, why = resolve(inst, arg)
		if target == nil then
			problem(inst, `require({arg}): {why}`)
		elseif not target:IsA("ModuleScript") then
			problem(inst, `require({arg}) points to a {target.ClassName}, not a ModuleScript`)
		end
	end
end

if #problems > 0 then
	for _, p in problems do
		print("  FAIL " .. p)
	end
	print(`{PLACE}: {scripts} scripts, {requires} requires, {#problems} problem(s)`)
	process.exit(1)
end
print(`{PLACE}: {scripts} scripts compile, {requires} requires all resolve to ModuleScripts`)
