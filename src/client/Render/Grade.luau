--!strict
-- The colour grade on screen (C-102): the atmosphere preset's colour
-- correction eased with zoom and warmed by big blasts (Core/Grade), written
-- to Lighting's ColorCorrection each frame, and the vignette, an image
-- drawn once in an EditableImage under all the UI. Client only.

local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local CoreGrade = require("../Core/Grade")
local Atmosphere = require("./Atmosphere")

local Grade = {}

Grade.VIEW = 1.2 -- a blast counts within this many camera distances of the focus
local SIZE = 256 -- vignette image side (256 KB of editable memory)

export type State = {
	flash: CoreGrade.Flash,
	label: ImageLabel?,
	failed: boolean, -- no editable memory: no vignette
	focusX: number,
	focusZ: number,
	distance: number,
	scratch: CoreGrade.Color,
	written: { number }, -- last values written (skip unchanged frames)
}

function Grade.new(): State
	return {
		flash = CoreGrade.newFlash(),
		label = nil,
		failed = false,
		focusX = 0,
		focusZ = 0,
		distance = 300,
		scratch = { brightness = 0, contrast = 0, saturation = 0, tint = { 255, 255, 255 } },
		written = {},
	}
end

local function vignette(state: State): ImageLabel?
	if state.label or state.failed then
		return state.label
	end
	-- create, write and wrap in one pcall: where the experience doesn't allow
	-- EditableImage the create can succeed and the write throw (C-214)
	local ok, content = pcall(function()
		local made = AssetService:CreateEditableImage({ Size = Vector2.new(SIZE, SIZE) })
		made:WritePixelsBuffer(Vector2.zero, Vector2.new(SIZE, SIZE), CoreGrade.vignette(SIZE, 4, 6, 12))
		return Content.fromObject(made)
	end)
	local playerGui = (Players.LocalPlayer :: Player):FindFirstChildOfClass("PlayerGui")
	if not ok or content == nil or playerGui == nil then
		state.failed = true
		warn("[Client] no vignette: editable images unavailable (memory, or the experience's setting)")
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10 -- under every other interface
	local label = Instance.new("ImageLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Active = false
	label.ImageContent = content
	label.Parent = gui
	gui.Parent = playerGui
	state.label = label
	return label
end

-- A blast (Vfx.onSpawn): flashes the grade if it is big and near the focus.
function Grade.burst(state: State, kind: string, x: number, z: number, scale: number)
	local dx, dz = x - state.focusX, z - state.focusZ
	CoreGrade.burst(state.flash, kind, scale, math.sqrt(dx * dx + dz * dz), state.distance * Grade.VIEW)
end

-- Once a frame, after the camera moved.
function Grade.update(state: State, x: number, z: number, distance: number, dt: number)
	state.focusX, state.focusZ, state.distance = x, z, distance
	CoreGrade.step(state.flash, dt)
	local color, strength = Atmosphere.grade()
	local t = CoreGrade.zoom(distance)
	local cc = Lighting:FindFirstChild("FtggColor") -- made by Atmosphere
	if color and cc and cc:IsA("ColorCorrectionEffect") then
		local c = state.scratch
		c.brightness, c.contrast, c.saturation = color.brightness, color.contrast, color.saturation
		c.tint[1], c.tint[2], c.tint[3] = color.tint.R * 255, color.tint.G * 255, color.tint.B * 255
		local b, k, s, r, g, bl = CoreGrade.mix(c, t)
		local fb, fk, fs, fr, fg, fbl = CoreGrade.flash(state.flash)
		b, k, s, r, g, bl = b + fb, k + fk, s + fs, r * fr / 255, g * fg / 255, bl * fbl / 255
		local w = state.written
		if w[1] ~= b or w[2] ~= k or w[3] ~= s or w[4] ~= r or w[5] ~= g or w[6] ~= bl then
			w[1], w[2], w[3], w[4], w[5], w[6] = b, k, s, r, g, bl
			cc.Brightness, cc.Contrast, cc.Saturation = b, k, s
			cc.TintColor = Color3.fromRGB(r, g, bl)
		end
	end
	local v = strength * (1 + (CoreGrade.FAR_VIGNETTE - 1) * t)
	if v > 0 then
		local label = vignette(state)
		if label then
			label.ImageTransparency = 1 - v
			label.Visible = true
		end
	elseif state.label then
		state.label.Visible = false
	end
end

return Grade
