--!strict
-- Sharing between allies (S-176, the user's playtest F23): giving units,
-- giving supply or power, and asking the allies for help. Only between
-- players of one ally team, both still in the match.
--
--   * Units: complete units the giver owns, never a Commander (S-175: the
--     ally team's Commanders keep it in the match). A given unit is
--     re-made for the receiver where it stands, with its health, heading
--     and missile stock: a new unit ID, no orders, factory queues dropped.
--     Aircraft are re-made flying.
--   * Resources: up to what the giver may still spend this window
--     (Economy.allowance); counted as spent by the giver and credited to
--     the receiver at the window's settle (as reclaim is), so neither store
--     goes negative and the receiver's overflow goes on to its allies.
--   * Requests: nothing changes; a SHARE event tells the ally team.
--
-- Every gift and request is a SHARE event for the giver's ally team and
-- spectators (NetOut). `sim.share` holds this tick's events; not hashed.

local Categories = require("@shared/Defs/Categories")
local Schema = require("@shared/Net/Schema")
local Economy = require("./Economy")
local Lifecycle = require("./Lifecycle")
local Spawn = require("./Spawn")
local Types = require("./Types")
local World = require("./World")

local Share = {}

local SK = Schema.ShareKind
local COMMANDER = Categories.Bit.COMMANDER

export type Event = { from: number, to: number, kind: number, amount: number }
export type State = { events: { Event } } -- this tick's

function Share.new(): State
	return { events = {} }
end

-- Clears last tick's events (Commands, at the start of a tick).
function Share.clear(sim: Types.Sim)
	table.clear(sim.share.events)
end

local function allies(sim: Types.Sim, a: number, b: number): boolean
	local pa, pb = sim.players[a], sim.players[b]
	return a ~= b and pa ~= nil and pb ~= nil and pa.allyTeam == pb.allyTeam and sim.match.eliminated[a] == nil and sim.match.eliminated[b] == nil
end

-- Gives `ids` (owned by `from`) to ally `to`. Returns the new unit IDs.
function Share.giveUnits(sim: Types.Sim, from: number, to: number, ids: { number }): { number }
	local out = {}
	if not allies(sim, from, to) then
		return out
	end
	local w = sim.world
	for _, id in ids do
		if w.owner[id] ~= from or w.buildProgress[id] < 1 or w.health[id] <= 0 then
			continue
		end
		local def = sim.defs.unitByIndex[w.defIndex[id]]
		if bit32.band(def.categoryMask, COMMANDER) ~= 0 then
			continue
		end
		local x, z, heading, health = w.posX[id], w.posZ[id], w.heading[id], w.health[id]
		local stock = {}
		for slot = 1, #def.weapons do
			stock[slot] = w.wStock[World.slotKey(id, slot)]
		end
		local state = w.state[id]
		Lifecycle.remove(sim, id)
		local nid = Spawn.unit(sim, def.id, to, x, z, heading)
		World.setHealth(w, nid, health)
		for slot, n in stock do
			w.wStock[World.slotKey(nid, slot)] = n
		end
		-- keep the switches (on / off, low priority); the rest is the unit's own
		local keep = bit32.bor(World.State.TOGGLED_ON, World.State.LOW_PRIORITY)
		World.setState(w, nid, bit32.bor(bit32.band(w.state[nid], bit32.bnot(keep)), bit32.band(state, keep)))
		table.insert(out, nid)
	end
	if #out > 0 then
		table.insert(sim.share.events, { from = from, to = to, kind = SK.UNITS, amount = #out })
	end
	return out
end

-- Gives up to `amount` of `kind` (SK.SUPPLY / SK.POWER) to ally `to`.
-- Returns what was given.
function Share.giveResource(sim: Types.Sim, from: number, to: number, kind: number, amount: number): number
	if not allies(sim, from, to) or (kind ~= SK.SUPPLY and kind ~= SK.POWER) then
		return 0
	end
	local res = if kind == SK.SUPPLY then "supply" else "power"
	local fromTeam, toTeam = sim.players[from].team, sim.players[to].team
	if fromTeam == toTeam then
		return 0
	end
	local giver = sim.eco.accounts[fromTeam][res]
	local receiver = sim.eco.accounts[toTeam][res]
	local give = math.min(amount, Economy.allowance(giver))
	if give <= 0 then
		return 0
	end
	giver.spent += give
	receiver.reclaimed += give
	table.insert(sim.share.events, { from = from, to = to, kind = kind, amount = math.floor(give + 0.5) })
	return give
end

-- `from` asks its allies for units, supply or power (SK.ASK_*).
function Share.request(sim: Types.Sim, from: number, kind: number)
	if kind ~= SK.ASK_UNITS and kind ~= SK.ASK_SUPPLY and kind ~= SK.ASK_POWER then
		return
	end
	if sim.players[from] == nil or sim.match.eliminated[from] ~= nil then
		return
	end
	table.insert(sim.share.events, { from = from, to = 0, kind = kind, amount = 0 })
end

return Share
