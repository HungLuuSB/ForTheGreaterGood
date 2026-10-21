--!strict
-- Warden (S-64, C-84): a deployable gun. Unpacking (the DEPLOYING bit, from
-- standing still), it swings its spades down behind it, squats onto them
-- and levels the gun over the def's deploy time; packing, it does the same
-- backwards and locks the gun forward for travel. Aim and recoil as the
-- default script (Default). Pieces: base, spades, turret, barrel, muzzle
-- (the models stream's blockout, request 3).

local Default = require("./Default")

local Warden = {}

Warden.SPADE_ANGLE = 55 -- degrees the spades swing down
Warden.SQUAT = 0.4 -- studs the hull settles onto them

local function seconds(u: any): number
	return (u.def.deploy and u.def.deploy.time) or 4
end

function Warden.Deploy(u: any, phase: string, instant: boolean?)
	local secs = seconds(u)
	local down = phase == "unpacking" or phase == "deployed"
	local spadeSpeed = if instant then 0 else Warden.SPADE_ANGLE / secs
	local squatSpeed = if instant then 0 else Warden.SQUAT / secs
	u:Turn("spades", "x", if down then Warden.SPADE_ANGLE else 0, spadeSpeed)
	u:Move("base", "y", if down then -Warden.SQUAT else 0, squatSpeed)
	if not down then
		-- travel lock: gun forward and level
		u:Turn("turret", "y", 0, if instant then 0 else 90 / secs)
		u:Turn("barrel", "x", 0, if instant then 0 else 30 / secs)
	end
end

function Warden.AimWeapon(u: any, slot: number, yaw: number, pitch: number)
	if u.deploy == "packing" or u.deploy == "packed" then
		return -- locked for travel; it can't fire packed
	end
	Default.AimWeapon(u, slot, yaw, pitch)
end

Warden.FireWeapon = Default.FireWeapon

return Warden
