--!strict
-- Out-of-sight things to draw in the world (guide 11.3, C-32):
--   * ghosts: structures seen before, now out of sight (strategic records
--     with the GHOST flag). A record only carries an icon and an 8-stud
--     cell, so the client remembers each structure's def, position and
--     heading while it is tactical and draws the ghost from that memory;
--     a structure never seen up close gets its icon's sample def at the
--     record's position;
--   * contacts: radar and sonar blips (RADAR_ONLY / SONAR_ONLY records) at
--     their wobbled position.
-- Pure Luau (C-7); Render/Contacts draws them.

local Schema = require("@shared/Net/Schema")
local Icons = require("./Icons")
local World = require("./World")

local Ghosts = {}

Ghosts.MATCH = 12 -- studs: a memory this close to the record's cell is the same structure

local SF = Schema.StrategicFlag

export type Memory = { defIndex: number, x: number, z: number, heading: number }
export type Ghost = { id: number, def: any, x: number, z: number, heading: number, team: number, exact: boolean }
export type Contact = { id: number, x: number, z: number, team: number, sonar: boolean }

export type State = { memory: { [number]: Memory }, icons: Icons.Table? }

function Ghosts.new(): State
	return { memory = {}, icons = nil }
end

-- Remembers every tactical structure (call each frame; cheap: structures only).
function Ghosts.remember(g: State, world: World.World)
	for id, u in world.units do
		if u.tier == "tactical" and u.defIndex then
			local def = World.def(world, u)
			if def and def.domain == "structure" then
				local m = g.memory[id]
				if m == nil then
					g.memory[id] = { defIndex = u.defIndex :: number, x = u.x, z = u.z, heading = u.heading }
				else
					m.defIndex, m.x, m.z, m.heading = u.defIndex :: number, u.x, u.z, u.heading
				end
			end
		end
	end
	for _, d in world.died do
		g.memory[d.id] = nil
	end
end

-- Ghosts and contacts in the world now.
function Ghosts.list(g: State, world: World.World): ({ Ghost }, { Contact })
	g.icons = g.icons or Icons.table(world.defs)
	local ghosts, contacts = {}, {}
	for id, u in world.units do
		if u.tier == "tactical" then
			continue
		end
		local flags = u.flags or 0
		if bit32.band(flags, SF.GHOST) ~= 0 then
			local m = g.memory[id]
			if m and (m.x - u.x) ^ 2 + (m.z - u.z) ^ 2 <= Ghosts.MATCH ^ 2 then
				table.insert(ghosts, { id = id, def = world.defs.unitByIndex[m.defIndex], x = m.x, z = m.z, heading = m.heading, team = u.team, exact = true })
			elseif u.icon and u.icon > 0 then
				local def = (g.icons :: Icons.Table).sample[u.icon]
				if def then
					table.insert(ghosts, { id = id, def = def, x = u.x, z = u.z, heading = 0, team = u.team, exact = false })
				end
			end
		elseif bit32.band(flags, SF.RADAR_ONLY + SF.SONAR_ONLY) ~= 0 then
			table.insert(contacts, { id = id, x = u.sx or u.x, z = u.sz or u.z, team = u.team, sonar = bit32.band(flags, SF.SONAR_ONLY) ~= 0 })
		end
	end
	table.sort(ghosts, function(a, b)
		return a.id < b.id
	end)
	table.sort(contacts, function(a, b)
		return a.id < b.id
	end)
	return ghosts, contacts
end

return Ghosts
