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

-- :render(fb, rect)
-- Renders to the framebuffer ONLY within the given rectangle.
-- This should NOT modify the state of the underlying VisualElement.

--------------------------------------------------------------------------------

local ZERO_RECT = {type = "rect", left = 0, right = 0, top = 0, bottom = 0}

-- Implements VisualElement protocol.
local Box = {}
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

		_lastArea = {},
		_stale = true,
	}

	return setmetatable(instance, Box)
end

function Box:plan()
	if not self._stale then
		return {}, {}
	end

	local old = self._lastArea
	local new = {self._area}
	self._lastArea = new
	self._stale = false
	return old, new
end

function Box:bound()
	return self._area
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
	local lowY = math.max(rect.top, self._area.top)
	local highY = math.min(rect.bottom, self._area.bottom) - 1
	local lowX = math.max(rect.left, self._area.left)
	local highX = math.min(rect.right, self._area.right) - 1
	for y = lowY, highY do
		for x = lowX, highX do
			fb:setPixel(x, y, self._color)
		end
	end
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
	return olds, news
end

function VisualStack:render(fb, area)
	for _, v in ipairs(self._elements) do
		v:render(fb, area)
	end
end

--------------------------------------------------------------------------------

-- Window implements the same interface as FrameBuffer, but delegates to an 
-- actual FrameBuffer with an offset and clipping rectangle.
local Window = {}
Window.__index = Window

function Window.new(fb, target)
	local instance = {
		_fb = fb,
		_tx = target.left,
		_ty = target.top,
		_width = target.right - target.left,
		_height = target.bottom - target.top,
	}
	return setmetatable(instance, Window)
end

function Window:setPixel(x, y, color)
	if 0 <= x and x < self._width then
		if 0 <= y and y <= self._height then
			self._fb:setPixel(x + self._tx, y + self._ty, color)
		end
	end
end

function Window:size()
	return self._width, self._height
end

--------------------------------------------------------------------------------

local TextBox = {}
TextBox.__index = TextBox

function TextBox.new(font, rect, text)
	local instance = {
		_font = font,
		_rect = rect,
		_text = text,

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

function TextBox:render(fb, region)
	local left = math.max(region.left, self._rect.left)
	local top = math.max(region.top, self._rect.top)
	local right = math.min(region.right, self._rect.right)
	local bottom = math.min(region.bottom, self._rect.bottom)
	local filter = {left = left, top = top, right = right, bottom = bottom}
	local window = Window.new(fb, filter)
	local bx = self._rect.left
	local by = (self._rect.top + self._rect.bottom) // 2
	font.renderString(window, self._font, bx - filter.left, by - filter.top, self._text)
end

--------------------------------------------------------------------------------

local function showRectangle(r)
	return string.format("{left = %d, right = %d; top = %d, bottom = %d}",
		r.left, r.right, r.top, r.bottom)
end

local function renderFrame(fb, element)
	local olds, news = element:plan()

	if #olds == 0 and #news == 0 then
		return
	end
	local begin = os.clock()

	for _, old in ipairs(olds) do
		element:render(fb, old)
	end
	for _, new in ipairs(news) do
		element:render(fb, new)
	end

	local width, height = fb:size()
	for _, old in ipairs(olds) do
		local left = math.max(0, old.left)
		local right = math.min(width, old.right)
		local top = math.max(0, old.top)
		local bottom = math.min(height, old.bottom)
		fb:flush(left, top, right, bottom, 1)
	end
	
	for _, new in ipairs(news) do
		local left = math.max(0, new.left)
		local right = math.min(width, new.right)
		local top = math.max(0, new.top)
		local bottom = math.min(height, new.bottom)
		fb:flush(left, top, right, bottom, 1)
	end

	print(os.clock() - begin, "time spent rerendering")
end

return {
	VisualStack = VisualStack,
	Box = Box,
	TextBox = TextBox,
	Window = Window,
	renderFrame = renderFrame,
}
