--!strict
-- Posts a message to Discord through a webhook (the user's queue, item 2).
--   lune run notify "<text>"
--   lune run notify --file <path>      (a Markdown summary, for example)
-- The webhook URL comes from the environment variable DISCORD_WEBHOOK_URL.
-- Without it this does nothing and exits 0, so scripts can always call it.
-- Messages longer than Discord's 2,000 characters are split on line breaks.
-- A failed post prints the status and exits 1; the URL is never printed.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local LIMIT = 1900 -- under Discord's 2,000, with room for a "(1/3)" tag

local url = process.env.DISCORD_WEBHOOK_URL
if url == nil or url == "" then
	print("notify: DISCORD_WEBHOOK_URL is not set; nothing sent")
	process.exit(0)
end

local text: string
if process.args[1] == "--file" then
	local path = process.args[2]
	if path == nil or not fs.isFile(path) then
		print(`notify: no such file: {tostring(path)}`)
		process.exit(1)
	end
	text = fs.readFile(path :: string)
else
	text = table.concat(process.args, " ")
end
if text == "" then
	print("notify: empty message; nothing sent")
	process.exit(0)
end

-- split on line breaks (a single over-long line is cut hard)
local chunks: { string } = {}
local current = ""
for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
	while #line > LIMIT do
		if current ~= "" then
			table.insert(chunks, current)
			current = ""
		end
		table.insert(chunks, string.sub(line, 1, LIMIT))
		line = string.sub(line, LIMIT + 1)
	end
	if #current + #line + 1 > LIMIT then
		table.insert(chunks, current)
		current = line
	else
		current = if current == "" then line else current .. "\n" .. line
	end
end
if current ~= "" then
	table.insert(chunks, current)
end

for i, chunk in chunks do
	local content = if #chunks > 1 then `{chunk}\n({i}/{#chunks})` else chunk
	local ok, response = pcall(net.request, {
		url = url :: string,
		method = "POST",
		headers = { ["Content-Type"] = "application/json" },
		body = serde.encode("json", { content = content, allowed_mentions = { parse = {} } }),
	})
	if not ok then
		-- (the error text may hold the URL: not printed)
		print(`notify: could not reach the webhook on part {i} of {#chunks}`)
		process.exit(1)
	end
	if not response.ok then
		print(`notify: Discord answered {response.statusCode} {response.statusMessage} on part {i} of {#chunks}`)
		process.exit(1)
	end
end
print(`notify: sent {#chunks} message(s)`)
