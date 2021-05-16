
local V2 = {}

function V2.new(x, y)
	assert(type(x) == "number", "x must be a number")
	assert(type(y) == "number", "y must be a number")
	return setmetatable({x = x, y = y}, {__index = V2})
end

function V2:polar(r, t)
	assert(type(r) == "number", "r must be a number")
	assert(type(t) == "number", "t must be a number")
	return self:add(V2.new(r * math.cos(t), r * math.sin(t)))
end

function V2:add(other)
	return V2.new(self.x + other.x, self.y + other.y)
end

function V2:sub(other)
	return V2.new(self.x - other.x, self.y - other.y)
end

function V2:scale(scale)
	assert(type(scale) == "number", "scale must be a number")
	return V2.new(scale * self.x, scale * self.y)
end

function V2:dot(other)
	return self.x * other.x + self.y * other.y
end

function V2:unit()
	return self:scale(1 / self:mag())
end

function V2:mag()
	return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

function V2:distance(other)
	return self:sub(other):mag()
end

function V2:mid(other)
	return self:add(other):scale(1/ 2)
end

function V2:lerp(b, t)
	return self:add(b:sub(self):scale(t))
end

-- RETURNS the projection of Z onto line AB, and its signed distance from a in
-- terms of lengths of AB.
function lineProject(a, b, z)
	local z = z:sub(a)
	local ba = b:sub(a)
	local mba = ba:mag()
	local uba = ba:scale(1 / mba)
	local d = z:dot(uba)

	return a:add(uba:scale(d)), d / mba
end

return {
	V2 = V2,
	lineProject = lineProject,
}
