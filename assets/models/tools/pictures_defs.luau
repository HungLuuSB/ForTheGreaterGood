--!strict
-- Input for the build-menu unit pictures (E-11, assets/models/tools/pictures.py):
-- every non-retired unit def with its approved mesh and the setting its picture
-- stands it in. Run from the project root:
--     lune run assets/models/tools/pictures_defs.luau
-- Writes debug_out/pictures/defs.json.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Defs = require("../../../src/shared/Defs/Defs")
local MoveClasses = require("../../../src/shared/Defs/MoveClasses")
local Meshes = require("../../../src/shared/Defs/Meshes/Registry")

local OUT = "debug_out/pictures"

-- The picture's setting, after the client's PortraitStage.kind, with ships,
-- subs, jets, helicopters and walkers apart.
local function setting(d: any): string
	local mc = d.moveClass and (MoveClasses :: any)[d.moveClass]
	local surface = mc and mc.surface
	if d.domain == "air" or surface == "air" then
		return if d.moveClass == "JET" then "jet" else "heli"
	elseif d.moveClass == "SUB" or d.placement == "seafloor" then
		return "sub"
	elseif d.domain == "structure" then
		return if d.placement == "water" then "sea_structure" else "structure"
	elseif d.domain == "naval" or surface == "water" then
		return "ship"
	elseif surface == "amphib" or surface == "hover" then
		return "shore"
	end
	return if d.moveClass == "WALKER" then "bot" else "ground"
end

local set = Defs.load()
local rows = {}
local missing = {}
for _, d in set.unitByIndex do
	if d.retired then
		continue
	end
	local model = d.model or d.id
	local m = (Meshes :: any).units[model]
	if not (m and m.status == "approved") then
		table.insert(missing, d.id)
		continue
	end
	table.insert(rows, {
		id = d.id,
		model = model,
		name = d.name,
		faction = d.faction,
		domain = d.domain,
		tier = d.tier or 0,
		footprint = d.footprint or 1,
		moveClass = d.moveClass,
		setting = setting(d),
	})
end
table.sort(rows, function(a, b)
	return a.id < b.id
end)

if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end
fs.writeFile(OUT .. "/defs.json", serde.encode("json", rows, true))
local counts = {}
for _, r in rows do
	counts[r.setting] = (counts[r.setting] or 0) + 1
end
local parts = {}
for k, n in counts do
	table.insert(parts, `{k} {n}`)
end
table.sort(parts)
print(`{#rows} defs -> {OUT}/defs.json ({table.concat(parts, ", ")})`)
if #missing > 0 then
	print(`no approved mesh (skipped): {table.concat(missing, ", ")}`)
end
