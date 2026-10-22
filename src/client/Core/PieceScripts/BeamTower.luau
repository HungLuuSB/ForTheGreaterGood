--!strict
-- Beam towers (S-96, C-112): Radiance (Order) and Inferno (Chaos).
-- Switched off (TOGGLED_ON clear) the tower retracts into its armored shell:
-- the turret sinks into the pit, the barrel folds down and, on models that
-- have them, the shell lids close over it (the models stream's `retracted`
-- pose: turret dy −7.6 / −7.4, barrel x −90°, shellL / shellR z ∓90°).
-- Switched on it rises and unfolds the other way round. It can't aim or
-- fire while retracted. Aim and fire as the default script.

local Default = require("./Default")

local BeamTower = {}

BeamTower.SECONDS = 1.5 -- to retract or rise
BeamTower.DROP = { ord_radiance = 7.6, chs_inferno = 7.4 } :: { [string]: number }
BeamTower.FOLD = 90 -- degrees the barrel folds down
BeamTower.LID = 90 -- degrees the shell lids swing closed

function BeamTower.Retract(u: any, retracted: boolean, instant: boolean?)
	local secs = BeamTower.SECONDS
	local drop = BeamTower.DROP[u.def.id] or 6
	local function speed(amount: number): number?
		return if instant then nil else amount / secs
	end
	if retracted then
		u:Turn("turret", "y", 0, speed(90)) -- face front to fold away
		u:Turn("barrel", "x", -BeamTower.FOLD, speed(BeamTower.FOLD))
		u:Move("turret", "y", -drop, speed(drop))
		u:Turn("shellL", "z", -BeamTower.LID, speed(BeamTower.LID))
		u:Turn("shellR", "z", BeamTower.LID, speed(BeamTower.LID))
	else
		u:Turn("shellL", "z", 0, speed(BeamTower.LID))
		u:Turn("shellR", "z", 0, speed(BeamTower.LID))
		u:Move("turret", "y", 0, speed(drop))
		u:Turn("barrel", "x", 0, speed(BeamTower.FOLD))
	end
end

function BeamTower.AimWeapon(u: any, slot: number, yaw: number, pitch: number)
	if u.retracted then
		return -- folded away: it can't fire
	end
	Default.AimWeapon(u, slot, yaw, pitch)
end

BeamTower.FireWeapon = Default.FireWeapon

return BeamTower
