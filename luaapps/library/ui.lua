local font = require "library/font"

-- Defines a basic "visual element protocol" for making efficient use of screen
-- flushes, as well as some basic controls that implement that protocol.


-- Rectangle :: {left = int, right = int, top = int, bottom = int}

-- A VisualElement has several methods:

-- :plan(): old []Rectangle, new []Rectangle
-- RETURNS the old and new portions of the screen this element
-- renders on.
-- `old` is the portion of the area that was rendered by the last :plan(), but
-- which is not covered by the new plan.
-- MODIFIES the underlying VisualElement so that subsequent
-- calls to :plan() may return results reflecting the 
-- render.
-- (TODO: Indicate the needed waveform in these render regions)

-- :render(fb, regions)
-- Renders to the framebuffer ONLY within the given regions.
-- A bounding left/right/top/bottom is also added to the regions list.
-- This should NOT modify the state of the underlying VisualElement.

local clockStack = {}
local function clockOpen(name)
	-- print(string.rep("\t", #clockStack) .. "< " .. name .. " >")
	table.insert(clockStack, {name, os.clock()})
end

local function clockClose()
	local entry = table.remove(clockStack)
	-- print(string.format("%s</ %s = %.3f >", string.rep("\t", #clockStack), entry[1], os.clock() - entry[2]))
end

--------------------------------------------------------------------------------

local VisualElement = {}
VisualElement.__index = VisualElement

function VisualElement:plan()
	if self._stale == false then
		return {}, {}
	end

	local new = self:bounds()
	local old = self._lastPlan or {}
	self._lastPlan = new
	self._stale = false
	return old, new
end

--------------------------------------------------------------------------------

local ZERO_RECT = {type = "rect", left = 0, right = 0, top = 0, bottom = 0}

-- Implements VisualElement protocol.
local Box = setmetatable({}, VisualElement)
Box.__index = Box
function Box.new(area, color)
	assert(type(area.left) == "number")
	assert(type(area.top) == "number")
	assert(type(area.right) == "number")
	assert(type(area.bottom) == "number")
	assert(0 <= color and color < 2^16)
	local instance = {
		_area = area,
		_color = color,
	}

	return setmetatable(instance, Box)
end

function Box:bounds()
	return {self._area}
end

function Box:setArea(area)
	self._area = area
	self._stale = true
end

function Box:setColor(color)
	if color ~= self._color then
		self._color = color

		-- The current area must be repainted, but no space is uncovered.
		self._stale = true
	end
end

function Box:render(fb, rect)
	clockOpen("Box:render")
	local lowY = math.max(rect.top, self._area.top)
	local highY = math.min(rect.bottom, self._area.bottom) - 1
	local lowX = math.max(rect.left, self._area.left)
	local highX = math.min(rect.right, self._area.right) - 1
	fb:setRect(lowX, lowY, highX + 1, highY + 1, self._color)
	clockClose()
end

--------------------------------------------------------------------------------

local VisualStack = {}
VisualStack.__index = VisualStack

function VisualStack.new(elements)
	local instance = {
		_elements = elements,
	}
	return setmetatable(instance, VisualStack)
end

function VisualStack:plan()
	clockOpen("VisualStack:plan()")
	local olds = {}
	local news = {}
	for _, v in ipairs(self._elements) do
		local va, vb = v:plan()
		for i = 1, #va do
			olds[#olds + 1] = va[i]
		end
		for i = 1, #vb do
			news[#news + 1] = vb[i]
		end
	end
	clockClose()
	return olds, news
end

function VisualStack:render(fb, regions)
	for _, v in ipairs(self._elements) do
		v:render(fb, regions)
	end
end

--------------------------------------------------------------------------------

-- Window implements the same interface as FrameBuffer, but delegates to an 
-- actual FrameBuffer with an offset and clipping rectangle.
local Window = {}
Window.__index = Window

function Window.new(fb, target, origin)
	local instance = {
		_fb = fb,
		_tx = target.left,
		_ty = target.top,
		_width = target.right - target.left,
		_height = target.bottom - target.top,
		_originLeft = (origin and origin.left) or 0,
		_originTop = (origin and origin.top) or 0,
	}
	return setmetatable(instance, Window)
end

function Window:setPixel(x, y, color)
	x = x - self._originLeft
	y = y - self._originTop
	if 0 <= x and x < self._width then
		if 0 <= y and y < self._height then
			self._fb:setPixel(x + self._tx, y + self._ty, color)
		end
	end
end

function Window:setRect(left, top, right, bottom, color)
	left = left - self._originLeft
	right = right - self._originLeft
	top = top - self._originTop
	bottom = bottom - self._originTop

	left = math.max(0, left)
	top = math.max(0, top)
	right = math.min(self._width, right)
	bottom = math.min(self._height, bottom)

	self._fb:setRect(self._tx + left, self._ty + top, self._tx + right, self._ty + bottom, color)
end

function Window:flush(x1, y1, x2, y2, mode)
	x1 = x1 - self._originLeft
	x2 = x2 - self._originLeft
	y1 = y1 - self._originTop
	y2 = y2 - self._originTop

	self._fb:flush(self._tx + x1, self._ty + y1, self._tx + x2, self._ty + y2, mode)
end

function Window:size()
	return self._width, self._height
end

function Window:containsOnTarget(x, y)
	local dx = x - self._tx
	local dy = y - self._ty
	if 0 <= dx and dx < self._width and 0 <= dy and dy < self._height then
		return dx, dy
	else
		return false
	end
end

--------------------------------------------------------------------------------

local TextBox = {}
TextBox.__index = TextBox

function TextBox.new(font, rect, text, baseline)
	local instance = {
		_font = font,
		_rect = rect,
		_text = text,
		_baseline = baseline,

		_lastPlan = {},
		_stale = true,
	}

	return setmetatable(instance, TextBox)
end

function TextBox:plan()
	if not self._stale then
		return {}, {}
	end

	local old = self._lastPlan
	local new = {self._rect}

	self._lastPlan = new
	self._stale = false
	return old, new
end

function TextBox:render(fb, regions)
	local left = math.max(region.left, self._rect.left)
	local top = math.max(region.top, self._rect.top)
	local right = math.min(region.right, self._rect.right)
	local bottom = math.min(region.bottom, self._rect.bottom)
	local filter = {left = left, top = top, right = right, bottom = bottom}
	local window = Window.new(fb, filter)
	local bx = self._rect.left
	local by = self._baseline
	font.renderString(window, self._font, bx - filter.left, by - filter.top, self._text)
end

--------------------------------------------------------------------------------

local Line = {}
Line.__index = Line

function Line.new(x1, y1, x2, y2)
	local instance = {
		_x1 = x1,
		_y1 = y1,
		_x2 = x2,
		_y2 = y2,

		_stale = true,
		_lastPlan = {},
	}
	return setmetatable(instance, Line)
end

function Line:plan()
	if not self._stale then
		return {}, {}
	end

	local old = self._lastPlan
	local new = {
		{
			left = math.min(self._x1, self._x2) - 1,
			top = math.min(self._y1, self._y2) - 1,
			right = math.max(self._x1, self._x2) + 1,
			bottom = math.max(self._y1, self._y2) + 1,
		},
	}
	self._lastPlan = new
	self._stale = false
	return old, new
end

function Line:set(x1, y1, x2, y2)
	self._x1 = x1
	self._y1 = y1
	self._x2 = x2
	self._y2 = y2
	self._stale = true
end

local function renderLine(fb, x1, y1, x2, y2, color)
	if x1 == x2 and y1 == y2 then
		fb:setPixel(x1, y1)
		return
	end
	
	if math.abs(y1 - y2) >= math.abs(x1 - x2) then
		for y = math.min(y1, y2), math.max(y1, y2) do
			local p = (y - y1) / (y2 - y1)
			local tx = p * x2 + (1 - p) * x1
			local x = math.floor(tx + 0.5)
			fb:setPixel(x, y, 0)
		end
	else
		for x = math.min(x1, x2), math.max(x1, x2) do
			local p = (x - x1) / (x2 - x1)
			local ty = p * y2 + (1 - p) * y1
			local y = math.floor(ty + 0.5)
			fb:setPixel(x, y, 0)
		end
	end
end

function Line:render(fb, regions)
	clockOpen("Line:render()")
	renderLine(fb, self._x1, self._y1, self._x2, self._y2, 0)
	clockClose("Line:render()")
end

--------------------------------------------------------------------------------

local function renderFrame(fb, element)
	clockOpen("renderFrame")

	local olds, news = element:plan()

	if #olds == 0 and #news == 0 then
		clockClose()
		return
	end
	local begin = os.clock()

	local width, height = fb:size()
	local regions = {left = width, right = 0, top = height, bottom = 0}
	for _, r in ipairs(olds) do
		regions.left = math.min(regions.left, r.left)
		regions.top = math.min(regions.top, r.top)
		regions.right = math.max(regions.right, r.right)
		regions.bottom = math.max(regions.bottom, r.bottom)
		table.insert(regions, r)
	end
	for _, r in ipairs(news) do
		regions.left = math.min(regions.left, r.left)
		regions.top = math.min(regions.top, r.top)
		regions.right = math.max(regions.right, r.right)
		regions.bottom = math.max(regions.bottom, r.bottom)
		table.insert(regions, r)
	end

	element:render(fb, regions)

	for _, region in ipairs(regions) do
		local left = math.max(0, region.left)
		local right = math.min(width, region.right)
		local top = math.max(0, region.top)
		local bottom = math.min(height, region.bottom)
		fb:flush(left, top, right, bottom, 1)
	end

	clockClose()
end

return {
	VisualStack = VisualStack,
	Box = Box,
	TextBox = TextBox,
	Window = Window,
	Line = Line,
	renderFrame = renderFrame,
	renderLine = renderLine,
}
