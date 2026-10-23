--!strict
-- The animated pieces every unit has besides its own script (C-156; rig.md
-- section 9, Core/PieceMotion), re-planned whenever its state changes:
--   spin    wheels roll while the unit moves; windmill rotors always turn;
--           a helicopter's tail rotor runs with the main rotor (Default
--           owns `rotor`); jammer emitters spin while powered
--   turn    radars, dishes, arrays and sonar drums sweep round while
--           powered; extractor drills turn while powered; cranes and jibs
--           swing back and forth while powered
--   slide   factory gantries and trolleys run along their rail while the
--           factory produces
--   scroll  track sets judder while the unit moves (no texture scroll yet)
-- Powered pieces run slower when the team's power stalls and stop when
-- it's out, the unit is switched off or not finished. `open`, `lower`,
-- `pulse` and `swing` belong to other scripts (beam tower lids, Commander
-- walk) or the glow (cores). Only the pieces named here move: any other
-- spin or turn piece (the Commander mech's torso and head) is left to its
-- unit's own script (the user: the Commander kept rotating, C-172).

local Ambient = {}

Ambient.SIGNAL = 2 ^ 20 -- signal bit of Ambient's loops (scripts use the low bits)
Ambient.WHEEL = 400 -- degrees per second while moving
Ambient.WINDMILL = 90
Ambient.RADAR = 60
Ambient.DRUM = 40
Ambient.DRILL = 160
Ambient.JAMMER = 240
Ambient.ROTOR = 1440 -- tail rotor, as Default.ROTOR_SPEED
Ambient.SPIN_UP = 180 -- degrees per second²: powered pieces wind up and down
Ambient.JIB = 30 -- degrees each way a crane swings
Ambient.JIB_SECONDS = 4 -- one way
Ambient.SLIDE_SECONDS = 2.5 -- a gantry's run, one way
Ambient.JUDDER = 0.05 -- studs a track set bobs
Ambient.JUDDER_SECONDS = 0.09

local RADARS = { radar = true, dish = true, array = true, radarPanel = true, mastArray = true }
local DRUMS = { drum = true, ring = true }
local JIBS = { jib = true, jib1 = true, jib2 = true, deckJib = true, deckCrane = true }
local JAMMERS = { band = true, tip = true, spine = true }

local function spinTo(u: any, m: any, speed: number)
	if speed == 0 then
		u:StopSpin(m.piece, m.axis, Ambient.SPIN_UP)
	else
		u:Spin(m.piece, m.axis, speed * m.sign, Ambient.SPIN_UP)
	end
end

-- Re-plans every animated piece of `u` for `mode` (Core/PieceMotion.Mode).
function Ambient.apply(u: any, motions: { any }, mode: any)
	u:Signal(Ambient.SIGNAL) -- ends the loops of the last plan
	local heli = u.def.moveClass == "HELI"
	for _, m in motions do
		local name = m.piece
		if m.motion == "spin" then
			if string.sub(name, 1, 5) == "wheel" then
				if mode.moving then
					u:Spin(name, m.axis, Ambient.WHEEL * m.sign)
				else
					u:StopSpin(name, m.axis, Ambient.WHEEL * 2)
				end
			elseif name == "rotor" and heli then
				-- Default's
			elseif name == "tailRotor" then
				if mode.landed then
					u:StopSpin(name, m.axis, Ambient.ROTOR / 2)
				else
					u:Spin(name, m.axis, Ambient.ROTOR * m.sign, Ambient.ROTOR / 2)
				end
			elseif name == "rotor" then
				u:Spin(name, m.axis, Ambient.WINDMILL * m.sign, Ambient.SPIN_UP) -- the wind always blows
			elseif JAMMERS[name] then
				spinTo(u, m, Ambient.JAMMER * mode.power) -- jammer emitters
			end
		elseif m.motion == "turn" then
			if RADARS[name] then
				spinTo(u, m, Ambient.RADAR * mode.power)
			elseif DRUMS[name] then
				spinTo(u, m, Ambient.DRUM * mode.power)
			elseif name == "drill" then
				spinTo(u, m, Ambient.DRILL * mode.power)
			elseif JIBS[name] then
				if mode.power > 0 then
					u:StartThread(function()
						u:SetSignalMask(Ambient.SIGNAL)
						local speed = Ambient.JIB * 2 / Ambient.JIB_SECONDS * mode.power
						while true do
							u:Turn(name, m.axis, Ambient.JIB, speed)
							u:WaitForTurn(name, m.axis)
							u:Turn(name, m.axis, -Ambient.JIB, speed)
							u:WaitForTurn(name, m.axis)
						end
					end)
				else
					u:Turn(name, m.axis, 0, Ambient.JIB / Ambient.JIB_SECONDS)
				end
			end
		elseif m.motion == "slide" then
			local range = (m.range or 4) * m.sign
			if mode.producing then
				u:StartThread(function()
					u:SetSignalMask(Ambient.SIGNAL)
					local speed = math.abs(range) / Ambient.SLIDE_SECONDS
					while true do
						u:Move(name, m.axis, range, speed)
						u:WaitForMove(name, m.axis)
						u:Move(name, m.axis, 0, speed)
						u:WaitForMove(name, m.axis)
					end
				end)
			else
				u:Move(name, m.axis, 0, math.abs(range) / Ambient.SLIDE_SECONDS)
			end
		elseif m.motion == "scroll" then
			if mode.moving then
				u:StartThread(function()
					u:SetSignalMask(Ambient.SIGNAL)
					local up = true
					while true do
						u:Move(name, "y", if up then Ambient.JUDDER else 0, Ambient.JUDDER * 2 / Ambient.JUDDER_SECONDS)
						u:Sleep(Ambient.JUDDER_SECONDS)
						up = not up
					end
				end)
			else
				u:Move(name, "y", 0, Ambient.JUDDER * 4)
			end
		end
	end
end

return Ambient
