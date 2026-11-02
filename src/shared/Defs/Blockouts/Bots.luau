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

-- Spider legs for the all-terrain bots (batch 2, moveClass SPIDER): legs
-- splayed round the body, each a `thigh<tag>` rising from the hip to a knee
-- high over the body, a `shin<tag>` down to the ankle and a thin claw tip to
-- the ground, so they read as able to grip a cliff. Thigh and shin are
-- client pieces that swing about X like the Skitter's (tags FL, ML, BL, FR,
-- MR, BR; ML / MR only on six legs: a tripod gait, FL MR BL against FR ML
-- BR). Yaw 0 points the leg back (+Z), 90 right (+X).
export type SpiderOptions = {
	legs: number, -- 4 or 6
	hipR: number, -- hips: distance out from the body's axis
	hipY: number,
	kneeR: number, -- knees: out and up
	kneeY: number,
	footR: number, -- claw tips on the ground
	thick: number,
	color: string, -- thigh color
	shin: string?, -- shin color (default "metal")
	claw: string?, -- claw color (default "dark")
	team: boolean?, -- a team band on each thigh
}

local SPIDER_YAWS = {
	[4] = { { "FL", 225 }, { "FR", 135 }, { "BL", 315 }, { "BR", 45 } },
	[6] = { { "FL", 215 }, { "ML", 270 }, { "BL", 325 }, { "FR", 145 }, { "MR", 90 }, { "BR", 35 } },
}

function Bots.spider(parts: { any }, o: SpiderOptions): { string }
	local names = {}
	-- one segment from (r0, y0) to (r1, y1) on the leg's vertical plane at yaw:
	-- a box whose Y axis runs between them
	local function segment(name: string, parent: string, yaw: number, r0: number, y0: number, r1: number, y1: number, w: number, color: string, pivot: boolean)
		local u = { math.sin(math.rad(yaw)), math.cos(math.rad(yaw)) }
		local dr, dy = r1 - r0, y1 - y0
		local rm, ym = (r0 + r1) / 2, (y0 + y1) / 2
		table.insert(parts, {
			name = name,
			parent = parent,
			shape = "box",
			size = { w, math.sqrt(dr * dr + dy * dy), w },
			at = { u[1] * rm, ym, u[2] * rm },
			rot = { math.deg(math.atan2(dr, dy)), yaw, 0 },
			pivot = if pivot then { u[1] * r0, y0, u[2] * r0 } else nil,
			color = color,
			anim = if pivot then SWING else nil,
		})
	end
	local t = o.thick
	local ankleR = o.kneeR + (o.footR - o.kneeR) * 0.8
	local ankleY = o.kneeY * 0.3
	for _, leg in SPIDER_YAWS[o.legs] do
		local tag, yaw = leg[1], leg[2]
		local u = { math.sin(math.rad(yaw)), math.cos(math.rad(yaw)) }
		segment(`thigh{tag}`, "base", yaw, o.hipR, o.hipY, o.kneeR, o.kneeY, t, o.color, true)
		table.insert(parts, { name = `hip{tag}`, parent = `thigh{tag}`, shape = "ball", size = { t * 1.5, t * 1.5, t * 1.5 }, at = { u[1] * o.hipR, o.hipY, u[2] * o.hipR }, color = "metal" })
		if o.team then
			segment(`thighTeam{tag}`, `thigh{tag}`, yaw, o.hipR + (o.kneeR - o.hipR) * 0.3, o.hipY + (o.kneeY - o.hipY) * 0.3 + t * 0.52, o.hipR + (o.kneeR - o.hipR) * 0.75, o.hipY + (o.kneeY - o.hipY) * 0.75 + t * 0.52, t * 0.7, "team", false)
		end
		segment(`shin{tag}`, `thigh{tag}`, yaw, o.kneeR, o.kneeY, ankleR, ankleY, t * 0.85, o.shin or "metal", true)
		table.insert(parts, { name = `knee{tag}`, parent = `shin{tag}`, shape = "ball", size = { t * 1.3, t * 1.3, t * 1.3 }, at = { u[1] * o.kneeR, o.kneeY, u[2] * o.kneeR }, color = "dark" })
		segment(`claw{tag}`, `shin{tag}`, yaw, ankleR, ankleY, o.footR, 0.05, t * 0.5, o.claw or "dark", false)
		table.insert(names, `thigh{tag}`)
		table.insert(names, `shin{tag}`)
	end
	return names
end

return Bots
