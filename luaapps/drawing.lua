package.path = "/home/root/luaapps/?.lua"

local font = require "library/font"
local ui = require "library/ui"

setmetatable(_G, {
	__index = function(_, var)
		error("attempting to read undefined global `" .. tostring(var) .. "`", 2)
	end,
})

local width, height = rm_fb:size()

local WHITE = 2 ^ 16 - 1
local BLACK = 0

local background = ui.Box.new({left = 0, top = 0, right = width, bottom = height}, WHITE)
local title = ui.TextBox.new(font.CMU32, {left = 500, right = 600, top = 500, bottom = 532}, "")
local cursor = ui.Box.new({left = 32, top = 32, right = 80, bottom = 100}, BLACK)

local lines = {}
local scene = {background, cursor}
for i = 1, 16 do
	table.insert(lines, ui.Line.new(1, 1, math.random(500), math.random(500)))
	table.insert(scene, lines[i])
end

-- local page = ui.VisualStack.new({background, title, cursor})
local page = ui.VisualStack.new(scene)

local wasTapped = false

print("Initialized.");
while true do
	ui.renderFrame(rm_fb, page)

	local r = width / 4
	local cube = {}
	local time = os.clock()
	for h = 0, 1 do
		for t = 0, 3 do
			local a = t * math.pi / 2 + time
			local x = width / 2 + r * math.sqrt(2) * math.cos(a)
			local y = height / 2 + r * math.sqrt(2) * math.sin(a) / 2 - h * 2 * r * (1 - 0.5 ^ 2) ^ 0.5
			table.insert(cube, {math.floor(x), math.floor(y)})
		end
	end
	for i = 1, 4 do
		lines[i]:set(cube[i][1], cube[i][2], cube[i % 4 + 1][1], cube[i % 4 + 1][2])
	end
	for i = 5, 8 do
		lines[i]:set(cube[i][1], cube[i][2], cube[i % 4 + 5][1], cube[i % 4 + 5][2])
	end

	rm_pen:poll(function(pen)
		if pen.touching then
			if not wasTapped then
				wasTapped = true
				cursor:setArea({
					left = pen.xPos - math.random(5, 100),
					right = pen.xPos + math.random(5, 100),
					top = pen.yPos - math.random(5, 100),
					bottom = pen.yPos + math.random(5, 100),
				})
			end
		else
			wasTapped = false
		end
	end)
end
