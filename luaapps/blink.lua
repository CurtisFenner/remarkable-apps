local width, height = rm_fb:size()

print(rm_calendar:getSeconds())
print(rm_monotonic:getSeconds())

local center_x = math.floor(width / 2)
local center_y = math.floor(height / 2)

local radius = math.floor(math.min(width, height) / 6)

function busySleep(seconds)
        local start = rm_monotonic:getSeconds()
        local elapsed
        repeat
                elapsed = rm_monotonic:getSeconds() - start
        until elapsed > seconds
        return elapsed
end

busySleep(1)

local STRIP = 128
rm_fb:setRect(0, 0, width, STRIP * 2, 0)
rm_fb:flush(0, 0, width, STRIP * 2, 1)

busySleep(0.25)

for x = 0, width - 1 do
    for y = 0, STRIP - 1 do
        local t = x / width
        local d = math.floor(t * 15)
        local h = t * 15 - d
        if math.random() < h then
            d = d + 1
        end
        rm_fb:setPixel(x, y, math.random() > t and 0 or 2 ^ 16 - 1)
        rm_fb:setPixel(x, y + STRIP, d * 2)
    end
end
rm_fb:flush(0, 0, width, STRIP, 1)
print(busySleep(1.5))
rm_fb:flush(0, STRIP, width, STRIP + STRIP, 3)
print(busySleep(1.5))

function drawCheck(b)
        local color1 = math.random(0, 2 ^ 16 - 1) -- b and 0 or 2 ^ 16 - 1
        local color2 = math.random(0, 2 ^ 16 - 1) --b and 2 ^ 16 - 1 or 0

        rm_fb:setRect(center_x - radius, center_y - radius, center_x, center_y, color1)
        rm_fb:setRect(center_x, center_y - radius, center_x + radius, center_y, color2)

        rm_fb:setRect(center_x - radius, center_y, center_x, center_y + radius, color2)
        rm_fb:setRect(center_x, center_y, center_x + radius, center_y + radius, color1)

        rm_fb:flush(center_x - radius, center_y - radius, center_x + radius, center_y + radius, 3)
end

local PAUSE = 1.5

for i = 1, 10 do
        drawCheck(true)
        busySleep(PAUSE)
        drawCheck(false)
        busySleep(PAUSE)
end

-- Waveform 3:
-- Renders color, but goes white -> black -> gray, taking about 1 second.
-- Colors are (black) 0, (grays) 2, 4, 6, 8, ..., (white)32

-- Waveform 1:
-- Renders black/white only, but takes only about 0.2 seconds.
-- Colors are 0, 2 ^ 16 - 1?

-- Drawing nearly black dark grays with 3 on top of black seems to have some
-- coloring artifacts.
