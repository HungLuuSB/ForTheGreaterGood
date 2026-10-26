--!strict
-- Leg kit for the walking bots (S-181, moveClass WALKER): two legs as client
-- pieces `leg_l` / `leg_r` (each blockout lists them in `visualPieces`, so
-- the client can swing them, C-30), jointed at the hip under `base` (the
-- pelvis). Each leg is a thigh (the piece itself) carrying a knee, a shin and
-- a foot. A library like Scale.luau, not a blockout. Model space, forward = -Z.

local Bots = {}

export type LegOptions = {
	hipY: number, -- hip height
	hipX: number, -- hip offset either side
	thick: number, -- thigh width
	color: string, -- thigh / shin color
	foot: string?, -- foot color (default "dark")
	knee: string?, -- knee color (default "metal")
	team: boolean?, -- a team stripe down each thigh
}

function Bots.legs(parts: { any }, o: LegOptions): { string }
	local kneeY = o.hipY * 0.5
	local t = o.thick
	for _, side in { "l", "r" } do
		local sx = if side == "l" then -1 else 1
		local x = sx * o.hipX
		local leg = `leg_{side}`
		table.insert(parts, { name = leg, parent = "base", shape = "box", size = { t, o.hipY - kneeY, t * 1.2 }, at = { x, (o.hipY + kneeY) / 2, 0.1 }, pivot = { x, o.hipY, 0 }, color = o.color })
		table.insert(parts, { name = `hip_{side}`, parent = leg, shape = "cylinder", axis = "x", size = { t * 1.1, t * 1.1, t * 1.1 }, at = { x, o.hipY, 0 }, color = o.knee or "metal" })
		table.insert(parts, { name = `knee_{side}`, parent = leg, shape = "ball", size = { t * 1.05, t * 1.05, t * 1.05 }, at = { x, kneeY, -0.1 }, color = o.knee or "metal" })
		table.insert(parts, { name = `shin_{side}`, parent = leg, shape = "box", size = { t * 0.9, kneeY - 0.3, t }, at = { x, kneeY / 2 + 0.2, 0.15 }, color = o.color })
		table.insert(parts, { name = `foot_{side}`, parent = leg, shape = "box", size = { t * 1.25, 0.4, t * 2.4 }, at = { x, 0.2, -0.3 * t }, color = o.foot or "dark" })
		if o.team then
			table.insert(parts, { name = `thighTeam_{side}`, parent = leg, shape = "box", size = { 0.06, (o.hipY - kneeY) * 0.6, t * 0.5 }, at = { x + sx * (t / 2 + 0.03), (o.hipY + kneeY) / 2, 0.1 }, color = "team" })
		end
	end
	return { "leg_l", "leg_r" }
end

return Bots
