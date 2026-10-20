--!strict
-- Tagged, levelled logging. DEBUG is off by default so sim systems can keep
-- their debug lines without spamming output.
--
--   local log = Log.new("Sim")
--   log:info("tick %d took %.2f ms", tick, ms)

local Env = require("./Env")

local Log = {}

Log.Level = table.freeze({
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	OFF = 5,
})

local LEVEL_NAMES = table.freeze({ "DEBUG", "INFO", "WARN", "ERROR" })

export type Sink = (level: number, line: string) -> ()

local function defaultSink(level: number, line: string)
	-- Roblox's warn() highlights the line in Output. Lune's warn() adds its own
	-- "[WARN]" header, so plain print keeps Lune output to one line per entry.
	if Env.isRoblox and level >= Log.Level.WARN then
		warn(line)
	else
		print(line)
	end
end

local currentLevel = Log.Level.INFO
local currentSink: Sink = defaultSink

function Log.setLevel(level: number)
	currentLevel = level
end

function Log.getLevel(): number
	return currentLevel
end

-- Redirects output (e.g. to capture it in a test). nil restores the default.
function Log.setSink(sink: Sink?)
	currentSink = sink or defaultSink
end

function Log.isEnabled(level: number): boolean
	return level >= currentLevel
end

local Logger = {}
Logger.__index = Logger

type LoggerData = { tag: string }
export type Logger = typeof(setmetatable({} :: LoggerData, Logger))

local function emit(self: Logger, level: number, fmt: string, ...: any)
	if level < currentLevel then
		return
	end
	-- Only format when arguments are given, so a literal "%" in a plain message is safe.
	local message = if select("#", ...) > 0 then string.format(fmt, ...) else fmt
	currentSink(level, `[{LEVEL_NAMES[level]}][{self.tag}] {message}`)
end

function Logger.debug(self: Logger, fmt: string, ...: any)
	emit(self, Log.Level.DEBUG, fmt, ...)
end

function Logger.info(self: Logger, fmt: string, ...: any)
	emit(self, Log.Level.INFO, fmt, ...)
end

function Logger.warn(self: Logger, fmt: string, ...: any)
	emit(self, Log.Level.WARN, fmt, ...)
end

-- Logs only; never throws. Use error() when execution must stop.
function Logger.error(self: Logger, fmt: string, ...: any)
	emit(self, Log.Level.ERROR, fmt, ...)
end

function Log.new(tag: string): Logger
	return setmetatable({ tag = tag }, Logger)
end

return Log
