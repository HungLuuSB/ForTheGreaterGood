--!strict
-- Leg kit for the walking bots (S-181, moveClass WALKER): the Commander
-- walker legs (rig.md 10, M-31) without the hip yokes, so the client's
-- stride drives both. Per side a `thigh{L,R}` jointed to `base` (the pelvis)
-- at the hip, a `shin{L,R}` at the knee, a `foot{L,R}` at the ankle, all
-- client pieces (each blockout lists them in `visualPieces`) that swing about
-- X. They rest with a knee bend: the thigh runs down and forward to the knee,
-- the shin back down to the ankle. A library like Scale.luau, not a
-- blockout. Model space, forward = -Z.

local Bots = {}

local SWING = { motion = "swing", axis = { 1, 0, 0 } }

export type LegOptions = {
	hipY: number, -- hip height
	hipX: number, -- hip offset either side
	thick: number, -- thigh width
	color: string, -- thigh / shin color
	foot: string?, -- foot color (default "dark")
	knee: string?, -- knee color (default "metal")
	team: boolean?, -- a team stripe down each thigh
}

-- a box whose Y axis runs from a to b (both in the same x plane)
local function limb(name: string, parent: string, a: { number }, b: { number }, w: number, d: number, color: string, pivot: { number }, anim: any?): any
	local dy, dz = a[2] - b[2], a[3] - b[3]
	local len = math.sqrt(dy * dy + dz * dz)
	return { name = name, parent = parent, shape = "box", size = { w, len, d }, at = { a[1], (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }, rot = { math.deg(math.atan2(dz, dy)), 0, 0 }, pivot = pivot, color = color, anim = anim }
end

function Bots.legs(parts: { any }, o: LegOptions): { string }
	local t = o.thick
	local kneeY, ankleY = o.hipY * 0.52, math.max(0.45, t * 0.7)
	local kneeZ = -t * 0.45 -- the knee forward of the hip
	local names = {}
	for _, side in { "L", "R" } do
		local sx = if side == "L" then -1 else 1
		local x = sx * o.hipX
		local hip, knee, ankle = { x, o.hipY, 0 }, { x, kneeY, kneeZ }, { x, ankleY, 0.1 }
		table.insert(parts, limb(`thigh{side}`, "base", hip, knee, t, t * 1.2, o.color, hip, SWING))
		table.insert(parts, { name = `hipJoint{side}`, parent = `thigh{side}`, shape = "cylinder", axis = "x", size = { t * 1.1, t * 1.1, t * 1.1 }, at = hip, color = o.knee or "metal" })
		if o.team then
			table.insert(parts, { name = `thighTeam{side}`, parent = `thigh{side}`, shape = "box", size = { 0.06, (o.hipY - kneeY) * 0.55, t * 0.5 }, at = { x + sx * (t / 2 + 0.03), (o.hipY + kneeY) / 2, kneeZ / 2 }, color = "team" })
		end
		table.insert(parts, limb(`shin{side}`, `thigh{side}`, knee, ankle, t * 0.9, t, o.color, knee, SWING))
		table.insert(parts, { name = `knee{side}`, parent = `shin{side}`, shape = "ball", size = { t * 1.05, t * 1.05, t * 1.05 }, at = knee, color = o.knee or "metal" })
		table.insert(parts, { name = `foot{side}`, parent = `shin{side}`, shape = "box", size = { t * 1.25, 0.4, t * 2.4 }, at = { x, 0.2, 0.1 - 0.3 * t }, pivot = ankle, color = o.foot or "dark", anim = SWING })
		table.insert(names, `thigh{side}`)
		table.insert(names, `shin{side}`)
		table.insert(names, `foot{side}`)
	end
	return names
end

return Bots
