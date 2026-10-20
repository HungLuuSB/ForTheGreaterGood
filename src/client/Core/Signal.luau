--!strict
-- Minimal signal (pure Luau, C-7): Connect returns a disconnect function.

export type Signal<T> = {
	Connect: (self: Signal<T>, fn: (T) -> ()) -> () -> (),
	Fire: (self: Signal<T>, value: T) -> (),
}

local Signal = {}

function Signal.new<T>(): Signal<T>
	local handlers: { (T) -> () } = {}
	local self = {}
	function self.Connect(_, fn: (T) -> ()): () -> ()
		table.insert(handlers, fn)
		return function()
			local i = table.find(handlers, fn)
			if i then
				table.remove(handlers, i)
			end
		end
	end
	function self.Fire(_, value: T)
		for _, fn in table.clone(handlers) do
			fn(value)
		end
	end
	return (self :: any) :: Signal<T>
end

return Signal
