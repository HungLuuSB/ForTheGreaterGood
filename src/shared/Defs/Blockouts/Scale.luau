--!strict
-- Uniformly scaled blockouts (size scale, M-26, S-104): a structure whose
-- footprint grew keeps its placeholder layout, scaled about the model origin
-- (on the ground under its centre), until its redesigned mesh is approved.
-- Parts, pivots and attachments scale; rotations and colors don't. Separate
-- from Blockout.luau, which requires the Registry that requires these files.

local Scale = {}

local function mul(v: { number }?, s: number): { number }?
	if v == nil then
		return nil
	end
	return { v[1] * s, v[2] * s, v[3] * s }
end

function Scale.scaled(bp: any, s: number): any
	local parts = {}
	for _, p in bp.parts do
		local q = table.clone(p)
		q.size = mul(p.size, s)
		q.at = mul(p.at, s)
		q.pivot = mul(p.pivot, s)
		table.insert(parts, q)
	end
	local out = table.clone(bp)
	out.parts = parts
	if bp.attachments then
		local atts = {}
		for _, a in bp.attachments do
			local b = table.clone(a)
			b.at = mul(a.at, s) :: { number }
			table.insert(atts, b)
		end
		out.attachments = atts
	end
	return out
end

return Scale
