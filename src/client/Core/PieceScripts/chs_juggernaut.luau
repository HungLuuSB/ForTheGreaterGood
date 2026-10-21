--!strict
-- Juggernaut (guide 14.4, C-30): the torso turns to the target, both gun
-- arms rise from hanging down to the firing pitch, recoil in turn when it
-- fires, and come down again RESTORE_DELAY seconds after the weapon stops
-- aiming. AimWeapon comes every PieceAnim.REAIM seconds while the weapon
-- is engaged, and each call cancels the pending restore (SIG_AIM).
--
-- Timing: with `turret.restPitch` in the weapon def (the server rests the
-- arms there and raises them at its pitchRate; request 8), the arms follow
-- the replicated pitch at the server's own rates and the restore uses
-- `turret.restoreDelay`, so the client shows exactly the server's timing.
-- Until then the arms hang at REST_PITCH and rise at ARM_SPEED (visual).

local Jug = {}

Jug.REST_PITCH = -65 -- degrees: arms hanging down
Jug.ARM_SPEED = 120 -- degrees per second (until the server raises them itself)
Jug.RESTORE_DELAY = 3 -- seconds
Jug.FOLLOW = 1.25
Jug.RECOIL = 0.8 -- studs
local SIG_AIM = 1

local function params(u: any, slot: number): (number, number, number, number)
	local weapon = u:weapon(slot)
	local t = (weapon and weapon.turret) or {}
	local serverRest = t.restPitch ~= nil
	local yawSpeed = (t.yawRate or 90) * Jug.FOLLOW
	local armSpeed = if serverRest then (t.pitchRate or 60) * Jug.FOLLOW else Jug.ARM_SPEED
	return yawSpeed, armSpeed, t.restPitch or Jug.REST_PITCH, t.restoreDelay or Jug.RESTORE_DELAY
end

local function restore(u: any, slot: number)
	local yawSpeed, armSpeed, rest, delay = params(u, slot)
	u:Sleep(delay)
	u:Turn("turret", "y", 0, yawSpeed)
	u:Turn("armL", "x", rest, armSpeed)
	u:Turn("armR", "x", rest, armSpeed)
end

function Jug.Create(u: any)
	local _, _, rest = params(u, 1)
	u:Turn("armL", "x", rest)
	u:Turn("armR", "x", rest)
end

function Jug.AimWeapon(u: any, slot: number, yaw: number, pitch: number, active: boolean)
	if not active then
		return -- not engaged: the restore thread lowers the arms after its delay
	end
	u:Signal(SIG_AIM) -- cancels the previous aim and its pending restore
	u:SetSignalMask(SIG_AIM)
	local yawSpeed, armSpeed = params(u, slot)
	u:Turn("turret", "y", yaw, yawSpeed)
	u:Turn("armL", "x", pitch, armSpeed)
	u:Turn("armR", "x", pitch, armSpeed)
	u:WaitForTurn("armL", "x")
	u:StartThread(restore, slot) -- inherits SIG_AIM: the next aim cancels it
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
