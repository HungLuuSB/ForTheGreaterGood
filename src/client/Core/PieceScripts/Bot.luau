--!strict
-- The walking bots (S-181, models-C's leg kit Blockouts/Bots.luau, rig.md
-- 10): the Commander's stride (PieceScripts/Commander) on `thigh` / `shin`
-- / `foot` L and R, without the torso twist (a bot's `torso` is its weapon
-- turret: Default aims it) and without arm swing (the bots have none), the
-- pelvis dipping less. One stride takes about 2.9 hip heights of ground at
-- the bot's top speed, so short legs patter and long ones stride; the swing
-- is scaled per bot (models-C: Fatboy short heavy steps, Centurion long
-- strides). Skitter (four splayed legs) walks a diagonal gait: front-left
-- with back-right, then front-right with back-left; so does the Mammoth on
-- its four whole legs (`legFL` .. `legBR`, hinged at the hip, models-C), an
-- elephant's walk. The experimentals Titan and Juggernaut (chs_juggernaut, S-213) use
-- the leg kit ×2.1, on land and on the seafloor (AMPHIB_WALKER, S-210).
-- Stopped, the legs ease back to rest.

local Default = require("./Default")

local Bot = {}

Bot.WALK = 1 -- signal mask of the walk thread
Bot.STRIDE_HIPS = 2.9 -- ground per stride, in hip heights (the Commander's: 0.6 s at its speed)
Bot.MIN_STRIDE, Bot.MAX_STRIDE = 0.25, 1.2 -- seconds per stride
-- hip heights (models-C); others 2.5
Bot.HIP = {
	ord_fatboy = 3.6,
	chs_centurion = 5.6,
	chs_skitter = 2.1,
	ord_titan = 9.66,
	chs_juggernaut = 9.68,
	chs_mammoth = 5.6,
} :: { [string]: number }
-- swing scale; others 1 (models-C: about 0.6 for the heavy, slow ones)
Bot.SCALE = {
	ord_fatboy = 0.5,
	chs_centurion = 1.15,
	chs_skitter = 0.7,
	ord_titan = 0.6,
	chs_juggernaut = 0.6,
	chs_mammoth = 0.6,
} :: { [string]: number }
Bot.DIP = 0.05 -- the pelvis's drop mid-step, in hip heights

-- the Commander's stride, left leg forward; the other step mirrors it (degrees)
local POSE = { thighL = 24, shinL = -8, footL = -16, thighR = -18, shinR = -22, footR = 30 }
local LEGS = { "thighL", "shinL", "footL", "thighR", "shinR", "footR" }
-- Skitter: the diagonal pairs' thighs and shins
local QUAD = { thighFL = 1, thighBR = 1, thighFR = -1, thighBL = -1, shinFL = 1, shinBR = 1, shinFR = -1, shinBL = -1 }
local QUAD_THIGH, QUAD_SHIN = 18, -12
-- Mammoth: four whole legs, diagonal pairs in phase
local TRUNKS = { legFL = 1, legBR = 1, legFR = -1, legBL = -1 }
local TRUNK = 22

local function mirror(name: string): string
	if string.sub(name, -1) == "L" then
		return string.sub(name, 1, -2) .. "R"
	end
	return string.sub(name, 1, -2) .. "L"
end

-- Seconds per stride (two steps) for this bot at its top speed.
function Bot.stride(def: any): number
	local hip = Bot.HIP[def.id] or 2.5
	local speed = (def.movement and def.movement.maxSpeed) or 30
	return math.clamp(Bot.STRIDE_HIPS * hip / math.max(speed, 1), Bot.MIN_STRIDE, Bot.MAX_STRIDE)
end

local function biped(u: any, left: boolean, seconds: number, scale: number, dip: number)
	for _, name in LEGS do
		local angle = POSE[name] * scale
		u:Turn(if left then name else mirror(name), "x", angle, math.abs(angle) * 2 / seconds + 20)
	end
	u:Move("base", "y", -dip, dip * 4 / seconds)
end

local function quad(u: any, first: boolean, seconds: number, scale: number, dip: number)
	for name, side in QUAD do
		local sign = if first then side else -side
		local angle = (if string.sub(name, 1, 5) == "thigh" then QUAD_THIGH else QUAD_SHIN) * scale * sign
		u:Turn(name, "x", angle, math.abs(angle) * 2 / seconds + 20)
	end
	u:Move("base", "y", -dip, dip * 4 / seconds)
end

local function trunks(u: any, first: boolean, seconds: number, scale: number, dip: number)
	for name, side in TRUNKS do
		local angle = TRUNK * scale * (if first then side else -side)
		u:Turn(name, "x", angle, math.abs(angle) * 2 / seconds + 10)
	end
	u:Move("base", "y", -dip, dip * 4 / seconds)
end

-- How a bot walks: "biped", "quad" (Skitter) or "trunks" (Mammoth).
function Bot.gait(def: any): string
	if def.id == "chs_skitter" then
		return "quad"
	elseif def.id == "chs_mammoth" then
		return "trunks"
	end
	return "biped"
end

function Bot.StartMoving(u: any)
	u:Signal(Bot.WALK)
	u:SetSignalMask(Bot.WALK)
	local id = u.def.id
	local half = Bot.stride(u.def) / 2
	local scale = Bot.SCALE[id] or 1
	local dip = Bot.DIP * (Bot.HIP[id] or 2.5)
	local gait = Bot.gait(u.def)
	local first = true
	while true do
		if gait == "quad" then
			quad(u, first, half, scale, dip)
		elseif gait == "trunks" then
			trunks(u, first, half, scale, dip)
		else
			biped(u, first, half, scale, dip)
		end
		u:Sleep(half / 2)
		u:Move("base", "y", 0, dip * 4 / half) -- up again as the legs pass
		u:Sleep(half / 2)
		first = not first
	end
end

function Bot.StopMoving(u: any)
	u:Signal(Bot.WALK)
	for _, name in LEGS do
		u:Turn(name, "x", 0, 120)
	end
	for name in QUAD do
		u:Turn(name, "x", 0, 120)
	end
	for name in TRUNKS do
		u:Turn(name, "x", 0, 60)
	end
	u:Move("base", "y", 0, 2)
end

Bot.Create = Default.Create
Bot.AimWeapon = Default.AimWeapon
Bot.FireWeapon = Default.FireWeapon

-- The Dragon (S-181): its ducted fans (`fanL` / `fanR`) run all the time,
-- faster while it moves.
Bot.Dragon = {
	FAN = 540, -- degrees per second hovering
	FAN_MOVING = 1080,
}

function Bot.Dragon.Create(u: any)
	Default.Create(u)
	u:Spin("fanL", "y", Bot.Dragon.FAN, 360)
	u:Spin("fanR", "y", -Bot.Dragon.FAN, 360)
end

function Bot.Dragon.StartMoving(u: any)
	u:Spin("fanL", "y", Bot.Dragon.FAN_MOVING, 540)
	u:Spin("fanR", "y", -Bot.Dragon.FAN_MOVING, 540)
end

function Bot.Dragon.StopMoving(u: any)
	u:Spin("fanL", "y", Bot.Dragon.FAN, 360)
	u:Spin("fanR", "y", -Bot.Dragon.FAN, 360)
end

Bot.Dragon.AimWeapon = Default.AimWeapon
Bot.Dragon.FireWeapon = Default.FireWeapon
Bot.Dragon.Land = Default.Land
Bot.Dragon.TakeOff = Default.TakeOff

return Bot
