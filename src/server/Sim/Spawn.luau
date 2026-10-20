--!strict
-- Spawning units from defs: the one place that turns a def into World fields
-- (health, weapon slots). Used by scenarios, tests and (later) construction.

local Types = require("./Types")
local World = require("./World")

local Spawn = {}

-- Spawns a `defId` unit for player `owner` at (x, z). Returns the unit ID.
function Spawn.unit(sim: Types.Sim, defId: string, owner: number, x: number, z: number, heading: number?): number
	local def = sim.defs.units[defId]
	if def == nil then
		error(`Spawn.unit: unknown def "{defId}"`, 2)
	end
	local player = sim.players[owner]
	if player == nil then
		error(`Spawn.unit: unknown player {owner}`, 2)
	end
	return World.spawn(sim.world, sim.tick, {
		defIndex = def.index,
		team = player.team,
		owner = owner,
		x = x,
		z = z,
		heading = heading,
		health = def.health,
		weaponCount = #def.weapons,
	})
end

return Spawn
