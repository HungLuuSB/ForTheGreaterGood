--!strict
-- The piece script of every unit without its own (C-30): each weapon's
-- turret and pitch pieces follow the replicated aim at FOLLOW × the
-- weapon's turret rates, so they reach each new server angle before the
-- next one arrives (at most a tick behind the server's own turret), and the
-- pitch piece (the barrel) recoils on each shot.

local Default = {}

Default.FOLLOW = 1.25
Default.RECOIL = 0.5 -- studs back along the barrel
Default.RECOIL_SPEED = 40 -- studs per second out
Default.RETURN_SPEED = 4 -- studs per second back

function Default.AimWeapon(u: any, slot: number, yaw: number, pitch: number)
	local slotDef = u.def.weapons[slot]
	local weapon = u:weapon(slot)
	local turret = weapon and weapon.turret
	if slotDef.turretPiece then
		u:Turn(slotDef.turretPiece, "y", yaw, if turret then turret.yawRate * Default.FOLLOW else nil)
	end
	if slotDef.pitchPiece then
		u:Turn(slotDef.pitchPiece, "x", pitch, if turret then turret.pitchRate * Default.FOLLOW else nil)
	end
end

function Default.FireWeapon(u: any, slot: number)
	local piece = u.def.weapons[slot].pitchPiece
	if piece == nil then
		return
	end
	u:Move(piece, "z", Default.RECOIL, Default.RECOIL_SPEED)
	u:WaitForMove(piece, "z")
	u:Move(piece, "z", 0, Default.RETURN_SPEED)
end

return Default
