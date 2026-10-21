--!strict
-- Minotaur (S-64, C-84): a siege ram. Slot 1 is its gun (aim and recoil as
-- the default script); slot 2, the demolition charge (a 30-stud hitscan
-- against structures), drives the ram forward hard and draws it back
-- slowly. Pieces: base, ram, turret, barrel, muzzle (the models stream's
-- blockout, request 3).

local Default = require("./Default")

local Minotaur = {}

Minotaur.RAM_REACH = 2.5 -- studs the ram strikes forward
Minotaur.RAM_SPEED = 30 -- studs per second out
Minotaur.RAM_BACK = 2 -- studs per second back

function Minotaur.AimWeapon(u: any, slot: number, yaw: number, pitch: number)
	if slot == 1 then
		Default.AimWeapon(u, slot, yaw, pitch)
	end
end

function Minotaur.FireWeapon(u: any, slot: number)
	if slot == 2 then
		u:Move("ram", "z", -Minotaur.RAM_REACH, Minotaur.RAM_SPEED)
		u:WaitForMove("ram", "z")
		u:Move("ram", "z", 0, Minotaur.RAM_BACK)
		return
	end
	Default.FireWeapon(u, slot)
end

return Minotaur
