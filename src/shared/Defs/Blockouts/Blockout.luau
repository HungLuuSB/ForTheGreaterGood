--!strict
-- Placeholder unit models as data (guide 20.2, docs/contracts/rig.md section 4,
-- decision C-6). Pure Luau: the client turns a Blockout into Parts and
-- Motor6Ds (src/client/Render/BlockoutBuilder); Lune checks them.
--
--   local bp = Blockout.forDef(def)       -- hand-made if registered, else generic
--   local problems = Blockout.validate(bp, def)
--
-- Positions are in model space: origin on the ground under the unit's
-- center, +Y up, forward = -Z (C-4).

local Registry = require("./Registry")

local Blockout = {}

export type Vec = { number } -- { x, y, z }
export type Shape = "box" | "wedge" | "cylinder" | "ball"
export type Color = "hull" | "dark" | "track" | "metal" | "glass" | "team" | "hazard"

export type Part = {
	name: string,
	parent: string?, -- required except for "base"
	shape: Shape,
	size: Vec,
	axis: ("x" | "y" | "z")?, -- cylinders only, default "x"
	at: Vec,
	rot: Vec?, -- degrees, Roblox Orientation order (Y, then X, then Z)
	pivot: Vec?, -- pieces only, default = at
	color: Color,
	-- an animated piece (rig.md "Animated pieces", M-27): jointed like a
	-- visual piece; the client moves it as `motion` about / along `axis`
	anim: Anim?,
}

export type Anim = { motion: string, axis: Vec, range: number? }

export type Attachment = { name: string, parent: string, at: Vec }

export type Blockout = {
	id: string,
	parts: { Part },
	attachments: { Attachment }?,
	-- pieces only the client animates (piece scripts, C-30) that the def
	-- doesn't list yet; jointed like def pieces
	visualPieces: { string }?,
}

-- Jointed pieces of a blockout for `def`: the def's and its visual pieces.
function Blockout.pieceSet(bp: Blockout, def: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, piece in def.pieces do
		set[piece] = true
	end
	for _, piece in bp.visualPieces or {} do
		set[piece] = true
	end
	for _, p in bp.parts do
		if p.anim ~= nil then
			set[p.name] = true
		end
	end
	return set
end

-- How the client may move each animated piece (rig.md "Animated pieces").
Blockout.MOTIONS = table.freeze({ spin = true, turn = true, scroll = true, slide = true, open = true, lower = true, pulse = true, swing = true })

-- name → anim for every part that carries one.
function Blockout.anims(bp: Blockout): { [string]: Anim }
	local out: { [string]: Anim } = {}
	for _, p in bp.parts do
		if p.anim ~= nil then
			out[p.name] = p.anim
		end
	end
	return out
end

-- RGB 0..255 per palette key and faction, from docs/art/style-guide.md
-- (M-15, M-16): Order light sand-grey paint with cyan accents; Chaos gunmetal
-- with orange accents. `glass` is the faction's accent (sensors, lights);
-- `hazard` is warning yellow (silo doors, M-19), the same for every faction.
Blockout.PALETTES = table.freeze({
	order = table.freeze({
		hull = { 178, 174, 160 },
		dark = { 112, 110, 102 },
		track = { 54, 54, 52 },
		metal = { 140, 140, 134 },
		glass = { 90, 210, 255 },
		team = { 210, 210, 210 },
		hazard = { 228, 184, 40 },
	}),
	chaos = table.freeze({
		hull = { 86, 90, 95 }, -- lifted with the BAR Ravager (review 2026-10-22, M-18, M-19)
		dark = { 46, 48, 52 },
		track = { 36, 36, 36 },
		metal = { 104, 108, 112 },
		glass = { 255, 140, 50 },
		team = { 210, 210, 210 },
		hazard = { 228, 184, 40 },
	}),
	neutral = table.freeze({
		hull = { 150, 150, 140 },
		dark = { 90, 90, 84 },
		track = { 50, 50, 50 },
		metal = { 120, 120, 120 },
		glass = { 160, 200, 220 },
		team = { 210, 210, 210 },
		hazard = { 228, 184, 40 },
	}),
})

local SHAPES = { box = true, wedge = true, cylinder = true, ball = true }
local AXES = { x = true, y = true, z = true }

-- Muzzles (`muzzle`, `muzzle1`, ...) are Attachments; every other name in a
-- def's `pieces` is a jointed part.
function Blockout.isAttachmentPiece(name: string): boolean
	return string.match(name, "^muzzle%d*$") ~= nil
end

local function isVec(v: any, positive: boolean): boolean
	if type(v) ~= "table" or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		local n = v[i]
		if type(n) ~= "number" or n ~= n or (positive and n <= 0) then
			return false
		end
	end
	return true
end

-- Every problem with `bp` against `def` (empty when it is valid).
function Blockout.validate(bp: Blockout, def: any): { string }
	local problems: { string } = {}
	local function bad(msg: string)
		table.insert(problems, `{bp.id}: {msg}`)
	end
	if bp.id ~= def.id then
		bad(`id doesn't match the def ({def.id})`)
	end
	local isPiece = Blockout.pieceSet(bp, def)
	for _, piece in bp.visualPieces or {} do
		if table.find(def.pieces, piece) then
			bad(`visual piece {piece} is already a def piece`)
		end
		if Blockout.isAttachmentPiece(piece) then
			bad(`visual piece {piece} can't be a muzzle`)
		end
	end

	local seen: { [string]: string } = {} -- name → "part" | "attachment"
	for i, p in bp.parts do
		local label = `part {i} ({p.name})`
		if seen[p.name] then
			bad(`{label}: name used twice`)
		end
		seen[p.name] = "part"
		if Blockout.isAttachmentPiece(p.name) then
			bad(`{label}: muzzles must be attachments`)
		end
		if not SHAPES[p.shape] then
			bad(`{label}: unknown shape {tostring(p.shape)}`)
		end
		if not isVec(p.size, true) then
			bad(`{label}: size must be three positive numbers`)
		end
		if not isVec(p.at, false) then
			bad(`{label}: at must be three numbers`)
		end
		if p.rot ~= nil and not isVec(p.rot, false) then
			bad(`{label}: rot must be three numbers`)
		end
		if p.axis ~= nil and (p.shape ~= "cylinder" or not AXES[p.axis]) then
			bad(`{label}: axis is for cylinders only, x / y / z`)
		end
		if Blockout.PALETTES.order[p.color] == nil then
			bad(`{label}: unknown color {tostring(p.color)}`)
		end
		if p.anim ~= nil then
			if p.name == "base" then
				bad(`{label}: base can't be animated`)
			elseif not Blockout.MOTIONS[p.anim.motion] then
				bad(`{label}: unknown motion {tostring(p.anim.motion)}`)
			elseif not isVec(p.anim.axis, false) then
				bad(`{label}: anim axis must be three numbers`)
			end
		end
		if p.pivot ~= nil then
			if not isPiece[p.name] then
				bad(`{label}: only pieces have a pivot`)
			elseif not isVec(p.pivot, false) then
				bad(`{label}: pivot must be three numbers`)
			end
		end
		if p.name == "base" then
			if i ~= 1 or p.parent ~= nil then
				bad(`{label}: base must be the first part and have no parent`)
			end
		elseif p.parent == nil then
			bad(`{label}: needs a parent`)
		elseif seen[p.parent] ~= "part" or p.parent == p.name then
			bad(`{label}: parent {p.parent} must be an earlier part`)
		elseif not isPiece[p.parent] then
			bad(`{label}: parent {p.parent} is a decoration, not a piece`)
		end
	end
	for i, a in bp.attachments or {} do
		local label = `attachment {i} ({a.name})`
		if seen[a.name] then
			bad(`{label}: name used twice`)
		end
		seen[a.name] = "attachment"
		if seen[a.parent] ~= "part" then
			bad(`{label}: parent {tostring(a.parent)} must be a part`)
		end
		if not isVec(a.at, false) then
			bad(`{label}: at must be three numbers`)
		end
	end
	for _, piece in def.pieces do
		local want = if Blockout.isAttachmentPiece(piece) then "attachment" else "part"
		if seen[piece] ~= want then
			bad(`def piece {piece} must be a{if want == "part" then " part" else "n attachment"}`)
		end
	end
	for _, piece in bp.visualPieces or {} do
		if seen[piece] ~= "part" then
			bad(`visual piece {piece} must be a part`)
		end
	end
	return problems
end

--------------------------------------------------------------------------------
-- Generic blockouts: a readable placeholder for any def without a hand-made
-- one, sized by footprint and shaped by domain, with every piece in place.
--------------------------------------------------------------------------------

local function add(parts: { Part }, p: Part)
	table.insert(parts, p)
end

-- The piece each muzzle hangs from: its weapon's pitch or turret piece, else
-- the last jointed piece listed before it, else base.
local function muzzleParents(def: any): { [string]: string }
	local out: { [string]: string } = {}
	local jointed: { [string]: boolean } = {}
	for _, piece in def.pieces do
		jointed[piece] = not Blockout.isAttachmentPiece(piece)
	end
	for _, slot in def.weapons or {} do
		if slot.muzzle then
			-- a slot may name a piece the def doesn't list (e.g. a bomb bay)
			local parent = slot.pitchPiece or slot.turretPiece
			if parent and jointed[parent] then
				out[slot.muzzle] = parent
			end
		end
	end
	local last = "base"
	for _, piece in def.pieces do
		if Blockout.isAttachmentPiece(piece) then
			out[piece] = out[piece] or last
		else
			last = piece
		end
	end
	return out
end

function Blockout.generic(def: any): Blockout
	local cell = 8
	local fp = def.footprint or 1
	local parts: { Part } = {}
	local domain = def.domain
	local w, l, h, y0
	if domain == "structure" then
		w, l, h, y0 = fp * cell - 1, fp * cell - 1, 2 + fp * 1.5, 0
	elseif domain == "air" then
		w, l, h, y0 = fp * cell * 0.35, fp * cell * 0.9, 1.4, 0
	elseif domain == "naval" then
		w, l, h, y0 = fp * cell * 0.45, fp * cell * 1.2, 2.2, 0
	else
		w, l, h, y0 = fp * cell * 0.65, fp * cell * 0.9, 1.6, 1.0
	end
	local top = y0 + h

	add(parts, { name = "base", shape = "box", size = { w, h, l }, at = { 0, y0 + h / 2, 0 }, color = "hull" })
	if domain == "ground" then
		for _, side in { -1, 1 } do
			add(parts, {
				name = if side < 0 then "trackL" else "trackR",
				parent = "base",
				shape = "box",
				size = { w * 0.2, y0 + 0.2, l },
				at = { side * (w / 2 + w * 0.08), (y0 + 0.2) / 2, 0 },
				color = "track",
			})
		end
	elseif domain == "air" and def.moveClass == "HELI" then
		-- tail boom, a mast and a two-blade rotor (spun by the piece script, C-31)
		add(parts, { name = "boom", parent = "base", shape = "box", size = { 0.4, 0.4, l * 0.6 }, at = { 0, h * 0.7, l * 0.75 }, color = "dark" })
		add(parts, { name = "tail", parent = "base", shape = "box", size = { 0.25, 1.2, 0.8 }, at = { 0, h * 0.7 + 0.5, l * 1.0 }, color = "team" })
		add(parts, { name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 0.8, 0.35 }, at = { 0, h + 0.4, 0 }, color = "metal" })
		if not table.find(def.pieces, "rotor") then
			add(parts, { name = "rotor", parent = "base", shape = "box", size = { l * 1.6, 0.12, 0.45 }, at = { 0, h + 0.85, 0 }, color = "dark" })
			add(parts, { name = "blade2", parent = "rotor", shape = "box", size = { 0.45, 0.12, l * 1.6 }, at = { 0, h + 0.85, 0 }, color = "dark" })
		end
	elseif domain == "air" then
		add(parts, { name = "wings", parent = "base", shape = "box", size = { l * 1.1, 0.25, l * 0.3 }, at = { 0, h / 2, l * 0.05 }, color = "dark" })
		add(parts, { name = "tail", parent = "base", shape = "box", size = { 0.25, 1.4, l * 0.2 }, at = { 0, h + 0.5, l * 0.4 }, color = "team" })
	elseif domain == "naval" then
		add(parts, { name = "bow", parent = "base", shape = "wedge", size = { w, h, l * 0.25 }, at = { 0, h / 2, -l / 2 - l * 0.125 }, color = "hull" })
	end

	-- jointed pieces stack on top of the hull, spread along it
	local jointed: { string } = {}
	for _, piece in def.pieces do
		if piece ~= "base" and not Blockout.isAttachmentPiece(piece) then
			table.insert(jointed, piece)
		end
	end
	local muzzleOf = muzzleParents(def)
	local pieceAt: { [string]: Vec } = {}
	local n = #jointed
	for i, piece in jointed do
		local z = if n == 1 then 0 else (i - (n + 1) / 2) * (l * 0.6 / n)
		local size = math.max(1.2, math.min(w, l) * (if domain == "structure" then 0.35 else 0.5))
		local isBarrel = piece == "barrel" or piece == "launcher" or piece == "rack"
		if isBarrel then
			-- hangs off the piece before it (turret), pointing forward
			local parent = jointed[i - 1] or "base"
			local pAt = pieceAt[parent] or { 0, top, 0 }
			local length = math.max(2, l * 0.45)
			add(parts, {
				name = piece,
				parent = parent,
				shape = if piece == "barrel" then "cylinder" else "box",
				axis = if piece == "barrel" then "z" else nil,
				size = if piece == "barrel" then { 0.5, 0.5, length } else { size * 0.8, size * 0.5, length * 0.6 },
				at = { pAt[1], pAt[2], pAt[3] - length / 2 - size * 0.3 },
				pivot = { pAt[1], pAt[2], pAt[3] - size * 0.3 },
				color = "metal",
			})
			pieceAt[piece] = { pAt[1], pAt[2], pAt[3] - length - size * 0.3 }
		else
			local height = if piece == "pylon" or piece == "array" then size * 1.6 else size * 0.6
			local at = { 0, top + height / 2, z }
			local color: Color = if piece == "turret" or piece == "turret1" or piece == "turret2" then "team" else "dark"
			local shape: Shape = if piece == "dish" or piece == "nano" then "cylinder" else "box"
			add(parts, {
				name = piece,
				parent = "base",
				shape = shape,
				axis = if shape == "cylinder" then "y" else nil,
				size = { size, height, size },
				at = at,
				color = color,
			})
			pieceAt[piece] = at
		end
	end

	local attachments: { Attachment } = {}
	for _, piece in def.pieces do
		if Blockout.isAttachmentPiece(piece) then
			local parent = muzzleOf[piece] or "base"
			local at = pieceAt[parent] or { 0, top, -l / 2 }
			-- barrels already store their tip; turrets and the hull use their front
			local tip = if parent == "barrel" or parent == "launcher" or parent == "rack"
				then at
				else { at[1], at[2], at[3] - math.max(w, l) * 0.3 }
			table.insert(attachments, { name = piece, parent = parent, at = tip })
		end
	end

	local visual = if domain == "air" and def.moveClass == "HELI" and not table.find(def.pieces, "rotor") then { "rotor" } else nil
	return { id = def.id, parts = parts, attachments = attachments, visualPieces = visual }
end

-- The hand-made blockout for `def` if there is one, else a generic one.
function Blockout.forDef(def: any): (Blockout, boolean)
	local bp = (Registry :: any)[def.id]
	if bp then
		return bp, true
	end
	return Blockout.generic(def), false
end

return table.freeze(Blockout)
