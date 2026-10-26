--!strict
-- The Commanders' landing (C-218, S-174): for Schema.LANDING_TICKS after
-- the match starts (COUNTDOWN 0) the sim holds every order while the
-- Commanders come down from the sky. Each one is drawn falling from
-- HEIGHT, slowing as it nears the ground (UnitRenderer.lift), wrapped in a
-- star flare (a white-gold glow with a light and a fading trail above it)
-- that flashes out on touchdown. On the render clock, so it follows the
-- sim's speed.

local Pregame = require("../Core/Pregame")
local World = require("../Core/World")

local Landing = {}

Landing.HEIGHT = 260 -- studs above the pick at the start
Landing.TRAIL = 70 -- studs of trail over the falling Commander
Landing.FLASH = 0.35 -- seconds the touchdown flash fades over

local GOLD = Color3.fromRGB(255, 236, 170)

export type Flare = { ball: Part, trail: Part, light: PointLight }
export type Landing = { folder: Folder, flares: { [number]: Flare }, flashes: { { flare: Flare, at: number } } }

local function isCommander(def: any): boolean
	return def ~= nil and table.find(def.categories or {}, "COMMANDER") ~= nil
end

-- The drawn height above the ground, 0..HEIGHT, at landing fraction `f`.
function Landing.height(f: number): number
	return Landing.HEIGHT * (1 - f) ^ 2
end

function Landing.new(): Landing
	local folder = Instance.new("Folder")
	folder.Name = "FtggLanding"
	folder.Parent = workspace
	return { folder = folder, flares = {}, flashes = {} }
end

-- The lift for UnitRenderer.lift: Commanders while the landing lasts.
function Landing.lift(world: World.World): (u: World.Unit, def: any, t: number) -> number
	return function(_u: World.Unit, def: any, t: number): number
		local f = Pregame.landing(world, t)
		if f == nil or not isCommander(def) then
			return 0
		end
		return Landing.height(f)
	end
end

local function part(parent: Instance, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Transparency = transparency
	p.Parent = parent
	return p
end

local function flare(l: Landing): Flare
	local ball = part(l.folder, 0.1)
	ball.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 40
	light.Brightness = 6
	light.Parent = ball
	local trail = part(l.folder, 0.5)
	trail.Shape = Enum.PartType.Cylinder
	return { ball = ball, trail = trail, light = light }
end

-- Once a frame, after the renderer placed the units (`t` the render tick).
function Landing.step(l: Landing, world: World.World, t: number, now: number)
	local f = Pregame.landing(world, t)
	local seen: { [number]: boolean } = {}
	if f ~= nil then
		for id, u in world.units do
			if u.rx and u.ry and u.rz and isCommander(World.def(world, u)) then
				seen[id] = true
				local fl = l.flares[id] or flare(l)
				l.flares[id] = fl
				local size = 14 + 10 * (1 - f)
				fl.ball.Size = Vector3.new(size, size, size)
				fl.ball.CFrame = CFrame.new(u.rx, u.ry + 6, u.rz)
				fl.trail.Size = Vector3.new(Landing.TRAIL, 3 + 4 * (1 - f), 3 + 4 * (1 - f))
				fl.trail.CFrame = CFrame.new(u.rx, u.ry + 6 + Landing.TRAIL / 2, u.rz) * CFrame.Angles(0, 0, math.pi / 2)
				fl.trail.Transparency = 0.4 + 0.5 * f
			end
		end
	end
	-- touched down (or gone): flash out
	for id, fl in l.flares do
		if not seen[id] then
			l.flares[id] = nil
			fl.trail:Destroy()
			table.insert(l.flashes, { flare = fl, at = now })
		end
	end
	for i = #l.flashes, 1, -1 do
		local fx = l.flashes[i]
		local k = (now - fx.at) / Landing.FLASH
		if k >= 1 then
			fx.flare.ball:Destroy()
			table.remove(l.flashes, i)
		else
			local size = 24 + 40 * k
			fx.flare.ball.Size = Vector3.new(size, size, size)
			fx.flare.ball.Transparency = 0.1 + 0.9 * k
			fx.flare.light.Brightness = 8 * (1 - k)
		end
	end
end

return Landing
