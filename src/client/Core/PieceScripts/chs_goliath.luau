--!strict
-- Goliath (chs_goliath, the T2 tank once named Juggernaut; guide 14.4, C-30, C-33): the torso turns to the target and
-- both gun arms follow the server's pitch, and the arms recoil in turn
-- when it fires. The timing is the server's (S-20, Shared/Combat/Aim): the
-- weapon rests with the arms hanging at `turret.restPitch`, raises them at
-- its pitchRate before it can fire, holds them `turret.restoreDelay`
-- seconds after losing its target, then lowers them. The client turns the
-- pieces at FOLLOW × those rates toward each replicated angle, so they stay
-- within a tick of the server and never show a shot before the arms are up.

local Jug = {}

Jug.FOLLOW = 1.25
Jug.RECOIL = 0.8 -- studs
Jug.DEFAULT_REST = -65 -- degrees, if the weapon def has no restPitch

local function rates(u: any, slot: number): (number, number, number)
	local weapon = u:weapon(slot)
	local t = (weapon and weapon.turret) or {}
	return (t.yawRate or 90) * Jug.FOLLOW, (t.pitchRate or 60) * Jug.FOLLOW, t.restPitch or Jug.DEFAULT_REST
end

function Jug.Create(u: any)
	local _, _, rest = rates(u, 1)
	u:Turn("armL", "x", rest)
	u:Turn("armR", "x", rest)
end

function Jug.AimWeapon(u: any, slot: number, yaw: number, pitch: number)
	local yawSpeed, armSpeed = rates(u, slot)
	u:Turn("turret", "y", yaw, yawSpeed)
	u:Turn("armL", "x", pitch, armSpeed)
	u:Turn("armR", "x", pitch, armSpeed)
end

function Jug.FireWeapon(u: any, _slot: number)
	-- the arms take turns
	u.nextArm = if u.nextArm == "armL" then "armR" else "armL"
	local arm = u.nextArm
	u:Move(arm, "z", Jug.RECOIL, 40)
	u:WaitForMove(arm, "z")
	u:Move(arm, "z", 0, 3)
end

return Jug
