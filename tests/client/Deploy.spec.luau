--!strict
-- S-64's faction units on the client (C-84): the Warden's piece script
-- follows the server's deploy phases (unpacking when it stands still,
-- deployed, packing before it drives off, packed) with its spades, and the
-- Minotaur's ram strikes on a demolition charge (weapon slot 2).

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local PieceAnim = require("../../src/client/Core/PieceAnim")
local Registry = require("../../src/client/Core/PieceScripts/Registry")
local Warden = require("../../src/client/Core/PieceScripts/ord_warden")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("the Warden's spades follow the server's unpack, deploy and pack", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local id = Spawn.unit(sim, "ord_warden", 1, 0, 0, 0)
		local s = PieceAnim.new(sim.defs.weaponByIndex)
		local phases: { string } = {}
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				if s.units[id] == nil and world.units[id] then
					local def = sim.defs.units.ord_warden
					PieceAnim.add(s, id, def, Registry.forDef(def))
				end
				local u = s.units[id]
				PieceAnim.drive(s, world, {})
				PieceAnim.step(s, DT)
				if u and phases[#phases] ~= u.deploy then
					table.insert(phases, u.deploy)
				end
			end
		end
		local function spades(): number
			local p = s.units[id].pieces.spades
			return if p then math.deg(p.rot[1]) else 0
		end
		step(15 * 6) -- standing still: it unpacks (4 s) and deploys
		t.equal(Registry.forDef(sim.defs.units.ord_warden), Warden)
		t.expect(bit32.band(sim.world.state[id], Schema.UnitState.DEPLOYED) ~= 0, "the server deployed it")
		t.equal(s.units[id].deploy, "deployed")
		t.expect(math.abs(spades() - Warden.SPADE_ANGLE) < 1, `spades down ({spades()})`)
		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.MOVE, { id }, 0, 150)))
		step(15 * 6) -- packs (4 s), then drives off
		t.equal(s.units[id].deploy, "packed")
		t.expect(math.abs(spades()) < 1, `spades up ({spades()})`)
		local seq = table.concat(phases, " ")
		t.expect(string.find(seq, "unpacking deployed packing packed", 1, true) ~= nil, `phases in order: {seq}`)
	end)

	t.test("the Minotaur's ram strikes on a demolition charge, not on its gun", function()
		local s = PieceAnim.new({})
		local def = { id = "chs_minotaur", weapons = { { pitchPiece = "barrel" }, { turretPiece = "ram" } } }
		PieceAnim.add(s, 1, def, Registry.forDef({ id = "chs_minotaur" }))
		local world: any = { units = { [1] = { state = 0, weapon = 0, aim = {} } }, latestTick = 0 }
		PieceAnim.drive(s, world, { { 1, 1 } })
		PieceAnim.step(s, 1 / 60)
		local ram = s.units[1].pieces.ram
		t.expect(ram == nil or ram.pos[3] == 0, "the gun's shot leaves the ram")
		PieceAnim.drive(s, world, { { 1, 2 } })
		for _ = 1, 4 do
			PieceAnim.step(s, 1 / 60)
		end
		ram = s.units[1].pieces.ram
		t.expect(ram ~= nil and ram.pos[3] < -0.5, "the demolition charge drives the ram forward")
		for _ = 1, 120 do
			PieceAnim.step(s, 1 / 60)
		end
		t.expect(math.abs(s.units[1].pieces.ram.pos[3]) < 1e-6, "and draws it back")
	end)
end
