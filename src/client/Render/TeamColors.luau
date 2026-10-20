--!strict
-- Team colors 1..8 (placeholder palette; needs review with the visual style).

local COLORS = {
	Color3.fromRGB(58, 120, 230), -- 1 blue
	Color3.fromRGB(214, 62, 48), -- 2 red
	Color3.fromRGB(64, 176, 84), -- 3 green
	Color3.fromRGB(232, 196, 52), -- 4 yellow
	Color3.fromRGB(150, 84, 210), -- 5 purple
	Color3.fromRGB(238, 132, 40), -- 6 orange
	Color3.fromRGB(60, 200, 210), -- 7 cyan
	Color3.fromRGB(226, 104, 170), -- 8 pink
}

return function(team: number): Color3
	return COLORS[team] or Color3.fromRGB(200, 200, 200)
end
