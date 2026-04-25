--!strict
-- Tiny formatting helpers for the score screen and HUD.

local NumberFormatter = {}

function NumberFormatter.Comma(n: number): string
	local formatted = tostring(math.floor(n))
	while true do
		local result, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = result
		if count == 0 then
			break
		end
	end
	return formatted
end

function NumberFormatter.Time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local m = math.floor(total / 60)
	local s = total % 60
	return string.format("%d:%02d", m, s)
end

function NumberFormatter.Plural(n: number, singular: string, plural: string?): string
	if n == 1 then
		return singular
	end
	return plural or (singular .. "s")
end

return NumberFormatter
