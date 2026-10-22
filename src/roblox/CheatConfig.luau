--!strict
-- Who may cheat (C-119; the cheat commands are the sim's, net.md 9a): a
-- player's CHEAT commands reach the sim only if the match allows cheats
-- (always in Studio; elsewhere only when the host turned "Cheats" on in the
-- lobby) AND their UserId is on this list. Public matchmaking never allows
-- them (there is none yet; a queue must leave `cheats` off).

return table.freeze({
	allow = table.freeze({
		[11846985184] = true, -- hungluu344 (the user)
	}) :: { [number]: boolean },
})
