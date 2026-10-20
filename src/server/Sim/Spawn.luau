--!strict
-- Spawning units from defs: the one place that turns a def into World fields
-- (health, weapon slots). Used by scenarios, tests and (later) construction.

local Air = require("./Air")
local Lifecycle = require("./Lifecycle")
local Placement = require("./Placement")
local Types = require("./Types")
local World = require("./World")

local Spawn = {}

-- Spawns a complete `defId` unit for player `owner` at (x, z). Returns the
-- unit ID. Structures snap to the grid and occupy their footprint (no
-- placement check: scenarios and tests place them deliberately). Structures
-- under construction come from Build, not from here.
function Spawn.unit(sim: Types.Sim, defId: string, owner: number, x: number, z: number, heading: number?): number
	local def = sim.defs.units[defId]
	if def == nil then
		error(`Spawn.unit: unknown def "{defId}"`, 2)
	end
	local player = sim.players[owner]
	if player == nil then
		error(`Spawn.unit: unknown player {owner}`, 2)
	end
	if def.domain == "structure" and sim.map then
		local _, _, cx, cz = Placement.snap(sim.map.grid, def.footprint, x, z)
		x, z = cx, cz
	end
	local id = World.spawn(sim.world, sim.tick, {
		defIndex = def.index,
		team = player.team,
		owner = owner,
		x = x,
		z = z,
		heading = heading,
		health = def.health,
		weaponCount = #def.weapons,
	})
	if def.domain == "structure" then
		Placement.occupy(sim, id)
	end
	Air.onSpawn(sim, id)
	if def.moveClass == "SUB" then
		World.setState(sim.world, id, bit32.bor(sim.world.state[id], World.State.SUBMERGED)) -- always submerged (guide 12.3)
	end
	Lifecycle.added(sim, id)
	return id
end

return Spawn
