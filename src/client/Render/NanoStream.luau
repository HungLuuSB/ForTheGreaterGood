--!strict
-- A nano stream (the user: "spray nano particles" instead of a light beam):
-- small glowing sparkles shot from a nozzle to where they build, fading as
-- they arrive, fanning out a little. One ParticleEmitter on an attachment
-- of our own aimed at the target each frame; the particles' speed and
-- lifetime follow the distance, so they reach the target and no further.
-- Builders' spray (BuildSpray) and factories' (FactoryFrames) use it.

local NanoStream = {}

NanoStream.TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
NanoStream.RATE = 90 -- particles a second per stream (48 read as a few specks in Studio)
NanoStream.SPREAD = 6 -- degrees: how wide the stream fans
NanoStream.MIN_SPEED = 16 -- studs a second
NanoStream.MAX_SPEED = 90
NanoStream.TRIP = 0.55 -- seconds a particle takes to arrive, when the speed allows

export type Stream = {
	at: Attachment,
	emitter: ParticleEmitter,
	length: number, -- the distance the speed and lifetime were set for
	color: Color3?,
}

function NanoStream.new(parent: Instance): Stream
	local at = Instance.new("Attachment")
	at.Name = "NanoStream"
	local e = Instance.new("ParticleEmitter")
	e.Name = "Nano"
	e.Texture = NanoStream.TEXTURE
	e.EmissionDirection = Enum.NormalId.Front -- along the attachment's look, aimed at the target
	e.Rate = NanoStream.RATE
	e.SpreadAngle = Vector2.new(NanoStream.SPREAD, NanoStream.SPREAD)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 3
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.4, 0.8),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0.05),
		NumberSequenceKeypoint.new(0.8, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.ZOffset = 0.3
	e.Enabled = false
	e.Parent = at
	at.Parent = parent
	return { at = at, emitter = e, length = -1, color = nil }
end

-- Sprays from `from` to `to` in `color` this frame.
function NanoStream.aim(s: Stream, from: Vector3, to: Vector3, color: Color3)
	local d = to - from
	local len = d.Magnitude
	if len < 0.5 then
		NanoStream.off(s)
		return
	end
	s.at.WorldCFrame = CFrame.lookAt(from, to)
	if math.abs(len - s.length) > 0.5 then
		s.length = len
		local speed = math.clamp(len / NanoStream.TRIP, NanoStream.MIN_SPEED, NanoStream.MAX_SPEED)
		local life = len / speed
		s.emitter.Speed = NumberRange.new(speed)
		s.emitter.Lifetime = NumberRange.new(life * 0.85, life)
	end
	if s.color ~= color then
		s.color = color
		-- white-hot as they leave the nozzle, the stream's colour on the way
		s.emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1):Lerp(color, 0.4)),
			ColorSequenceKeypoint.new(0.3, color),
			ColorSequenceKeypoint.new(1, color),
		})
	end
	if not s.emitter.Enabled then
		s.emitter.Enabled = true
	end
end

-- Stops emitting; the particles in flight finish their trip.
function NanoStream.off(s: Stream)
	if s.emitter.Enabled then
		s.emitter.Enabled = false
	end
end

function NanoStream.destroy(s: Stream)
	s.at:Destroy()
end

return NanoStream
