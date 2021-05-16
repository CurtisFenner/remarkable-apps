local ui = require "library/ui"

local OBJ_SELECTION_PX = 20

local SketchWidget = {}
SketchWidget.__index = SketchWidget

function SketchWidget.new(placement)
	assert(type(placement.left) == "number", "placement.left: number")
	assert(type(placement.top) == "number", "placement.top: number")
	assert(type(placement.width) == "number", "placement.width: number")
	assert(type(placement.height) == "number", "placement.height: number")

	local instance = {
		placement = placement,
		rendered = {
			frame = false,
			objects = {
			},
		},

		-- An object ID, when the cursor is hovering (but not touching)
		-- an object.
		hoveringOver = false,

		-- An object ID, when the cursor is dragging an object.
		dragging = false,

		objects = {
			a = {
				tag = "point",
				x = 50,
				y = 50,
			};
			b = {
				tag = "point",
				x = 500,
				y = 50,
			};
			c = {
				tag = "point",
				x = 50,
				y = 500,
			};
		},
	}
	return setmetatable(instance, SketchWidget)
end

function SketchWidget:contains(x, y)
	local dx, dy = self:relative(x, y)
	local ix = 0 <= dx and dx < self.placement.width
	local iy = 0 <= dy and dy < self.placement.height
	return ix and iy
end

function SketchWidget:relative(x, y)
	return x - self.placement.left, y - self.placement.top
end

-- RETURNS the object ID at the given (relative) screen position, or `false` if
-- none.
function SketchWidget:highlight(x, y)
	local bestID = nil
	local bestDistance = 0

	for id, object in pairs(self.objects) do
		if object.tag == "point" then
			local sx, sy = self:toScreen(object.x, object.y)
			local dx = x - sx
			local dy = y - sy
			local dm = math.sqrt(dx * dx + dy * dy)
			if not bestID or bestDistance > dm then
				bestID = id
				bestDistance = dm
			end
		end
	end

	if bestID and bestDistance < OBJ_SELECTION_PX then
		return bestID, bestDistance
	end
	return false
end

function SketchWidget:touchStart(app, x, y, tool)
	if tool == "pen" then
		self.dragging = self:highlight(x, y)
	end
end

function SketchWidget:touchDrag(app, x, y, tool)
	if self.dragging then
		local dragged = self.objects[self.dragging]
		dragged.x = x
		dragged.y = y
	end
end

function SketchWidget:touchEnd(app, x, y, tool)
	self.dragging = false
end

function SketchWidget:hover(app, x, y, tool)
	if tool == "pen" then
		local over = self:highlight(x, y)
		self.hoveringOver = over
	end
end

function SketchWidget:hoverEnd(app, x, y, tool)
	self.hoveringOver = false
end

function SketchWidget:window(fb)
	return ui.Window.new(fb, {
		left = self.placement.left,
		top = self.placement.top,
		right = self.placement.left + self.placement.width,
		bottom = self.placement.top + self.placement.height,
	})
end

local POINT_RADIUS_PX = 4
local POINT_HIGHLIGHT_RADIUS_PX = 8

function SketchWidget:pointRepaintRectangles(id, old, new)
	if old and new then
		local newHighlighted = self.hoveringOver == id
		local newX, newY = self:toScreen(new.x, new.y)
		if old.sx ~= newX or old.sy ~= newY or old.highlighted ~= newHighlighted then
			local newX, newY = self:toScreen(new.x, new.y)
			return {
				{
					left = math.floor(old.sx - POINT_HIGHLIGHT_RADIUS_PX),
					right = math.ceil(old.sx + POINT_HIGHLIGHT_RADIUS_PX),
					top = math.floor(old.sy - POINT_HIGHLIGHT_RADIUS_PX),
					bottom = math.ceil(old.sy + POINT_HIGHLIGHT_RADIUS_PX),
				},
				{
					left = math.floor(newX - POINT_HIGHLIGHT_RADIUS_PX),
					right = math.ceil(newX + POINT_HIGHLIGHT_RADIUS_PX),
					top = math.floor(newY - POINT_HIGHLIGHT_RADIUS_PX),
					bottom = math.ceil(newY + POINT_HIGHLIGHT_RADIUS_PX),
				},
			}
		else
			return {}
		end
	else
		assert(old or new)
		local onlyX, onlyY
		if new then
			onlyX, onlyY = self:toScreen(new.x, new.y)
		else
			onlyX, onlyY = old.sx, old.sy
		end
		return {
			{
				left = math.floor(onlyX - POINT_HIGHLIGHT_RADIUS_PX),
				right = math.ceil(onlyX + POINT_HIGHLIGHT_RADIUS_PX),
				top = math.floor(onlyY - POINT_HIGHLIGHT_RADIUS_PX),
				bottom = math.ceil(onlyY + POINT_HIGHLIGHT_RADIUS_PX),
			},
		}
	end
end

local function oldNewPairs(olds, news)
	local list = {}
	for k, old in pairs(olds) do
		assert(old.tag ~= nil)
		local new = news[k]
		if new == nil then
			table.insert(list, {
				tag = old.tag,
				k = k,
				old = old,
				new = false,
			})
		end
	end
	for k, new in pairs(news) do
		assert(new.tag ~= nil)
		local old = olds[k]
		if old and old.tag ~= new.tag then
			table.insert(list, {
				tag = old.tag,
				k = k,
				old = old,
				new = false,
			})
			table.insert(list, {
				tag = new.tag,
				k = k,
				old = false,
				new = new,
			})
		else
			table.insert(list, {
				tag = new.tag,
				k = k,
				old = old or false,
				new = new,
			})
		end
	end
	return list
end

function SketchWidget:repaintRectangles()
	local rectangles = {}
	if not self.rendered.frame then
		table.insert(rectangles, {
			left = 0,
			top = 0,
			right = self.placement.width,
			bottom = self.placement.height,
		})
	end

	local tuples = oldNewPairs(self.rendered.objects, self.objects)
	assert(type(tuples) == "table")

	for _, tuple in ipairs(tuples) do
		if tuple.tag == "point" then
			local pointRectangles = self:pointRepaintRectangles(tuple.k, tuple.old, tuple.new)
			for _, r in ipairs(pointRectangles) do
				table.insert(rectangles, r)
			end
		else
			error("unknown tag `" .. tuple.tag .. "`")
		end
	end
	return rectangles
end

function SketchWidget:toScreen(wx, wy)
	-- TODO:
	return math.floor(wx), math.floor(wy)
end

function SketchWidget:repaintObject(fb, rectangle, k, object)
	if object.tag == "point" then
		local radius = POINT_RADIUS_PX
		if k == self.hoveringOver then
			radius = POINT_HIGHLIGHT_RADIUS_PX
		end
		local sx, sy = self:toScreen(object.x, object.y)
		fb:setRect(sx - radius, sy - radius, sx + radius, sy + radius, 0)
		print("painting point", k, "at", sx, sy, "radius", radius)
	end
end

function SketchWidget:repaint(fb, rectangle)
	fb:setRect(rectangle.left, rectangle.top, rectangle.right, rectangle.bottom, 31)

	-- Draw the frame.
	-- fb:setRect(self.placement.left, self.placement.top, 1, self.placement.height, 0)
	-- fb:setRect(self.placement.left + self.placement.width - 1, self.placement.top, 1, self.placement.height, 0)
	-- fb:setRect(self.placement.left, self.placement.top, self.placement.width, 1, 0)
	-- fb:setRect(self.placement.left, self.placement.top + self.placement.height - 1, self.placement.width, 1, 0)

	for k, object in pairs(self.objects) do
		self:repaintObject(fb, rectangle, k, object)
	end
end

function SketchWidget:render(fb)
	-- Look at diff between current state and rendered.
	-- Generate new rendered state.
	-- Generate a set of rectangles that need to be rerendered
	-- (around old points, and around new points, wherever they moved)
	-- Repaint those rectangles.
	-- Flush those rectangles.
	-- Update rendered state.
	local rectangles = self:repaintRectangles()
	for _, rectangle in ipairs(rectangles) do
		local window = ui.Window.new(fb, rectangle, rectangle)
		window = fb
		self:repaint(window, rectangle)
	end

	if #rectangles ~= 0 then
		-- print("Repaint:")
	end

	for _, rectangle in ipairs(rectangles) do
		fb:flush(rectangle.left, rectangle.top, rectangle.right, rectangle.bottom, 1)

		-- print("", rectangle.left .. " to " .. rectangle.right, "x", rectangle.top .. " to " .. rectangle.bottom)
	end

	if #rectangles ~= 0 then
		-- print("")
	end

	self.rendered.objects = {}
	for k, object in pairs(self.objects) do
		if object.tag == "point" then
			local sx, sy = self:toScreen(object.x, object.y)
			self.rendered.objects[k] = {
				tag = "point",
				highlighted = k == self.hoveringOver,
				sx = sx,
				sy = sy,
			}
		end
	end
	self.rendered.frame = true
end

return {
	SketchWidget = SketchWidget,
}
