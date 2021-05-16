local SplitWidget = {}
SplitWidget.__index = SplitWidget

function SplitWidget.new(placement, widgets)
	assert(type(placement.left) == "number", "placement.left: number")
	assert(type(placement.top) == "number", "placement.top: number")
	assert(type(placement.width) == "number", "placement.width: number")
	assert(type(placement.height) == "number", "placement.height: number")

	for k in pairs(widgets) do
		assert(type(k) == "table")
		assert(type(k.contains) == "function")
		assert(type(k.relative) == "function")
	end

	local instance = {
		placement = placement,
		widgets = widgets,
		focus = false,
	}
	return setmetatable(instance, SplitWidget)
end

function SplitWidget:contains(x, y)
	local dx, dy = self:relative(x, y)
	local ix = 0 <= dx and dx < self.placement.width
	local iy = 0 <= dy and dy < self.placement.height
	return ix and iy
end

function SplitWidget:relative(x, y)
	return x - self.placement.left, y - self.placement.top
end

-- touchStart: A touch is starting within this widget.
-- The tool may either be "eraser" or "pen".
function SplitWidget:touchStart(app, x, y, tool)
	assert(self.focus == false, "touchStart called when focused")
	for widget in pairs(self.widgets) do
		if widget:contains(x, y) then
			local dx, dy = widget:relative(x, y)
			self.focus = widget
			return widget:touchStart(app, dx, dy, tool)
		end
	end
	self.focus = true
end

-- touchDrag: A touch that STARTED within this widget is continuing and has
-- moved.
-- tool: "pen" | "eraser"
function SplitWidget:touchDrag(app, x, y, tool)
	assert(self.focus)
	if self.focus ~= true then
		local dx, dy = self.focus:relative(x, y)
		self.focus:touchDrag(app, dx, dy, tool)
	end
end

-- touchEnd: A touch that STARTED within this widget is has ended.
-- The tool may either be "eraser" or "pen".
-- NOTE: This is fired for the widget that `touchStart` was fired in, leaving
-- `(x, y)` out-of-bounds.
function SplitWidget:touchEnd(app, x, y, tool)
	assert(self.focus)
	if self.focus ~= true then
		local dx, dy = self.focus:relative(x, y)
		self.focus:touchEnd(app, dx, dy, tool)
	end
	self.focus = false
end

-- hover: The is hovering near the screen over this widget.
-- tool: "pen" | "eraser"
function SplitWidget:hover(app, x, y, tool)
	local newFocus = true
	for widget in pairs(self.widgets) do
		if widget:contains(x, y) then
			newFocus = widget
			break
		end
	end

	if self.focus and self.focus ~= true and self.focus ~= newFocus then
		local dx, dy = self.widgets[self.focus]:relative(x, y)
		self.focus:hoverEnd(app, dx, dy, tool, "out")
	end
	self.focus = newFocus
	if newFocus ~= true then
		local dx, dy = newFocus:relative(x, y)
		newFocus:hover(app, dx, dy, tool)
	end
end

-- hoverEnd: The pen was hovering, and either
-- * started contacting
-- * was lifted away from the screen
-- while over this widget
-- tool: "pen" | "eraser"
-- out: "pen" | "eraser" | "out" | "away"
function SplitWidget:hoverEnd(app, x, y, tool, out)
	assert(self.focus)
	if self.focus ~= true then
		local dx, dy = self.focus:relative(x, y)
		self.focus:hoverEnd(app, x, y, tool, out)
	end
	self.focus = false
end

function SplitWidget:window(fb)
	return ui.Window.new(fb, {
		left = self.placement.left,
		top = self.placement.top,
		right = self.placement.left + self.placement.width,
		bottom = self.placement.top + self.placement.height,
	})
end

function SplitWidget:render(fb)
	for widget in pairs(self.widgets) do
		local window = widget:window(fb)
		widget:render(window)
	end
end

return {
	SplitWidget = SplitWidget,
}
