--!strict
-- Unit selection and control groups (guide 15.6). Pure Luau (C-7): screen
-- positions come from a projector the caller passes in (the Roblox camera,
-- or a test projection).

local World = require("./World")

local Selection = {}

Selection.CENTER_HEIGHT = 1.5 -- studs above the ground: where a unit is "pointed at"
Selection.PICK_PIXELS = 18 -- click radius around a unit's projected center
Selection.GROUPS = 9

-- (x, y, z) world → (screen x, screen y, in front of the camera)
export type Projector = (x: number, y: number, z: number) -> (number, number, boolean)

export type Selection = {
	ids: { number }, -- selection order
	set: { [number]: boolean },
	groups: { [number]: { number } },
	version: number, -- bumps on every change (the API fires `selection` on it)
}

function Selection.new(): Selection
	local groups = {}
	for n = 1, Selection.GROUPS do
		groups[n] = {}
	end
	return { ids = {}, set = {}, groups = groups, version = 0 }
end

local function isOwn(world: World.World, id: number): boolean
	local u = world.units[id]
	return u ~= nil and u.team == world.me.team
end

-- Where a unit is drawn: the renderer's interpolated position when it has
-- one, else the last known position.
function Selection.position(world: World.World, u: World.Unit): (number, number, number)
	if u.rx then
		return u.rx :: number, (u.ry :: number) + Selection.CENTER_HEIGHT, u.rz :: number
	end
	local x, z = u.sx or u.x, u.sz or u.z -- a strategic record's drawn spot (C-151)
	return x, World.groundY(world, x, z) + u.alt + Selection.CENTER_HEIGHT, z
end

-- Replaces, adds to or toggles the selection; only own units are kept.
function Selection.set(sel: Selection, world: World.World, ids: { number }, mode: ("replace" | "add" | "toggle")?)
	mode = mode or "replace"
	if mode == "replace" then
		table.clear(sel.ids)
		table.clear(sel.set)
	end
	for _, id in ids do
		if not isOwn(world, id) then
			continue
		end
		if sel.set[id] then
			if mode == "toggle" then
				sel.set[id] = nil
				table.remove(sel.ids, table.find(sel.ids, id) :: number)
			end
		else
			sel.set[id] = true
			table.insert(sel.ids, id)
		end
	end
	sel.version += 1
end

-- Drops units that died or are no longer known from the selection and the
-- groups. Returns true if the selection changed.
function Selection.prune(sel: Selection, world: World.World): boolean
	local changed = false
	for i = #sel.ids, 1, -1 do
		local id = sel.ids[i]
		if not isOwn(world, id) then
			table.remove(sel.ids, i)
			sel.set[id] = nil
			changed = true
		end
	end
	for _, group in sel.groups do
		for i = #group, 1, -1 do
			if not isOwn(world, group[i]) then
				table.remove(group, i)
			end
		end
	end
	if changed then
		sel.version += 1
	end
	return changed
end

-- Own units whose projected center is inside the screen rectangle, by ID.
function Selection.inBox(world: World.World, project: Projector, x0: number, y0: number, x1: number, y1: number): { number }
	local minX, maxX = math.min(x0, x1), math.max(x0, x1)
	local minY, maxY = math.min(y0, y1), math.max(y0, y1)
	local out = {}
	for id, u in world.units do
		if u.team ~= world.me.team then
			continue
		end
		local sx, sy, front = project(Selection.position(world, u))
		if front and sx >= minX and sx <= maxX and sy >= minY and sy <= maxY then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- The unit nearest to screen point (sx, sy) within PICK_PIXELS, any team.
function Selection.pick(world: World.World, project: Projector, sx: number, sy: number): number?
	local best, bestD = nil, Selection.PICK_PIXELS * Selection.PICK_PIXELS
	for id, u in world.units do
		local px, py, front = project(Selection.position(world, u))
		if front then
			local d = (px - sx) ^ 2 + (py - sy) ^ 2
			if d <= bestD then
				best, bestD = id, d
			end
		end
	end
	return best
end

-- Own tactical units of def `defIndex` on screen (double-click).
function Selection.sameTypeOnScreen(world: World.World, project: Projector, defIndex: number, width: number, height: number): { number }
	local out = {}
	for id, u in world.units do
		if u.team == world.me.team and u.defIndex == defIndex then
			local sx, sy, front = project(Selection.position(world, u))
			if front and sx >= 0 and sx <= width and sy >= 0 and sy <= height then
				table.insert(out, id)
			end
		end
	end
	table.sort(out)
	return out
end

-- A click on a type tile in the unit panel (C-157, BAR's selection
-- panel): "keep" only that type, "remove" it (Shift), or "screen": every
-- own unit of that type on screen (Ctrl; `onScreen` from sameTypeOnScreen).
function Selection.tileClick(world: World.World, ids: { number }, defIndex: number, how: "keep" | "remove" | "screen", onScreen: { number }?): { number }
	if how == "screen" then
		return table.clone(onScreen or {})
	end
	local out = {}
	for _, id in ids do
		local u = world.units[id]
		local same = u ~= nil and u.defIndex == defIndex
		if same == (how == "keep") then
			table.insert(out, id)
		end
	end
	return out
end

function Selection.saveGroup(sel: Selection, n: number)
	sel.groups[n] = table.clone(sel.ids)
end

-- Selects group `n` (adding with `add`); returns its IDs.
function Selection.recallGroup(sel: Selection, world: World.World, n: number, add: boolean?): { number }
	local ids = table.clone(sel.groups[n] or {})
	Selection.set(sel, world, ids, if add then "add" else "replace")
	return ids
end

-- Center of the selected units (camera jump on a double-tapped group key).
function Selection.center(world: World.World, ids: { number }): (number?, number?)
	local sx, sz, n = 0, 0, 0
	for _, id in ids do
		local u = world.units[id]
		if u then
			sx += u.rx or u.x
			sz += u.rz or u.z
			n += 1
		end
	end
	if n == 0 then
		return nil, nil
	end
	return sx / n, sz / n
end

return Selection
