--!strict
-- The team's radar accuracy in the missile sensor view (C-181, the user's
-- request through the sim stream; S-147): what radar-fired weapons
-- actually miss by. The Eco record carries it with the Pinpointers already
-- applied: a shot at a radar contact aims at a point circling it at
-- `radarError`, at a contact under fire-control radar (TRACKED) at
-- `trackError`. The view draws that circle round each radar blip and a
-- readout line. Sonar contacts get no circle (radar numbers don't apply).

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local RadarAccuracy = {}

local SF = Schema.StrategicFlag

export type Accuracy = {
	radar: number?, -- studs; nil without a radar
	track: number?, -- studs; nil without a fire-control radar
	precision: number, -- Pinpointer precision 0..1
}

export type Ring = { id: number, x: number, z: number, radius: number, tracked: boolean }

-- From the own team's Eco record; nil before one arrives.
function RadarAccuracy.of(eco: Schema.Eco?): Accuracy?
	if eco == nil or eco.radarError == nil then
		return nil
	end
	local function studs(tenths: number?): number?
		return if tenths and tenths > 0 then tenths / 10 else nil
	end
	return { radar = studs(eco.radarError), track = studs(eco.trackError), precision = (eco.precision or 0) / 255 }
end

-- A circle per radar contact (where its blip is drawn), the radius its
-- radar-fired shots miss by; tracked ones the fire-control radius.
function RadarAccuracy.rings(world: World.World, acc: Accuracy?): { Ring }
	local out = {}
	if acc == nil or (acc.radar == nil and acc.track == nil) then
		return out
	end
	for id, u in world.units do
		if u.tier == "tactical" then
			continue
		end
		local flags = u.flags or 0
		if bit32.band(flags, SF.RADAR_ONLY) == 0 or bit32.band(flags, SF.GHOST + SF.SONAR_ONLY) ~= 0 then
			continue
		end
		local tracked = bit32.band(flags, SF.TRACKED) ~= 0 and acc.track ~= nil
		local radius = if tracked then acc.track else acc.radar
		if radius then
			table.insert(out, { id = id, x = u.sx or u.x, z = u.sz or u.z, radius = radius, tracked = tracked })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

local function studsText(v: number): string
	return if v < 10 then string.format("±%.1f", v) else string.format("±%d", math.floor(v + 0.5))
end

-- The readout: "Radar accuracy ±1.6 studs · tracked ±0.4 · Pinpointers 50%".
function RadarAccuracy.readout(acc: Accuracy?): string
	if acc == nil or (acc.radar == nil and acc.track == nil) then
		return "Radar accuracy: no radar"
	end
	local parts = {}
	if acc.radar then
		table.insert(parts, `Radar accuracy {studsText(acc.radar)} studs`)
	end
	if acc.track then
		table.insert(parts, if acc.radar then `tracked {studsText(acc.track)}` else `Tracked accuracy {studsText(acc.track)} studs`)
	end
	table.insert(parts, if acc.precision > 0 then string.format("Pinpointers %d%%", math.floor(acc.precision * 100 + 0.5)) else "no Pinpointers")
	return table.concat(parts, "  ·  ")
end

return RadarAccuracy
