--!strict
-- The shield mechanic demo (C-87, on the C-90 dome): fake shells from all
-- round brake in the field, turn back or break through (Core/Shield's
-- repulsor), the charge drains per shell and recharges, the dome collapses
-- at 0% and rises again at 25%. It drives a Render/ShieldFx dome through its
-- interface (setStrength, hit, collapse, deploy), as the sim will. Studio
-- only, from FtggClientDebug:Invoke("shield").

local RunService = game:GetService("RunService")

local Shield = require("../Core/Shield")
local ShieldFx = require("./ShieldFx")

local ShieldDemo = {}

ShieldDemo.SHELLS = 40 -- a fixed pool of shell parts
ShieldDemo.SPEED = 260
local MASSES = { 0.5, 1, 1, 1, 2.5, 4 }

type Shot = { shell: Shield.Shell, part: Part, born: number }

-- A dome at `center` under fake fire for `seconds`. Returns a stop function.
function ShieldDemo.run(center: Vector3, radius: number, seconds: number?): () -> ()
	local fx = ShieldFx.new(center, radius)
	fx:deploy()
	local model = Shield.newDome({ x = center.X, y = center.Y, z = center.Z }, radius)
	local folder = Instance.new("Folder")
	folder.Name = "ShieldDemoShells"
	folder.Parent = workspace
	local free: { Part } = {}
	for _ = 1, ShieldDemo.SHELLS do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = folder
		table.insert(free, p)
	end
	local shots: { Shot } = {}
	local rng = Random.new()
	local t0 = os.clock()
	local nextShot = 0.8 -- after the dome is up
	local wasUp = true
	local conn: RBXScriptConnection
	local function stop()
		conn:Disconnect()
		folder:Destroy()
		fx:destroy()
	end
	conn = RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock() - t0
		if seconds and now > seconds then
			stop()
			return
		end
		Shield.recharge(model, dt)
		if now >= nextShot and #free > 0 then
			local mass = MASSES[rng:NextInteger(1, #MASSES)]
			local a = rng:NextNumber() * math.pi * 2
			local aim = center + Vector3.new(math.cos(a + 0.3), 0.3 + rng:NextNumber() * 0.6, math.sin(a + 0.3)).Unit * radius
			local from = center + Vector3.new(math.cos(a) * (radius + 200), radius * 0.6 + rng:NextNumber() * 40, math.sin(a) * (radius + 200))
			local part = table.remove(free) :: Part
			part.Size = Vector3.one * (0.5 + 0.45 * mass)
			part.Color = Color3.fromRGB(255, 190, 90)
			part.Transparency = 0
			local v = (aim - from).Unit * ShieldDemo.SPEED
			table.insert(shots, { shell = Shield.newShell({ x = from.X, y = from.Y, z = from.Z }, { x = v.X, y = v.Y, z = v.Z }, mass), part = part, born = now })
			nextShot = now + 0.2 + rng:NextNumber() * 0.3
		end
		for i = #shots, 1, -1 do
			local s = shots[i]
			local e = Shield.stepShell(s.shell, model, dt)
			if e and s.shell.hitAt then
				local h = s.shell.hitAt
				fx:hit(Vector3.new(h.x, h.y, h.z), if e == "breach" then s.shell.mass * 1.5 else s.shell.mass)
			end
			local p = s.shell.pos
			s.part.Position = Vector3.new(p.x, p.y, p.z)
			if s.shell.state == "braking" then
				-- the field heats it as it slows
				local k = 1 - Shield.len(s.shell.vel) / math.max(s.shell.entry, 1)
				s.part.Color = Color3.fromRGB(255, 190, 90):Lerp(Color3.new(1, 1, 1), math.clamp(k, 0, 1))
			end
			if now - s.born > 6 or p.y < center.Y - 5 then
				s.part.Transparency = 1
				table.insert(free, s.part)
				table.remove(shots, i)
			end
		end
		fx:setStrength(model.charge)
		if model.up ~= wasUp then
			wasUp = model.up
			if model.up then
				fx:deploy()
			else
				fx:collapse()
			end
		end
	end)
	return stop
end

return ShieldDemo
