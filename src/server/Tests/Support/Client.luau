--!strict
-- A headless "client" for tests: decodes one player's messages and rebuilds
-- its view of the world, the way the Roblox client will (guide 7.4, 15.1).
-- It only ever learns what the server sent.

local Grid = require("@shared/Grid/Grid")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local Client = {}

export type Unit = {
	tier: "tactical" | "strategic",
	team: number,
	defIndex: number?, -- tactical units only
	icon: number?, -- strategic records
	flags: number?, -- strategic records
	x: number,
	z: number,
	heading: number?,
	health: number?,
	build: number?,
	state: number?,
}

export type View = {
	grid: Grid.Grid,
	units: { [number]: Unit },
	strategicTick: number, -- wire tick of the current strategic snapshot
	received: { [number]: boolean }, -- every unit ID ever mentioned
	log: { { channel: string, ids: { number } } }, -- this tick's mentions, for checks
}

function Client.new(grid: Grid.Grid): View
	return { grid = grid, units = {}, strategicTick = -1, received = {}, log = {} }
end

local function mention(view: View, channel: string, ids: { number })
	for _, id in ids do
		view.received[id] = true
	end
	table.insert(view.log, { channel = channel, ids = ids })
end

-- Applies every message the server put in this player's outbox this tick.
function Client.receive(view: View, outbox: { [string]: { buffer } })
	table.clear(view.log)
	local g = view.grid
	for _, msg in outbox.Events do
		local events = Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)
		local ids, leaves = {}, {}
		for _, e in events do
			if e.kind == Schema.EventKind.LEAVE then
				-- LEAVE carries no information: the client already had the unit
				assert(view.units[e.unitId] ~= nil, `LEAVE for unit {e.unitId} the client never had`)
				table.insert(leaves, e.unitId)
			else
				table.insert(ids, e.unitId)
			end
			if e.kind == Schema.EventKind.ENTER then
				local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
				view.units[e.unitId] = {
					tier = "tactical",
					team = e.team :: number,
					defIndex = e.defIndex,
					x = x,
					z = z,
					heading = e.heading,
					health = e.health,
					build = e.build,
					state = e.state,
				}
			elseif e.kind == Schema.EventKind.LEAVE then
				local u = view.units[e.unitId]
				if u then
					u.tier = "strategic" -- refreshed or dropped by the next strategic snapshot
				end
			else
				view.units[e.unitId] = nil
			end
		end
		mention(view, "Events", ids)
		mention(view, "Leave", leaves)
	end
	for _, msg in outbox.Tactical do
		local records = Packer.readAll(msg, Schema.decodeTactical, Schema.decodeTickHeader)
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local u = view.units[r.unitId]
			assert(u and u.tier == "tactical", `tactical record for unit {r.unitId} that never entered`)
			u.x, u.z = g:decode(r.cell, r.offX, r.offZ)
			u.heading = r.heading
		end
		mention(view, "Tactical", ids)
	end
	for _, msg in outbox.State do
		local records = Packer.readAll(msg, Schema.decodeState, Schema.decodeTickHeader)
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local u = view.units[r.unitId]
			assert(u and u.tier == "tactical", `state record for unit {r.unitId} that never entered`)
			u.health = r.health or u.health
			u.build = r.build or u.build
			u.state = r.state or u.state
		end
		mention(view, "State", ids)
	end
	for _, msg in outbox.Strategic do
		local records, tick = Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeTickHeader)
		if tick ~= view.strategicTick then
			-- a new snapshot replaces every non-tactical unit
			view.strategicTick = tick :: number
			for id, u in view.units do
				if u.tier ~= "tactical" then
					view.units[id] = nil
				end
			end
		end
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local x, z = g:decode(r.cell, 128, 128) -- cell center
			view.units[r.unitId] = { tier = "strategic", team = r.team, icon = r.icon, flags = r.flags, x = x, z = z }
		end
		mention(view, "Strategic", ids)
	end
end

return Client
