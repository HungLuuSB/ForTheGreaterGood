--!strict
-- The aim model (guide 10.3, 14.4; S-20), shared so a client can animate
-- turrets and arms exactly as the server turns them.
--
-- A weapon's aim is a yaw (relative to the hull) and a pitch, in radians.
-- It starts at the turret's rest pose (`restYaw`, `restPitch`, degrees,
-- default 0). With a target it turns toward the wanted aim at `yawRate` /
-- `pitchRate`, clamped to the arc and to [minPitch, maxPitch]. Without one
-- it keeps its aim for `restoreDelay` seconds (default 0), then turns back
-- to rest at the same rates. Firing needs the aim within `tolerance` of the
-- wanted aim (Weapons), so raising arms from rest costs real time.
--
-- State per weapon: yaw, pitch and `hold`, the ticks it still keeps its aim
-- after losing its target. `Aim.update` advances one tick; the server calls
-- it for every weapon every tick, and a client running it from the same
-- state with the same wanted aims gets the same angles, bit for bit.

local Aim = {}

Aim.DT = 1 / 15

local PI, TAU = math.pi, 2 * math.pi
local rad, max, min = math.rad, math.max, math.min

export type Turret = {
	yawRate: number,
	pitchRate: number,
	tolerance: number,
	minPitch: number,
	maxPitch: number,
	arc: number,
	restYaw: number?,
	restPitch: number?,
	restoreDelay: number?,
}

export type State = { yaw: number, pitch: number, hold: number }

-- Test hook: called with (key, wantYaw, wantPitch) whenever the server aims
-- a weapon at a target (wantYaw nil when it has none). Never set in play.
Aim.observer = nil :: ((key: number, wantYaw: number?, wantPitch: number?) -> ())?

function Aim.wrapAngle(a: number): number
	a = a % TAU
	if a > PI then
		a -= TAU
	end
	return a
end

-- The rest pose in radians (0, 0 without a turret).
function Aim.rest(turret: Turret?): (number, number)
	if turret == nil then
		return 0, 0
	end
	return rad(turret.restYaw or 0), rad(turret.restPitch or 0)
end

-- Ticks a weapon keeps its aim after losing its target.
function Aim.holdTicks(turret: Turret?): number
	if turret == nil or turret.restoreDelay == nil then
		return 0
	end
	return math.ceil(turret.restoreDelay / Aim.DT - 1e-9)
end

-- One tick of turning from (yaw, pitch) toward (wantYaw, wantPitch). A
-- weapon without a turret (fixed mounts, bombs) aims at once.
function Aim.step(turret: Turret?, yaw: number, pitch: number, wantYaw: number, wantPitch: number): (number, number)
	if turret == nil then
		return wantYaw, wantPitch
	end
	local diff = Aim.wrapAngle(wantYaw - yaw)
	local yawStep = rad(turret.yawRate) * Aim.DT
	yaw = Aim.wrapAngle(yaw + max(-yawStep, min(yawStep, diff)))
	if turret.arc < 360 then
		local half = rad(turret.arc) / 2
		yaw = max(-half, min(half, yaw))
	end
	local minP, maxP = rad(turret.minPitch), rad(turret.maxPitch)
	local step = rad(turret.pitchRate) * Aim.DT
	pitch = max(minP, min(maxP, pitch + max(-step, min(step, max(minP, min(maxP, wantPitch)) - pitch))))
	return yaw, pitch
end

-- One tick of the aim model: with a wanted aim (the weapon has a target),
-- turn toward it and reset the hold; without one, keep the aim while the
-- hold lasts, then turn back to rest. Updates `state` in place.
function Aim.update(turret: Turret?, state: State, wantYaw: number?, wantPitch: number?)
	local wy, wp
	if wantYaw ~= nil and wantPitch ~= nil then
		wy, wp = wantYaw, wantPitch
		state.hold = Aim.holdTicks(turret)
	elseif state.hold > 0 then
		state.hold -= 1
		wy, wp = state.yaw, state.pitch
	else
		wy, wp = Aim.rest(turret)
	end
	state.yaw, state.pitch = Aim.step(turret, state.yaw, state.pitch, wy, wp)
end

-- Seconds to turn the pitch from `from` to `to` (degrees): what raising the
-- arms costs.
function Aim.pitchTime(turret: Turret, from: number, to: number): number
	return math.abs(to - from) / turret.pitchRate
end

return Aim
