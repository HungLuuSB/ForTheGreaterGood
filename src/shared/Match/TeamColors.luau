--!strict
-- Player colours by side, as each viewer sees them (S-172, the user): every
-- player's colour is assigned automatically. To a viewer, it and its allies
-- are cold colours (blue, green, cyan shades: the viewer first, then its
-- allies by player ID); every enemy a warm one (red, orange, fuchsia and
-- yellow shades: by side, then player ID, so one side's players sit
-- together and the next side starts on another hue). Spectators see ally
-- team 1 (the lowest) as the cold side. Pure Luau; the client and the
-- lobby share it, so a player has the same colour on both.

local TeamColors = {}

export type Color = { name: string, rgb: { number } }

local function c(name: string, r: number, g: number, b: number): Color
	return table.freeze({ name = name, rgb = table.freeze({ r, g, b }) })
end

-- 8: a side of up to 8 (the viewer included)
TeamColors.COLD = table.freeze({
	c("Blue", 64, 132, 230),
	c("Cyan", 60, 200, 210),
	c("Green", 82, 186, 92),
	c("Navy", 38, 60, 150),
	c("Teal", 40, 130, 120),
	c("Sky", 130, 190, 250),
	c("Mint", 120, 230, 170),
	c("Forest", 40, 110, 60),
})

-- 16: up to 15 enemies (a 16-player FFA); hues alternate, light then dark
TeamColors.WARM = table.freeze({
	c("Red", 222, 70, 62),
	c("Orange", 238, 132, 46),
	c("Fuchsia", 225, 60, 190),
	c("Yellow", 236, 200, 64),
	c("Crimson", 160, 24, 40),
	c("Amber", 250, 168, 30),
	c("Magenta", 160, 40, 150),
	c("Gold", 196, 160, 40),
	c("Coral", 250, 120, 100),
	c("Tangerine", 255, 150, 80),
	c("Pink", 240, 130, 200),
	c("Lemon", 250, 230, 110),
	c("Brick", 170, 70, 40),
	c("Rust", 190, 100, 30),
	c("Plum", 120, 30, 90),
	c("Mustard", 170, 150, 40),
})

export type Player = { id: number, allyTeam: number }

-- Each player's colour to the viewer: `viewer` is a player ID (0 for a
-- spectator); `players` every player in the match (any order).
function TeamColors.forViewer(viewer: number, players: { Player }): { [number]: Color }
	local sorted = table.clone(players)
	table.sort(sorted, function(a, b)
		return a.id < b.id
	end)
	local own: number? = nil
	for _, p in sorted do
		if p.id == viewer then
			own = p.allyTeam
		end
	end
	if own == nil then
		-- a spectator: the lowest ally team is the cold side
		for _, p in sorted do
			own = math.min(own or math.huge, p.allyTeam)
		end
	end
	local out: { [number]: Color } = {}
	local cold = 0
	if viewer ~= 0 and own ~= nil then
		cold = 1
		out[viewer] = TeamColors.COLD[1]
	end
	for _, p in sorted do
		if p.allyTeam == own and out[p.id] == nil then
			cold += 1
			out[p.id] = TeamColors.COLD[(cold - 1) % #TeamColors.COLD + 1]
		end
	end
	local enemies = {}
	for _, p in sorted do
		if p.allyTeam ~= own then
			table.insert(enemies, p)
		end
	end
	table.sort(enemies, function(a, b)
		if a.allyTeam ~= b.allyTeam then
			return a.allyTeam < b.allyTeam
		end
		return a.id < b.id
	end)
	for k, p in enemies do
		out[p.id] = TeamColors.WARM[(k - 1) % #TeamColors.WARM + 1]
	end
	return out
end

return table.freeze(TeamColors)
