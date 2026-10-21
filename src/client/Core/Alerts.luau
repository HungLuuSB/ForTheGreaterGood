--!strict
-- Alerts (C-68, guide 15.7): "unit under attack" (an own unit's health
-- drops; once per zone per COOLDOWN), "structure lost" (an own structure
-- dies), "power stall" / "supply stall" (the economy's ratio below 1) and
-- "nuclear launch" (a launch warning). Newest last in `list`, at most MAX.
-- Pure Luau (C-7); UI/Alerts shows them and pings the minimap.

local World = require("./World")

local Alerts = {}

Alerts.MAX = 20
Alerts.COOLDOWN = 20 -- seconds per zone and kind
Alerts.ZONE = 400 -- studs: "under attack" alerts merge within a zone
Alerts.STALL_COOLDOWN = 30

export type Alert = { kind: string, text: string, x: number, z: number, time: number }

export type State = {
	list: { Alert },
	health: { [number]: number }, -- own unit → last health seen
	lastAt: { [string]: number }, -- kind:zone → time of its last alert
	warned: { [any]: boolean }, -- launch warnings already announced
}

function Alerts.new(): State
	return { list = {}, health = {}, lastAt = {}, warned = setmetatable({}, { __mode = "k" }) :: any }
end

local function push(a: State, out: { Alert }, kind: string, text: string, x: number, z: number, now: number, key: string, cooldown: number)
	local last = a.lastAt[key]
	if last and now - last < cooldown then
		return
	end
	a.lastAt[key] = now
	local alert = { kind = kind, text = text, x = x, z = z, time = now }
	table.insert(a.list, alert)
	if #a.list > Alerts.MAX then
		table.remove(a.list, 1)
	end
	table.insert(out, alert)
end

-- New alerts this frame. Call before the frame clears `world.died`.
-- `warnings`: Core/Effects' launch warnings; `economy`: the Api's state.economy.
function Alerts.step(a: State, world: World.World, now: number, warnings: { any }?, economy: any?): { Alert }
	local out: { Alert } = {}
	local me = world.me.team
	for id, u in world.units do
		if u.team ~= me then
			continue
		end
		local h = u.health
		local before = a.health[id]
		if h and before and h < before - 1e-6 then
			local def = World.def(world, u)
			local structure = def ~= nil and def.domain == "structure"
			local zone = `{math.floor(u.x / Alerts.ZONE)},{math.floor(u.z / Alerts.ZONE)}`
			push(a, out, "attack", if structure then "Structure under attack" else "Unit under attack", u.x, u.z, now, "attack:" .. zone, Alerts.COOLDOWN)
		end
		if h then
			a.health[id] = h
		end
	end
	for _, d in world.died do
		a.health[d.id] = nil
		if d.team == me and d.defIndex then
			local def = world.defs.unitByIndex[d.defIndex]
			if def and def.domain == "structure" then
				push(a, out, "lost", `Structure lost: {def.name}`, d.x, d.z, now, `lost:{d.id}:{d.tick}`, 0)
			end
		end
	end
	if economy then
		for _, r in { { "power", economy.power }, { "supply", economy.supply } } do
			local res = r[2]
			if res and res.ratio < 0.999 then
				local x, z = 0, 0
				push(a, out, "stall", if r[1] == "power" then "Power stall" else "Supply stall", x, z, now, "stall:" .. r[1], Alerts.STALL_COOLDOWN)
			end
		end
	end
	for _, w in warnings or {} do
		if not a.warned[w] then
			a.warned[w] = true
			push(a, out, "nuke", "Nuclear launch detected", w.x, w.z, now, `nuke:{w.projId}:{w.born}`, 0)
		end
	end
	return out
end

-- The newest alert with a place to jump to, or nil.
function Alerts.last(a: State): Alert?
	for i = #a.list, 1, -1 do
		local al = a.list[i]
		if al.kind ~= "stall" then
			return al
		end
	end
	return nil
end

return Alerts
