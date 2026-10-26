--!strict
-- Animated pieces (C-156, rig.md section 9): the Ambient layer turns
-- radars and drills while powered and stops them without power or when
-- unfinished, rolls wheels only while moving, runs a factory's gantry only
-- while it produces, and keeps windmill rotors turning.

local PieceAnim = require("../../src/client/Core/PieceAnim")
local PieceMotion = require("../../src/client/Core/PieceMotion")
local Default = require("../../src/client/Core/PieceScripts/Default")
local Registry = require("../../src/client/Core/PieceScripts/Registry")
local Bot = require("../../src/client/Core/PieceScripts/Bot")
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

	t.test("the Commander mechs' torso and head don't spin (C-172)", function()
		for _, id in { "ord_sovereign", "chs_warlord" } do
			local world = World.new(defs)
			world.me.team = 1
			world.economy = { power = { ratio = 255 } } :: any
			unit(world, 1, id)
			local s = PieceAnim.new(defs.weaponByIndex)
			PieceAnim.add(s, 1, defs.units[id], {}) -- no walk script: only Ambient moves pieces
			run(s, world, 3)
			t.equal(angle(s, 1, "torso", 2), 0, `{id}: torso still`)
			t.equal(angle(s, 1, "head", 2), 0, `{id}: head still`)
		end
	end)

	t.test("far away (LOD far), a producing factory's gantry loop still yields (C-177)", function()
		local world = World.new(defs)
		world.me.team = 1
		unit(world, 2, "chs_vehplant", { queue = { defs.units.chs_jackal.index }, queueProgress = 0.1 })
		local s = PieceAnim.new(defs.weaponByIndex)
		local u = PieceAnim.add(s, 2, defs.units.chs_vehplant, {})
		run(s, world, 0.5) -- near: the gantry loop starts
		u.lod = "far" -- the camera pulls away: turns and moves land at once
		local t0 = os.clock()
		run(s, world, 2) -- would never return if the loop didn't yield
		t.expect(os.clock() - t0 < 2, "the frames kept coming")
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
		-- the rotor's axis as the model says (models-C's tidal mesh turns it about X)
		local rotorAxis = 3
		for _, m in PieceMotion.forDef(defs.units.chs_tidal) do
			if m.piece == "rotor" then
				rotorAxis = ({ x = 1, y = 2, z = 3 })[m.axis]
			end
		end
		local m0 = angle(s, 3, "rotor", rotorAxis)
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
		t.expect(angle(s, 3, "rotor", rotorAxis) ~= m0, "the windmill turns")
	end)

	t.test("the walking bots stride, Skitter's diagonal pairs swing, the Dragon's fans turn (S-181)", function()
		local MOVING = World.State.MOVING
		for _, id in { "ord_glint", "ord_fatboy", "chs_centurion" } do
			local world = World.new(defs)
			world.me.team = 1
			local u = unit(world, 1, id, { state = MOVING })
			local s = PieceAnim.new(defs.weaponByIndex)
			PieceAnim.add(s, 1, defs.units[id], Registry.forDef(defs.units[id]))
			local swing = 0
			for _ = 1, 60 do
				run(s, world, 1 / 60)
				swing = math.max(swing, math.abs(angle(s, 1, "thighL", 1)))
			end
			t.expect(swing > math.rad(5), `{id}: the thighs swing ({math.deg(swing)}°)`)
			t.equal(angle(s, 1, "torso", 2), 0, `{id}: the torso (its turret) doesn't twist with the walk`)
			u.state = 0
			run(s, world, 1.5)
			t.expect(math.abs(angle(s, 1, "thighL", 1)) < math.rad(0.5), `{id}: at rest when stopped`)
		end
		do -- Skitter: FL with BR, FR with BL
			local world = World.new(defs)
			world.me.team = 1
			unit(world, 1, "chs_skitter", { state = MOVING })
			local s = PieceAnim.new(defs.weaponByIndex)
			PieceAnim.add(s, 1, defs.units.chs_skitter, Registry.forDef(defs.units.chs_skitter))
			run(s, world, 0.12)
			local fl, br, fr = angle(s, 1, "thighFL", 1), angle(s, 1, "thighBR", 1), angle(s, 1, "thighFR", 1)
			t.expect(math.abs(fl) > math.rad(1) and math.abs(fl - br) < 1e-6 and math.abs(fl + fr) < 1e-6, `diagonal pairs ({fl}, {br}, {fr})`)
		end
		do -- the Dragon's fans
			local world = World.new(defs)
			world.me.team = 1
			unit(world, 1, "chs_dragon", { alt = 40 })
			local s = PieceAnim.new(defs.weaponByIndex)
			PieceAnim.add(s, 1, defs.units.chs_dragon, Registry.forDef(defs.units.chs_dragon))
			run(s, world, 1)
			t.expect(angle(s, 1, "fanL", 2) ~= 0 and angle(s, 1, "fanR", 2) ~= 0, "both fans turn")
		end
		t.expect(Bot.stride(defs.units.ord_fatboy) > Bot.stride(defs.units.ord_glint), "Fatboy's strides are slower than Glint's")
	end)
end
