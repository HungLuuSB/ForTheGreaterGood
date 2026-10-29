--!strict
-- The construction turrets (ord_nano / chs_nano, S-209; models-C's rig):
-- `turret` yaws to the work and `nano`, the emitter head on it, pitches
-- down to it, so the spray (Render/BuildSpray, from the `nano1` attachment
-- at the lens) leaves the lens toward what it builds. Done working, the
-- head lifts back level and the turret stays where it last looked.

local NanoTurret = {}

NanoTurret.YAW_SPEED = 90 -- degrees per second
NanoTurret.PITCH_SPEED = 45
NanoTurret.LENS = { ord_nano = 10.4, chs_nano = 8 } :: { [string]: number } -- the lens's height (models-C)
NanoTurret.TARGET = 3 -- studs up the work, where the head points
NanoTurret.MIN_PITCH = -60

-- The emitter's pitch toward work `dist` studs away (degrees, down < 0).
function NanoTurret.pitch(def: any, dist: number): number
	local drop = (NanoTurret.LENS[def.id] or 8) - NanoTurret.TARGET
	return math.max(-math.deg(math.atan2(drop, math.max(dist, 1))), NanoTurret.MIN_PITCH)
end

function NanoTurret.Work(u: any, yaw: number?, dist: number?)
	if yaw then
		u:Turn("turret", "y", yaw, NanoTurret.YAW_SPEED)
		u:Turn("nano", "x", NanoTurret.pitch(u.def, dist or 30), NanoTurret.PITCH_SPEED)
	else
		u:Turn("nano", "x", 0, NanoTurret.PITCH_SPEED / 2)
	end
end

return NanoTurret
