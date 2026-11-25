-- FlyCrash: машины на дорогах. Ездят туда-обратно по правой полосе.
-- Самолёт может в них врезаться (и они — повод не садиться на дорогу).

local RunService = game:GetService("RunService")

local CFG = { CARS_PER_ROAD = 3, SPEED_MIN = 28, SPEED_MAX = 45 }
local ROADS = "__ROADS__"

local folder = Instance.new("Folder")
folder.Name = "Traffic"
folder.Parent = workspace

local COLORS = {
	Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 30, 35),
	Color3.fromRGB(40, 90, 180), Color3.fromRGB(235, 190, 40), Color3.fromRGB(60, 140, 80),
}

local function p(parent, size, cf, color, shape, mat)
	local x = Instance.new("Part")
	x.Anchored = true
	x.CanCollide = true
	x.Size = size
	x.CFrame = cf
	x.Color = color
	x.Material = mat or Enum.Material.SmoothPlastic
	x.TopSurface = Enum.SurfaceType.Smooth
	x.BottomSurface = Enum.SurfaceType.Smooth
	if shape then x.Shape = shape end
	x.Parent = parent
	return x
end

local function makeCar()
	local m = Instance.new("Model")
	m.Name = "Car"
	local van = math.random() < 0.3
	local color = COLORS[math.random(#COLORS)]
	local body = p(m, Vector3.new(5, van and 4 or 2.4, van and 11 or 10), CFrame.new(0, van and 3 or 2, 0), color)
	m.PrimaryPart = body
	if not van then
		p(m, Vector3.new(4.6, 1.8, 5), CFrame.new(0, 4, 0.6), color)
	end
	p(m, Vector3.new(4.4, van and 1.6 or 1.4, 0.2), CFrame.new(0, van and 4.2 or 4, van and -5.5 or -1.95), Color3.fromRGB(60, 90, 120), nil, Enum.Material.Glass)
	for _, o in ipairs({ { 2.4, -3.2 }, { -2.4, -3.2 }, { 2.4, 3.2 }, { -2.4, 3.2 } }) do
		p(m, Vector3.new(0.8, 1.9, 1.9), CFrame.new(o[1], 0.95, o[2]), Color3.fromRGB(25, 25, 28), Enum.PartType.Cylinder)
	end
	return m, body.Position.Y
end

local cars = {}
for entry in string.gmatch(ROADS, "[^;]+") do
	local sx, sz, ex, ez = string.match(entry, "(-?%d+),(-?%d+),(-?%d+),(-?%d+)")
	if sx then
		local a = Vector3.new(tonumber(sx), 0.35, tonumber(sz))
		local b = Vector3.new(tonumber(ex), 0.35, tonumber(ez))
		local len = (b - a).Magnitude
		if len > 100 then
			for _ = 1, CFG.CARS_PER_ROAD do
				local car, h = makeCar()
				car.Parent = folder
				table.insert(cars, {
					m = car, h = h, a = a, b = b, len = len, t = math.random() * len,
					dir = math.random() < 0.5 and 1 or -1,
					speed = math.random(CFG.SPEED_MIN, CFG.SPEED_MAX),
				})
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	for _, c in ipairs(cars) do
		if c.m.Parent then
			c.t += c.speed * dt * c.dir
			if c.t > c.len then c.t = c.len c.dir = -1 end
			if c.t < 0 then c.t = 0 c.dir = 1 end
			local fwd = (c.b - c.a).Unit * c.dir
			local right = fwd:Cross(Vector3.yAxis)
			local pos = c.a + (c.b - c.a).Unit * c.t + right * 4.2 + Vector3.new(0, c.h, 0)
			c.m:PivotTo(CFrame.lookAt(pos, pos + fwd))
		end
	end
end)
