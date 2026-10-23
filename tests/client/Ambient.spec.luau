--!strict
-- Animated pieces (C-156, rig.md section 9): the Ambient layer turns
-- radars and drills while powered and stops them without power or when
-- unfinished, rolls wheels only while moving, runs a factory's gantry only
-- while it produces, and keeps windmill rotors turning.

local PieceAnim = require("../../src/client/Core/PieceAnim")
local PieceMotion = require("../../src/client/Core/PieceMotion")
local Default = require("../../src/client/Core/PieceScripts/Default")
local World = require("../../src/client/Core/World")
local Defs = require("@shared/Defs/Defs")

local defs = Defs.load()

local function unit(world: any, id: number, defId: string, fields: any?): any
	local def = assert(defs.units[defId], defId)
	local u: any = { id = id, tier = "tactical", team = 1, defIndex = def.index, x = 0, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {}, build = 1 }
	for k, v in fields or {} do
		u[k] = v
	end
	world.units[id] = u
	return u
end

local function run(s: any, world: any, seconds: number)
	for _ = 1, math.floor(seconds * 60) do
		PieceAnim.drive(s, world, {})
		PieceAnim.step(s, 1 / 60)
	end
end

local function angle(s: any, id: number, piece: string, axis: number): number
	local p = s.units[id].pieces[piece]
	return if p then p.rot[axis] else 0
end

local function offset(s: any, id: number, piece: string, axis: number): number
	local p = s.units[id].pieces[piece]
	return if p then p.pos[axis] else 0
end

return function(t: any)
	t.test("every animated piece names a known motion and a model axis", function()
		local n = 0
		local known = { spin = true, turn = true, scroll = true, slide = true, open = true, lower = true, pulse = true, swing = true }
		for _, def in defs.unitByIndex do
			for _, m in PieceMotion.forDef(def) do
				n += 1
				t.expect(known[m.motion], `{def.id}.{m.piece}: {m.motion}`)
				t.expect(m.axis == "x" or m.axis == "y" or m.axis == "z")
			end
		end
		t.expect(n > 100, `animated pieces found ({n})`)
	end)

	t.test("radars and drills turn while powered, stop without power or unfinished", function()
		local world = World.new(defs)
		world.me.team = 1
		world.economy = { power = { ratio = 255 } } :: any
		unit(world, 1, "chs_airfield") -- radar on its tower
		unit(world, 2, "chs_advextractor") -- drill
		unit(world, 3, "chs_advextractor", { build = 0.5 }) -- still a frame
		local s = PieceAnim.new(defs.weaponByIndex)
		for id = 1, 3 do
			PieceAnim.add(s, id, defs.unitByIndex[world.units[id].defIndex], Default)
		end
		run(s, world, 3)
		local r0, d0, f0 = angle(s, 1, "radar", 2), angle(s, 2, "drill", 2), angle(s, 3, "drill", 2)
		run(s, world, 1)
		t.expect(math.abs(angle(s, 1, "radar", 2) - r0) > math.rad(30), "the radar sweeps")
		t.expect(math.abs(angle(s, 2, "drill", 2) - d0) > math.rad(90), "the drill turns")
		t.equal(angle(s, 3, "drill", 2), f0, "an unfinished extractor's drill stays still")
		world.economy.power.ratio = 0 -- out of power
		run(s, world, 3) -- winds down
		local r1 = angle(s, 1, "radar", 2)
		run(s, world, 1)
		t.expect(math.abs(angle(s, 1, "radar", 2) - r1) < 1e-6, "no power: the radar stops")
	end)

	t.test("wheels roll only while moving; a gantry runs only while producing; windmills always turn", function()
		local world = World.new(defs)
		world.me.team = 1
		local wheels = unit(world, 1, "chs_condor")
		unit(world, 2, "chs_vehplant")
		unit(world, 3, "chs_tidal")
		local s = PieceAnim.new(defs.weaponByIndex)
		for id = 1, 3 do
			PieceAnim.add(s, id, defs.unitByIndex[world.units[id].defIndex], Default)
		end
		run(s, world, 1)
		local w0 = angle(s, 1, "wheelL", 1)
		run(s, world, 1)
		t.equal(angle(s, 1, "wheelL", 1), w0, "parked: wheels still")
		t.expect(offset(s, 2, "trolley", 3) == 0, "idle factory: the gantry rests")
		local m0 = angle(s, 3, "rotor", 3)
		-- moving and producing
		local origMoving = World.moving
		;(World :: any).moving = function(_w: any, u: any): boolean
			return u == wheels
		end
		world.units[2].queue = { defs.units.chs_jackal.index }
		world.units[2].queueProgress = 0.2
		run(s, world, 2)
		;(World :: any).moving = origMoving
		t.expect(angle(s, 1, "wheelL", 1) ~= w0, "moving: wheels roll")
		t.expect(math.abs(offset(s, 2, "trolley", 3)) > 0.5, "producing: the gantry runs")
		t.expect(angle(s, 3, "rotor", 3) ~= m0, "the windmill turns")
	end)
end
