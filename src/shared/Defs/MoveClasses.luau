--!strict
-- Movement classes (guide 6.1). `bit` is the class's bit in the passMask
-- layer (bit i = value 2^i); never renumber, only append.
--
--   surface   land | water | land+water (hover: on the surface) | land+seafloor (amphib) | air
--   maxSlope  degrees; nil = not limited
--   maxFord   deepest water (studs) a land class can drive through
--   minDepth  shallowest water (studs) a naval class can enter
--   pathing   flowfield | steering

export type MoveClass = {
	id: string,
	bit: number,
	surface: "land" | "water" | "hover" | "amphib" | "air",
	maxSlope: number?,
	maxFord: number?,
	minDepth: number?,
	pathing: "flowfield" | "steering",
}

local classes: { [string]: MoveClass } = {
	WHEELED = { id = "WHEELED", bit = 0, surface = "land", maxSlope = 20, maxFord = 1, pathing = "flowfield" },
	TRACKED = { id = "TRACKED", bit = 1, surface = "land", maxSlope = 30, maxFord = 2, pathing = "flowfield" },
	HEAVY_TRACKED = { id = "HEAVY_TRACKED", bit = 2, surface = "land", maxSlope = 25, maxFord = 2, pathing = "flowfield" },
	HOVER = { id = "HOVER", bit = 3, surface = "hover", maxSlope = 18, pathing = "flowfield" },
	AMPHIB = { id = "AMPHIB", bit = 4, surface = "amphib", maxSlope = 30, pathing = "flowfield" },
	SHIP = { id = "SHIP", bit = 5, surface = "water", minDepth = 6, pathing = "flowfield" },
	SUB = { id = "SUB", bit = 6, surface = "water", minDepth = 12, pathing = "flowfield" },
	HELI = { id = "HELI", bit = 7, surface = "air", pathing = "steering" },
	JET = { id = "JET", bit = 8, surface = "air", pathing = "steering" },
}

for _, mc in classes do
	table.freeze(mc)
end

return table.freeze(classes)
