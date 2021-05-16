package.path = "/home/root/luaapps/?.lua"

setmetatable(_G, {
	__index = function(_, var)
		error("undefined variable `" .. tostring(var) .. "`")
	end,
})

local width, height = rm_fb:size()

local function mandel(a, b)
	local x = 0
	local y = 0
	for i = 1, 36 do
		-- (x + yi) ^ 2 = (x ^ 2 - y ^ 2) + 2xy
		x, y = x * x - y * y, 2 * x * y

		-- (x + yi) + (a + bi) = (x + a) + (y + b)i
		x, y = x + a, y + b

		local m2 = x * x + y * y
		if m2 > 4 then
			return false
		end
	end
	return true
end

local scale = 4 * 0.5 / math.min(width, height)

local chunk = 32
while chunk >= 1 do
	for x = 0, width, chunk do
		for y = 0, height, chunk do
			local u = x + 0.5 * chunk - width / 2
			local v = y + 0.5 * chunk - height / 2
			u = u * scale
			v = v * scale
			local color = mandel(v - 0.5, u) and 0 or 2 ^ 16 - 1
			rm_fb:setRect(x, y, x + chunk, y + chunk, color)
			-- print(x, y, "=>", color, "at", chunk .. "x" .. chunk)
		end
		rm_fb:flush(x, 0, math.min(width, x + chunk), height, 1)
	end
	chunk = chunk / 2
end

print("Done!")
