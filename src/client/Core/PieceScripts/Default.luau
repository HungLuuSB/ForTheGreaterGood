--!strict
-- The piece script of every unit without its own (C-30): each weapon's
-- turret and pitch pieces follow the replicated aim at FOLLOW × the
-- weapon's turret rates, so they reach each new server angle before the
-- next one arrives (at most a tick behind the server's own turret), and the
-- pitch piece (the barrel) recoils on each shot. A helicopter's rotor
-- spins while it flies and winds down when it lands (C-31).

local Default = {}

Default.FOLLOW = 1.25
Default.RECOIL = 0.5 -- studs back along the barrel
Default.RECOIL_SPEED = 40 -- studs per second out
Default.RETURN_SPEED = 4 -- studs per second back
Default.ROTOR_SPEED = 1440 -- degrees per second (4 turns a second)
Default.ROTOR_ACCEL = 720 -- degrees per second²: spin-up / wind-down

local function isHeli(u: any): boolean
	return u.def.moveClass == "HELI"
end

function Default.Create(u: any)
	if isHeli(u) then
		u:Spin("rotor", "y", Default.ROTOR_SPEED)
	end
end

function Default.Land(u: any)
	if isHeli(u) then
		u:StopSpin("rotor", "y", Default.ROTOR_ACCEL / 2)
	end
end

function Default.TakeOff(u: any)
	if isHeli(u) then
		u:Spin("rotor", "y", Default.ROTOR_SPEED, Default.ROTOR_ACCEL)
	end
end

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

Default.DRUM_SPEED = 720 -- degrees per second: a barrel cluster turning to the next barrel

-- A slot with several muzzles (S-157, C-198): each shot's barrel recoils in
-- turn (`barrelN` for `muzzleN`, `laser_barrelN` for `laser_muzzleN`), and
-- a `drumPiece` turns the cluster one barrel on after each shot (Geryon,
-- Bulwark's laser).
local function cycleFire(u: any, slot: number, slotDef: any, muzzles: { string })
	u.shotsFired = u.shotsFired or {}
	local n = u.shotsFired[slot] or 0
	u.shotsFired[slot] = n + 1
	if slotDef.drumPiece then
		u:Turn(slotDef.drumPiece, "z", -(n + 1) * 360 / #muzzles, Default.DRUM_SPEED)
	end
	local barrel = (string.gsub(muzzles[n % #muzzles + 1], "muzzle", "barrel"))
	u:Move(barrel, "z", Default.RECOIL, Default.RECOIL_SPEED) -- (a model without it draws nothing)
	u:WaitForMove(barrel, "z")
	u:Move(barrel, "z", 0, Default.RETURN_SPEED)
end

function Default.FireWeapon(u: any, slot: number)
	local slotDef = u.def.weapons[slot]
	if slotDef.muzzles and #slotDef.muzzles > 1 then
		cycleFire(u, slot, slotDef, slotDef.muzzles)
		return
	end
	local piece = slotDef.pitchPiece
	if piece == nil then
		return
	end
	u:Move(piece, "z", Default.RECOIL, Default.RECOIL_SPEED)
	u:WaitForMove(piece, "z")
	u:Move(piece, "z", 0, Default.RETURN_SPEED)
end

return Default
