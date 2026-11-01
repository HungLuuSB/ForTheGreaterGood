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
-- The spider kit's legs (Blockouts/Bots.spider, S-233 batch 2) sweep about
-- the hip and lift: six legs in a tripod (FL MR BL against FR ML BR), four
-- in diagonal pairs. Any unit whose legs swing walks with this script
-- (Registry.forDef, C-290): its gait comes from its leg pieces and its hip
-- height from its blockout. Stopped, the legs ease back to rest.

local Default = require("./Default")
local PieceMotion = require("../PieceMotion")
local Blockout = require("@shared/Defs/Blockouts/Blockout")

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
Bot.HEAVY_HIP = 6 -- hips this high (the T3 walkers) swing at HEAVY_SCALE unless SCALE says
Bot.HEAVY_SCALE = 0.6
Bot.SPIDER_SWEEP = 16 -- degrees a spider leg swings forward or back about its hip
Bot.SPIDER_LIFT = 14 -- degrees a stepping spider leg lifts

-- the Commander's stride, left leg forward; the other step mirrors it (degrees)
local POSE = { thighL = 24, shinL = -8, footL = -16, thighR = -18, shinR = -22, footR = 30 }
local LEGS = { "thighL", "shinL", "footL", "thighR", "shinR", "footR" }
-- Skitter: the diagonal pairs' thighs and shins
local QUAD = { thighFL = 1, thighBR = 1, thighFR = -1, thighBL = -1, shinFL = 1, shinBR = 1, shinFR = -1, shinBL = -1 }
local QUAD_THIGH, QUAD_SHIN = 18, -12
-- Mammoth: four whole legs, diagonal pairs in phase
local TRUNKS = { legFL = 1, legBR = 1, legFR = -1, legBL = -1 }
local TRUNK = 22
-- the spider kit's legs: each one's yaw from the body (0 back, 90 right;
-- Blockouts/Bots SPIDER_YAWS) and which set it steps with
local SPIDER_YAWS = {
	[4] = { FL = 225, FR = 135, BL = 315, BR = 45 },
	[6] = { FL = 215, ML = 270, BL = 325, FR = 145, MR = 90, BR = 35 },
}
local SPIDER_SETS = {
	[4] = { FL = 1, BR = 1, FR = -1, BL = -1 },
	[6] = { FL = 1, MR = 1, BL = 1, FR = -1, ML = -1, BR = -1 },
}

local function mirror(name: string): string
	if string.sub(name, -1) == "L" then
		return string.sub(name, 1, -2) .. "R"
	end
	return string.sub(name, 1, -2) .. "L"
end

local swingCache: { [string]: { [string]: boolean } } = {}
local hipCache: { [string]: number } = {}

-- The pieces of `def` that swing (its legs), from its blockout or mesh.
local function swings(def: any): { [string]: boolean }
	local found = swingCache[def.id]
	if found == nil then
		found = {}
		for _, m in PieceMotion.forDef(def) do
			if m.motion == "swing" then
				found[m.piece] = true
			end
		end
		swingCache[def.id] = found
	end
	return found
end

-- Whether `def` walks on swinging legs (a biped's, a spider's or trunks).
function Bot.walks(def: any): boolean
	local s = swings(def)
	return s.thighL == true or s.thighFL == true or s.legFL == true
end

-- Hip height in studs: HIP, else the blockout's hip pivot, else 2.5.
function Bot.hip(def: any): number
	local h = Bot.HIP[def.id] or hipCache[def.id]
	if h then
		return h
	end
	h = 2.5
	local ok, bp = pcall(Blockout.forDef, def)
	if ok and bp then
		for _, p in bp.parts do
			if (p.name == "thighL" or p.name == "thighFL" or p.name == "legFL") and p.pivot then
				h = p.pivot[2]
				break
			end
		end
	end
	hipCache[def.id] = h
	return h
end

-- Swing scale: SCALE, else smaller for the heavy walkers.
function Bot.scale(def: any): number
	return Bot.SCALE[def.id] or (if Bot.hip(def) >= Bot.HEAVY_HIP then Bot.HEAVY_SCALE else 1)
end

-- Seconds per stride (two steps) for this bot at its top speed.
function Bot.stride(def: any): number
	local hip = Bot.hip(def)
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

-- A spider's legs: the stepping set sweeps forward and lifts, the other set
-- sweeps back on the ground. The lift turns about the horizontal axis
-- across the leg (outward × up), as x and z turns.
local function spider(u: any, first: boolean, seconds: number, scale: number, legs: number)
	local sets = SPIDER_SETS[legs]
	for tag, yaw in SPIDER_YAWS[legs] do
		local stepping = (sets[tag] == 1) == first
		local ux, uz = math.sin(math.rad(yaw)), math.cos(math.rad(yaw))
		local sweep = Bot.SPIDER_SWEEP * scale * (if stepping then 1 else -1) * (if ux > 0 then 1 else -1)
		local lift = if stepping then Bot.SPIDER_LIFT * scale else 0
		local name = "thigh" .. tag
		u:Turn(name, "y", sweep, Bot.SPIDER_SWEEP * 4 / seconds + 20)
		u:Turn(name, "x", -uz * lift, Bot.SPIDER_LIFT * 4 / seconds + 20)
		u:Turn(name, "z", ux * lift, Bot.SPIDER_LIFT * 4 / seconds + 20)
	end
end

-- Mid-step: the stepping legs come down.
local function spiderDown(u: any, seconds: number, legs: number)
	for tag in SPIDER_YAWS[legs] do
		u:Turn("thigh" .. tag, "x", 0, Bot.SPIDER_LIFT * 4 / seconds + 20)
		u:Turn("thigh" .. tag, "z", 0, Bot.SPIDER_LIFT * 4 / seconds + 20)
	end
end

-- How a bot walks: "biped", "quad" (Skitter), "trunks" (Mammoth, Colossus)
-- or "spider" (the spider kit's legs).
function Bot.gait(def: any): string
	if def.id == "chs_skitter" then
		return "quad"
	end
	local s = swings(def)
	if s.legFL then
		return "trunks"
	elseif s.thighFL then
		return "spider"
	end
	return "biped"
end

function Bot.StartMoving(u: any)
	u:Signal(Bot.WALK)
	u:SetSignalMask(Bot.WALK)
	local id = u.def.id
	local half = Bot.stride(u.def) / 2
	local scale = Bot.scale(u.def)
	local dip = Bot.DIP * Bot.hip(u.def)
	local gait = Bot.gait(u.def)
	local legs = if swings(u.def).thighML then 6 else 4
	local first = true
	while true do
		if gait == "quad" then
			quad(u, first, half, scale, dip)
		elseif gait == "trunks" then
			trunks(u, first, half, scale, dip)
		elseif gait == "spider" then
			spider(u, first, half, scale, legs)
		else
			biped(u, first, half, scale, dip)
		end
		u:Sleep(half / 2)
		if gait == "spider" then
			spiderDown(u, half, legs)
		end
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
	if Bot.gait(u.def) == "spider" then
		for tag in SPIDER_YAWS[6] do
			for _, axis in { "x", "y", "z" } do
				u:Turn("thigh" .. tag, axis, 0, 120)
			end
		end
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
