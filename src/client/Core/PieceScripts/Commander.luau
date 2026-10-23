--!strict
-- The Commanders as walking mechs (models-C's M-31, rig.md 10; C-146):
-- ord_sovereign and chs_warlord. Their legs, arms, torso and head are
-- client-only pieces. Moving, they walk: models-C's stride pose and its
-- mirror alternate, one stride per STRIDE seconds. Arms swing against the
-- legs, the torso twists, the pelvis dips. Stopped, everything eases back
-- to rest. They have no weapon; building is the default script's.

local Default = require("./Default")

local Commander = {}

Commander.STRIDE = 0.6 -- seconds per stride (two steps)
Commander.WALK = 1 -- signal mask of the walk thread

-- models-C's stride (left leg forward); the other step mirrors it. Degrees.
local POSE = {
	thighL = 28, shinL = -18, footL = -10,
	thighR = -22, shinR = -30, footR = 20,
	armL = -18, armR = 18,
}
local TORSO = 6
local DIP = 0.12 -- studs the pelvis drops mid-step
local LIMBS = { "thighL", "shinL", "footL", "thighR", "shinR", "footR", "armL", "armR" }

-- The mirror of a pose: L and R swapped.
local function mirror(name: string): string
	if string.sub(name, -1) == "L" then
		return string.sub(name, 1, -2) .. "R"
	end
	return string.sub(name, 1, -2) .. "L"
end

local function step(u: any, left: boolean, seconds: number)
	for _, name in LIMBS do
		local angle = POSE[name]
		local piece = if left then name else mirror(name)
		u:Turn(piece, "x", angle, math.abs(angle) * 2 / seconds + 20)
	end
	u:Turn("torso", "y", if left then TORSO else -TORSO, TORSO * 4 / seconds)
	u:Move("base", "y", -DIP, DIP * 4 / seconds)
end

function Commander.StartMoving(u: any)
	u:Signal(Commander.WALK)
	u:SetSignalMask(Commander.WALK)
	local half = Commander.STRIDE / 2
	local left = true
	while true do
		step(u, left, half)
		u:Sleep(half / 2)
		u:Move("base", "y", 0, DIP * 4 / half) -- up again as the legs pass
		u:Sleep(half / 2)
		left = not left
	end
end

function Commander.StopMoving(u: any)
	u:Signal(Commander.WALK)
	for _, name in LIMBS do
		u:Turn(name, "x", 0, 120)
	end
	u:Turn("torso", "y", 0, 30)
	u:Move("base", "y", 0, 2)
end

Commander.Create = Default.Create
Commander.AimWeapon = Default.AimWeapon
Commander.FireWeapon = Default.FireWeapon

return Commander
