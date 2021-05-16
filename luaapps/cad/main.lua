setmetatable(_G, {
	__index = function(_, key)
		error("reading undefined global `" .. tostring(key) .. "`", 2)
	end,
	__newindex = function(_, key)
		error("writing global `" .. tostring(key) .. "`", 2)
	end,
})

--------------------------------------------------------------------------------

package.path = "/home/root/luaapps/?.lua"

local function main()
	local ui = require "library/ui"
	local SketchWidget = (require "cad/sketchwidget").SketchWidget
	local SplitWidget = (require "cad/splitwidget").SplitWidget

	----------------------------------------------------------------------------

	local SCREEN_WIDTH, SCREEN_HEIGHT = rm_fb:size()

	local SKETCH_HEIGHT = math.floor(0.75 * SCREEN_HEIGHT)
	local SKETCH_WIDTH = math.floor(0.75 * SCREEN_WIDTH)
	local TOOLBAR_HEIGHT = 75
	print("Screen size:", SCREEN_WIDTH, "x", SCREEN_HEIGHT)
	print("Sketch size:", SKETCH_WIDTH, "x", SKETCH_HEIGHT)

	local sketchPlacement = {
		left = 0,
		top = 0,
		width = SKETCH_WIDTH,
		height = SKETCH_HEIGHT,
	}
	local sketchWidget = SketchWidget.new(sketchPlacement)

	local toolbarPlacement = {
		left = 0,
		top = SKETCH_HEIGHT,
		width = SKETCH_WIDTH,
		height = TOOLBAR_HEIGHT,
	}
	local toolbarWidget = SplitWidget.new(toolbarPlacement, {
		-- TODO
	})

	local screenPlacement = {
		left = 0,
		top = 0,
		width = SCREEN_WIDTH,
		height = SCREEN_HEIGHT,
	}

	-- local appWidget = SplitWidget.new(screenPlacement, {
	-- 	[sketchWidget] = true,
	-- 	[toolbarWidget] = true,
	-- })
	local appWidget = sketchWidget

	local app = {
		TODO = "TODO",
	}

	-- pen.contacting: boolean
	-- pen.hoverDraw: boolean
	-- pen.hoverErase: boolean
	-- RETURNS: "away" | "hover-pen" | "hover-eraser" | "pen" | "eraser"
	local function rmpenState(pen)
		if pen.contacting then
			if pen.hoverDraw then
				return "pen"
			else
				return "eraser"
			end
		elseif pen.hoverDraw then
			return "hover-pen"
		elseif pen.hoverErase then
			return "hover-eraser"
		else
			return "away"
		end
	end

	-- penState: "away" | "hover-pen" | "hover-eraser" | "pen" | "eraser"
	local penState = "away"
	local function handlePen(pen)
		local newState = rmpenState(pen)

		-- Synthetically slow odd transitions.
		if penState == "pen" and newState == "eraser" then
			newState = "hover-eraser"
		elseif penState == "eraser" and newState == "pen" then
			newState = "hover-pen"
		elseif penState == "hover-pen" and newState == "hover-eraser" then
			newState = "away"
		elseif penState == "hover-eraser" and newState == "hover-pen" then
			newState = "away"
		end

		if newState == "away" then
			if penState == "away" then
				-- Nothing
			elseif penState == "hover-pen" or penState == "hover-eraser" then
				local hoverTool = penState == "hover-pen" and "pen" or "eraser"
				appWidget:hoverEnd(app, pen.xPos, pen.yPos, hoverTool, "away")
			elseif penState == "pen" or penState == "eraser" then
				appWidget:touchEnd(app, pen.xPos, pen.yPos, newState)
			else
				error("unknown penState `" .. tostring(penState) .. "`")
			end
		elseif newState == "hover-pen" or newState == "hover-eraser" then
			if penState == "eraser" or penState == "eraser" then
				appWidget:touchEnd(app, pen.xPos, pen.yPos, penState)
			end
			local tool = newState == "hover-pen" and "pen" or "eraser"
			appWidget:hover(app, pen.xPos, pen.yPos, tool)
		elseif newState == "pen" or newState == "eraser" then
			if penState == "hover-pen" or penState == "hover-eraser" then
				local hoverTool = penState == "hover-pen" and "pen" or "eraser"
				appWidget:hoverEnd(app, pen.xPos, pen.yPos, hoverTool, newState)
			end
			if penState == "pen" or penState == "eraser" then
				assert(penState == newState)
				appWidget:touchDrag(app, pen.xPos, pen.yPos, newState)
			else
				appWidget:touchStart(app, pen.xPos, pen.yPos, newState)
			end
		else
			error("unknown newState `" .. tostring(newState) .. "`")
		end

		penState = newState
	end

	while true do
		rm_pen:poll(handlePen)
		appWidget:render(rm_fb)
	end
end

xpcall(main, function(e)
	print(debug.traceback(e))
	return e
end)
