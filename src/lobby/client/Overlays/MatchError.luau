--!strict
-- Why you couldn't reach (or stay in) a match (F38, L-21): the code, its
-- title and description, and the detail, in a panel you dismiss. The errors
-- wait in your view (`v.errors`) until you do, so one that happened while
-- you were arriving isn't lost; each shows once, oldest first.

local MatchErrors = require("../../shared/MatchErrors")
local Net = require("../Net")
local Ui = require("../Ui")

local Kit = Ui.Kit

local MatchError = {}

function MatchError.new(gui: ScreenGui): any
	local shown: { [number]: boolean } = {}
	local openId: number? = nil

	local function show(e: any)
		local entry = MatchErrors.LIST[e.code] or MatchErrors.LIST[299]
		local p = Kit.panel(gui, "Couldn't reach the match", Vector2.new(560, if e.detail then 262 else 230))
		p.root.Name = "MatchError"
		p.root.ZIndex = 47
		p.scrim.ZIndex = 46
		openId = e.id
		local function close()
			p.root:Destroy()
			p.scrim:Destroy()
			openId = nil
			Net.send({ op = "dismissError", id = e.id })
		end
		Kit.list(p.content, Kit.SPACE.s)
		local code = Kit.text(p.content, `Error {e.code}`, "small", Kit.COLOR.defeat)
		code.FontFace = Kit.font(Enum.FontWeight.Bold)
		code.Size = UDim2.new(1, 0, 0, 18)
		code.LayoutOrder = 1
		local title = Kit.text(p.content, entry.title, "title", Kit.COLOR.text)
		title.TextSize = 26
		title.Size = UDim2.new(1, 0, 0, 34)
		title.LayoutOrder = 2
		local desc = Kit.text(p.content, entry.description, "label", Kit.COLOR.text)
		desc.TextWrapped = true
		desc.Size = UDim2.new(1, 0, 0, 40)
		desc.LayoutOrder = 3
		if e.detail then
			local d = Kit.text(p.content, e.detail, "small", Kit.COLOR.dim)
			d.TextWrapped = true
			d.TextTruncate = Enum.TextTruncate.AtEnd
			d.Size = UDim2.new(1, 0, 0, 30)
			d.LayoutOrder = 4
		end
		local b = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 36))
		b.LayoutOrder = 5
		local bl = Kit.list(b, Kit.SPACE.s, true)
		bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		Ui.button(b, "OK", "primary", close, 120, 34)
	end

	return {
		update = function(v: any)
			if openId ~= nil or type(v.errors) ~= "table" then
				return
			end
			for _, e in v.errors do
				if not shown[e.id] then
					shown[e.id] = true
					show(e)
					return -- the next one after this is dismissed (the view then drops it)
				end
			end
		end,
	}
end

return MatchError
