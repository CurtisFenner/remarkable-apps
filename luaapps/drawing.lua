package.path = "/home/root/luaapps/?.lua"

local font = require "library/font"

local width, height = rm_fb:size()


print("Starting...")
for y = 0, height - 1 do
	for x = 0, width - 1 do
		local color =  2 ^ 16 - 1
		if x == 0 or y == 0 or x == width - 1 or y == height - 1 then
			color = 0
		end
		rm_fb:setPixel(x, y, color)
	end
end

font.renderString(rm_fb, font.CMU32, 64, height - 64, "Welcome.")

rm_fb:flush(0, 0, width, height, 2)

print("Reset.")

while true do
	rm_pen:poll(function(pen)
		if not pen.touching then
			return
		end
		
		local brush
		local color
		if pen.hoverDraw then
			brush = 2
			color = 0
		else
			brush = 12
			color = 2^16 - 1
		end

		for y = pen.yPos - brush, pen.yPos + brush do
			for x = pen.xPos - brush, pen.xPos + brush do
				if 0 <= x and x < width and 0 <= y and y < height then
					rm_fb:setPixel(x, y, color)
				end
			end
		end
		rm_fb:flush(math.max(0, pen.xPos - brush), math.max(0, pen.yPos - brush), math.min(width, pen.xPos + brush), math.min(height, pen.yPos + brush), 1)
	end)
end
