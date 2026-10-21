--!strict
-- Missile sensor view (C-39), War Thunder style: what each homing missile
-- is doing, drawn over the scene when toggled on (N). Pure Luau (C-7);
-- Render/MissileView draws it.
--
-- For the MAX_MISSILES most important homing missiles drawn this frame:
-- where it is drawn, its target's centre and the point it steers at (the
-- server's lead, Effects.aim), its predicted path over the next PATH_TICKS
-- (Effects.predict), the closest approach that prediction gives against the
-- proximity fuse (the weapon's aoe from the target's hull), and a label:
-- guidance, LOCK or no lock, target, distance, time to go, the target's
-- angle off the nose against the seeker cone (C-42), predicted miss.
-- Corrections, decoys and lost locks come from Effects' marks.

local Effects = require("./Effects")
local World = require("./World")

local MissileView = {}

MissileView.MAX_MISSILES = 12
MissileView.PATH_TICKS = 15 -- the drawn path: 1 s of sim time
MissileView.PREDICT_TICKS = 45 -- how far ahead the miss is looked for (3 s)
MissileView.PAST_TICKS = 2 -- a locked missile's path ends this many ticks after its closest approach
-- Seeker half-angle off the nose by guidance (degrees, C-42) until the sim
-- gives weapons a `seekerAngle` (request 13c); COMMAND guidance has no seeker.
MissileView.SEEKER_ANGLE = table.freeze({ IR = 60, RADAR = 70 }) :: { [string]: number }

export type Entry = {
	id: number,
	x: number, -- drawn position
	y: number,
	z: number,
	guidance: string, -- IR / RADAR / COMMAND, "—" for unguided homing
	fx: number, -- flight direction (unit vector)
	fy: number,
	fz: number,
	seekerAngle: number?, -- the seeker cone's half-angle (degrees); nil without a seeker
	seekerRange: number, -- the cone's length: weapon.lockRange or range
	offNose: number?, -- degrees between the nose and the target's centre
	inSeeker: boolean, -- the target's centre is inside the cone
	locked: boolean,
	targetId: number?,
	targetName: string?,
	cx: number?, -- the target's centre
	cy: number?,
	cz: number?,
	lx: number?, -- the point it steers at
	ly: number?,
	lz: number?,
	path: { number }, -- x, y, z: the drawn position, then up to PATH_TICKS predicted ticks (locked: up to PAST_TICKS past the closest approach)
	fuse: number, -- proximity fuse: studs from the target's hull (weapon.aoe)
	hullRadius: number?, -- the target's collision cylinder
	hullHeight: number?,
	distance: number?, -- studs to the target's centre
	tgo: number?, -- sim seconds to the closest approach
	miss: number?, -- predicted closest approach to the hull (studs)
	px: number?, -- the missile at that closest approach
	py: number?,
	pz: number?,
	hit: boolean, -- the fuse would fire on the prediction
	label: string,
}

local function fmt(v: number): string
	return if v < 10 then string.format("%.1f", v) else string.format("%d", math.floor(v + 0.5))
end

-- `visible`: Effects.visible's list for this render tick.
function MissileView.build(fx: Effects.Fx, world: World.World, renderTick: number, visible: { { any } }): { Entry }
	local homing = {}
	for _, v in visible do
		local p = v[1] :: Effects.Proj
		if p.weapon.type == "HOMING" then
			table.insert(homing, v)
		end
	end
	table.sort(homing, function(a, b)
		if a[5] ~= b[5] then
			return a[5] > b[5]
		end
		return (a[1] :: Effects.Proj).id < (b[1] :: Effects.Proj).id
	end)
	local out: { Entry } = {}
	for i = 1, math.min(#homing, MissileView.MAX_MISSILES) do
		local v = homing[i]
		local p = v[1] :: Effects.Proj
		local x, y, z = v[2] :: number, v[3] :: number, v[4] :: number
		local weapon = p.weapon
		local target = if p.target ~= 0 then world.units[p.target] else nil
		-- the drawn velocity: the tick's start velocity eased toward the next (C-38)
		local s = math.clamp(renderTick - fx.tick, 0, 1)
		local vx, vy, vz = p.vx, p.vy, p.vz
		local ns = p.nextState
		if ns then
			vx, vy, vz = vx + (ns[4] - vx) * s, vy + (ns[5] - vy) * s, vz + (ns[6] - vz) * s
		end
		local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
		if speed > 1e-6 then
			vx, vy, vz = vx / speed, vy / speed, vz / speed
		else
			vx, vy, vz = 0, 0, 1
		end
		local guidance = weapon.guidance or "—"
		local e: Entry = {
			id = p.id,
			x = x,
			y = y,
			z = z,
			guidance = guidance,
			fx = vx,
			fy = vy,
			fz = vz,
			seekerAngle = weapon.seekerAngle or MissileView.SEEKER_ANGLE[guidance],
			seekerRange = weapon.lockRange or weapon.range or 0,
			inSeeker = false,
			locked = target ~= nil,
			path = { x, y, z },
			fuse = weapon.aoe or 0,
			hit = false,
			label = "",
		}
		local pred = Effects.predict(fx, world, p, MissileView.PREDICT_TICKS)
		-- the path from the drawn point on: the predicted ticks after this frame
		local ahead = renderTick - fx.tick
		local n = math.min(#pred.path // 3, MissileView.PATH_TICKS)
		if pred.at then
			n = math.min(n, math.ceil(pred.at :: number) + MissileView.PAST_TICKS)
		end
		for k = 1, n do
			if k > ahead then
				table.move(pred.path, k * 3 - 2, k * 3, #e.path + 1, e.path)
			end
		end
		local lines = {}
		if target then
			local def = World.def(world, target)
			e.targetId = p.target
			-- a strategic-tier target (outside the camera's rectangle) has no def
			e.targetName = if def then def.name else `contact #{p.target}`
			local lx, ly, lz, cx, cy, cz = Effects.aim(world, p, renderTick, x, y, z)
			e.lx, e.ly, e.lz, e.cx, e.cy, e.cz = lx, ly, lz, cx, cy, cz
			local fp = if def then def.footprint else 1
			e.hullRadius = fp * Effects.HULL_RADIUS
			e.hullHeight = fp * Effects.UNIT_HEIGHT
			local dx, dy, dz = (cx :: number) - x, (cy :: number) - y, (cz :: number) - z
			e.distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			if e.seekerAngle and (e.distance :: number) > 1e-6 then
				local cos = (dx * vx + dy * vy + dz * vz) / (e.distance :: number)
				e.offNose = math.deg(math.acos(math.clamp(cos, -1, 1)))
				e.inSeeker = (e.offNose :: number) <= (e.seekerAngle :: number)
			end
			if pred.miss then
				e.miss, e.hit = pred.miss, pred.hit
				e.tgo = math.max(0, ((pred.at :: number) - ahead) / 15)
				e.px, e.py, e.pz = pred.cx, pred.cy, pred.cz
			end
			table.insert(lines, `{e.guidance}  LOCK  {e.targetName}`)
			local second = `{fmt(e.distance :: number)} studs`
			if e.tgo then
				second ..= `  {string.format("%.2f", e.tgo)} s`
			end
			if e.offNose then
				second ..= `  {math.floor((e.offNose :: number) + 0.5)}° / {e.seekerAngle}° off`
			end
			table.insert(lines, second)
			if e.miss then
				table.insert(lines, `miss {fmt(e.miss :: number)} / fuse {fmt(e.fuse)}{if e.hit then "  HIT" else ""}`)
			end
		else
			table.insert(lines, `{e.guidance}  no lock`)
		end
		e.label = table.concat(lines, "\n")
		table.insert(out, e)
	end
	return out
end

return MissileView
