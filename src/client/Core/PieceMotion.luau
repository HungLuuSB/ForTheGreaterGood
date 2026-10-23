--!strict
-- Animated pieces (docs/contracts/rig.md section 9, models-C's M-27; C-156):
-- which pieces of a unit type move on their own, from the blockout's part
-- `anim` and the mesh manifest's `anim` (the mesh wins on a name both
-- have; piece names are the same in both), and the state that drives them
-- (PieceScripts/Ambient): moving, switched on, powered, built, producing,
-- landed. Pure Luau (C-7).

local Blockout = require("@shared/Defs/Blockouts/Blockout")
local Meshes = require("@shared/Defs/Meshes/Registry")
local Schema = require("@shared/Net/Schema")

local PieceMotion = {}

export type Motion = {
	piece: string,
	motion: string, -- spin, turn, scroll, slide, open, lower, pulse, swing
	axis: "x" | "y" | "z", -- the model axis it turns about or slides along
	sign: number, -- +1 or -1: the axis' direction (positive = forward / opening)
	range: number?,
}

export type Mode = {
	moving: boolean,
	power: number, -- 0 (off, stalled or unbuilt) or 0.25..1: how hard powered pieces run
	producing: boolean,
	landed: boolean,
}

local AXES = { "x", "y", "z" }

local function axisOf(v: { number }): ("x" | "y" | "z", number)
	local best, sign = 1, 1
	for i = 1, 3 do
		if math.abs(v[i]) > math.abs(v[best]) then
			best = i
		end
	end
	sign = if v[best] < 0 then -1 else 1
	return AXES[best] :: any, sign
end

local cache: { [string]: { Motion } } = {}

-- The animated pieces of `def`, sorted by name (the same order every run).
function PieceMotion.forDef(def: any): { Motion }
	local found = cache[def.id]
	if found then
		return found
	end
	local byName: { [string]: any } = {}
	local ok, bp = pcall(Blockout.forDef, def)
	if ok and bp then
		for name, a in Blockout.anims(bp) do
			byName[name] = a
		end
	end
	local entry = (Meshes :: any).units[def.id]
	for name, a in (entry and entry.anim) or {} do
		byName[name] = a
	end
	local list: { Motion } = {}
	for name, a in byName do
		local axis, sign = axisOf(a.axis or { 0, 1, 0 })
		table.insert(list, { piece = name, motion = a.motion, axis = axis, sign = sign, range = a.range })
	end
	table.sort(list, function(x, y)
		return x.piece < y.piece
	end)
	cache[def.id] = list
	return list
end

-- How hard powered pieces run: 0 when switched off (converters, beam
-- towers: TOGGLED_ON clear), unfinished or with no power; else the power
-- ratio in quarters (own team's stall ratio; others count as powered), so
-- a small change in the ratio doesn't restart the pieces.
function PieceMotion.power(def: any, state: number, build: number?, ratio: number): number
	if (build or 1) < 1 then
		return 0
	end
	if (def.converter or def.retract) and bit32.band(state, Schema.UnitState.TOGGLED_ON) == 0 then
		return 0
	end
	if ratio <= 0.05 then
		return 0
	end
	return math.clamp(math.ceil(ratio * 4) / 4, 0.25, 1)
end

-- A number that changes exactly when the Ambient script must re-plan (no
-- allocation: it's checked every frame for every drawn unit).
function PieceMotion.key(moving: boolean, power: number, producing: boolean, landed: boolean): number
	return (if moving then 1 else 0) + math.floor(power * 4 + 0.5) * 2 + (if producing then 16 else 0) + (if landed then 32 else 0)
end

return PieceMotion
