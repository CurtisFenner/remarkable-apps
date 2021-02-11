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

local page = ui.VisualStack.new({background, title, cursor})

local wasTapped = false

print("Initialized.");
while true do
	ui.renderFrame(rm_fb, page)

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
