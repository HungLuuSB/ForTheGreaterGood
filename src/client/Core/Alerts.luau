--!strict
-- Alerts (C-68, guide 15.7; from the server since C-85): the server's ALERT
-- events (protocol 23, S-68: owner only, rate-limited on the server) as
-- lines for the alert feed and minimap pings. Newest last in `list`, at
-- most MAX. The client used to work them out itself (health drops, deaths,
-- the economy, launch warnings); the server's are exact and fog-safe.
-- Pure Luau (C-7); UI/AlertFeed shows them.

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Alerts = {}

Alerts.MAX = 20

export type Alert = { kind: string, text: string, x: number, z: number, time: number, at: boolean }

export type State = { list: { Alert } }

local AK = Schema.AlertKind
-- server kind → the feed's kind (its colour) and text; `place` alerts have a spot to jump to
local KINDS: { [number]: { kind: string, text: string, place: boolean } } = {
	[AK.UNIT_ATTACKED] = { kind = "attack", text = "Unit under attack", place = true },
	[AK.STRUCTURE_ATTACKED] = { kind = "attack", text = "Structure under attack", place = true },
	[AK.COMMANDER_ATTACKED] = { kind = "commander", text = "Command Vehicle under attack", place = true },
	[AK.UNIT_LOST] = { kind = "lost", text = "Unit lost", place = true },
	[AK.STRUCTURE_LOST] = { kind = "lost", text = "Structure lost", place = true },
	[AK.BUILD_DONE] = { kind = "built", text = "Construction complete", place = true },
	[AK.STALL_SUPPLY] = { kind = "stall", text = "Supply stall", place = false },
	[AK.STALL_POWER] = { kind = "stall", text = "Power stall", place = false },
	[AK.NUKE_LAUNCH] = { kind = "nuke", text = "Nuclear launch detected", place = true },
}

function Alerts.new(): State
	return { list = {} }
end

-- New alerts this frame, from the server's ALERT events.
function Alerts.step(a: State, world: World.World, now: number): { Alert }
	local out: { Alert } = {}
	for _, e in world.alertQueue do
		local k = KINDS[e.kind]
		if k == nil then
			continue
		end
		local def = if e.defIndex > 0 then world.defs.unitByIndex[e.defIndex] else nil
		local text = if def and k.kind ~= "nuke" then `{k.text}: {def.name}` else k.text
		local alert = { kind = k.kind, text = text, x = e.x, z = e.z, time = now, at = k.place }
		table.insert(a.list, alert)
		if #a.list > Alerts.MAX then
			table.remove(a.list, 1)
		end
		table.insert(out, alert)
	end
	table.clear(world.alertQueue)
	return out
end

-- The newest alert with a place to jump to, or nil.
function Alerts.last(a: State): Alert?
	for i = #a.list, 1, -1 do
		local al = a.list[i]
		if al.at then
			return al
		end
	end
	return nil
end

return Alerts
