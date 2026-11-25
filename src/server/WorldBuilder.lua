-- FlyCrash: живой мир — ландшафт с травой, лоскутные поля, горы, море, облака, атмосфера.
-- Строится при запуске (пока игроки в ангаре). Поля генерирует файл места, данные ниже.

local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

---------------------------------------------------------------- СВЕТ И НЕБО
Lighting.ClockTime = 14.2
Lighting.Brightness = 2.6
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
Lighting.Ambient = Color3.fromRGB(70, 70, 80)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true

local function ensure(class, parent, props)
	local o = parent:FindFirstChildOfClass(class)
	if not o then
		o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = parent
	end
	return o
end
ensure("Atmosphere", Lighting, {
	Density = 0.28, Offset = 0.15, Color = Color3.fromRGB(199, 214, 230),
	Decay = Color3.fromRGB(120, 150, 180), Glare = 0.3, Haze = 1.2,
})
ensure("ColorCorrectionEffect", Lighting, { Saturation = 0.15, Contrast = 0.06, Brightness = 0.02 })
ensure("SunRaysEffect", Lighting, { Intensity = 0.06, Spread = 0.6 })
ensure("BloomEffect", Lighting, { Intensity = 0.35, Size = 24, Threshold = 1.7 })
ensure("Clouds", Terrain, { Cover = 0.55, Density = 0.6, Color = Color3.new(1, 1, 1) })

---------------------------------------------------------------- ЦВЕТА МАТЕРИАЛОВ (поля)
pcall(function() Terrain.Decoration = true end) -- колышущаяся трава
Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 158, 66))
Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(78, 128, 52))
Terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(226, 202, 58))  -- рапс
Terrain:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(212, 186, 120)) -- пшеница
Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(128, 94, 62))      -- пашня
Terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(100, 76, 52))
Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(226, 210, 160))
Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 126, 122))
Terrain.WaterColor = Color3.fromRGB(30, 95, 130)
Terrain.WaterTransparency = 0.6
Terrain.WaterWaveSize = 0.15
Terrain.WaterWaveSpeed = 8
Terrain.WaterReflectance = 0.6

---------------------------------------------------------------- ЗЕМЛЯ: трава до берега (верх = 0)
for x = -6144, 2048, 2048 do
	for z = -6144, 4096, 2048 do
		local w = (x == 2048) and 760 or 2048
		Terrain:FillBlock(CFrame.new(x + w / 2, -4, z + 1024), Vector3.new(w, 8, 2048), Enum.Material.Grass)
	end
	task.wait()
end

---------------------------------------------------------------- ПОЛЯ
local FIELDS = "__FIELDS__"
local n = 0
for entry in string.gmatch(FIELDS, "[^;]+") do
	local x, z, w, d, mat = string.match(entry, "(-?%d+),(-?%d+),(%d+),(%d+),(%a+)")
	if x then
		local m = Enum.Material[mat]
		Terrain:FillBlock(CFrame.new(tonumber(x), -1, tonumber(z)), Vector3.new(tonumber(w), 2.2, tonumber(d)), m)
		n += 1
		if n % 60 == 0 then task.wait() end
	end
end

---------------------------------------------------------------- ПЛЯЖ И МОРЕ (восток)
Terrain:FillBlock(CFrame.new(2960, -4, 0), Vector3.new(320, 8, 12288), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(3260, -10, 0), Vector3.new(400, 4, 12288), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(4200, -5, 0), Vector3.new(2400, 14, 12288), Enum.Material.Water)
-- остров-убежище с аэродромом (верх ≈ y 3)
-- верх острова ровно на y = 4 (сетка ландшафта — 4 studs), полоса лежит поверх
Terrain:FillBlock(CFrame.new(4900, -4, 0), Vector3.new(760, 16, 1900), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(4900, -2, 0), Vector3.new(680, 12, 1800), Enum.Material.Grass)
Terrain:FillBall(Vector3.new(4900, -40, 950), 120, Enum.Material.Sand)
Terrain:FillBall(Vector3.new(4900, -40, -950), 120, Enum.Material.Sand)

---------------------------------------------------------------- ГОРЫ (разные!)
-- Типы: острый пик, хребет из нескольких вершин, столовая гора, вулкан, холмы.
local rng = Random.new(1978)
Terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(105, 110, 118))
Terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(70, 66, 64))
Terrain:SetMaterialColor(Enum.Material.Granite, Color3.fromRGB(150, 135, 125))
Terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(226, 202, 58)) -- (рапс; для гор не используем)
local ROCKS = { Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Granite, Enum.Material.Basalt }
local SNOW_LINE = 330

-- острый пик: стопка шаров, сужающихся кверху, со случайным смещением — получается неровная вершина
local function peak(x, z, r, h, rock)
	rock = rock or ROCKS[rng:NextInteger(1, #ROCKS)]
	Terrain:FillBall(Vector3.new(x, -r * 0.55, z), r * 1.05, Enum.Material.Grass)
	local steps = rng:NextInteger(4, 6)
	local ox, oz = 0, 0
	for i = 1, steps do
		local t = i / steps
		local rr = r * (1 - t * rng:NextNumber(0.7, 0.88))
		ox += rng:NextNumber(-1, 1) * r * 0.12
		oz += rng:NextNumber(-1, 1) * r * 0.12
		local cy = -r * 0.55 + h * t
		local mat = (cy + rr * 0.6 > SNOW_LINE) and Enum.Material.Snow or rock
		Terrain:FillBall(Vector3.new(x + ox, cy, z + oz), rr, mat)
	end
	task.wait()
end

-- хребет: цепочка пиков разной высоты вдоль случайного направления
local function ridge(x, z, n, r, hMin, hMax)
	local ang = rng:NextNumber(0, math.pi)
	local dx, dz = math.cos(ang), math.sin(ang)
	local rock = ROCKS[rng:NextInteger(1, #ROCKS)]
	for i = 0, n - 1 do
		local s = (i - (n - 1) / 2) * r * rng:NextNumber(0.9, 1.3)
		local rr = r * rng:NextNumber(0.7, 1.15)
		peak(x + dx * s + rng:NextNumber(-60, 60), z + dz * s + rng:NextNumber(-60, 60), rr, rng:NextNumber(hMin, hMax), rock)
	end
end

-- столовая гора: плоская вершина и крутые красноватые склоны
local function mesa(x, z, r, h)
	Terrain:FillCylinder(CFrame.new(x, h / 2 - 20, z), h + 40, r, Enum.Material.Granite)
	Terrain:FillCylinder(CFrame.new(x + rng:NextNumber(-30, 30), h * 0.25, z + rng:NextNumber(-30, 30)), h * 0.5, r * 1.25, Enum.Material.Granite)
	Terrain:FillCylinder(CFrame.new(x, h + 1, z), 6, r * 0.97, Enum.Material.Grass)
	Terrain:FillBall(Vector3.new(x, -r * 0.8, z), r * 1.6, Enum.Material.Grass)
	task.wait()
end

-- вулкан: тёмный конус, кратер с лавой
local function volcano(x, z, r, h)
	for i = 0, 6 do
		local t = i / 6
		Terrain:FillBall(Vector3.new(x, -r * 0.5 + h * t * 0.95, z), r * (1 - t * 0.8), i < 1 and Enum.Material.Grass or Enum.Material.Basalt)
	end
	local top = -r * 0.5 + h * 0.95 + r * 0.2
	Terrain:FillBall(Vector3.new(x, top + r * 0.12, z), r * 0.22, Enum.Material.Air)
	Terrain:FillBall(Vector3.new(x, top - r * 0.12, z), r * 0.12, Enum.Material.CrackedLava)
	task.wait()
end

-- холмы: пологие и зелёные
local function hills(x, z, n)
	for _ = 1, n do
		local r = rng:NextNumber(90, 200)
		local m = rng:NextNumber() < 0.5 and Enum.Material.Grass or Enum.Material.LeafyGrass
		Terrain:FillBall(Vector3.new(x + rng:NextNumber(-300, 300), -r * rng:NextNumber(0.55, 0.75), z + rng:NextNumber(-300, 300)), r, m)
	end
	task.wait()
end

-- запад: большой альпийский хребет + отдельные пики
for i = 0, 4 do
	ridge(-5300 + rng:NextNumber(-300, 200), -4400 + i * 2200, rng:NextInteger(3, 5), rng:NextNumber(260, 360), 380, 700)
end
for _ = 1, 4 do
	peak(rng:NextNumber(-4700, -4200), rng:NextNumber(-4000, 4000), rng:NextNumber(220, 320), rng:NextNumber(500, 820))
end
-- северо-запад: вулкан
volcano(-3900, 4600, 420, 640)
-- юго-запад: столовые горы
mesa(-3700, -4300, 260, 220)
mesa(-3100, -4900, 190, 170)
mesa(-4300, -3600, 160, 260)
-- север и юг: хребты пониже
ridge(-1500, 5600, 5, 240, 250, 480)
ridge(1200, 5700, 4, 220, 220, 420)
ridge(-1200, -5600, 5, 250, 260, 520)
ridge(1600, -5500, 3, 200, 200, 380)
-- холмы ближе к полям
hills(-3200, 1500, 6)
hills(-3300, -1500, 6)
hills(-2600, 4200, 5)
hills(500, -4600, 5)
hills(-500, 4700, 5)


-- полоса/перрон/вертолётная площадка острова: убираем траву над ними
-- (ландшафт сглаживается и вылезает поверх деталей), режем воздух от y=0 вверх
do
	local AIR = Enum.Material.Air
	for _, b in ipairs({
		{ 4900, 0, 100, 1400 },   -- полоса
		{ 5010, -60, 80, 500 },   -- перрон
		{ 5100, 420, 40, 40 },    -- вертолётная площадка
	}) do
		-- срезаем ландшафт до y = 0: плиты толщиной ~5 studs заполняют эту выемку,
		-- и сглаженная трава (она «вспухает» до 2 studs) больше не налезает сверху
		Terrain:FillBlock(CFrame.new(b[1], 20, b[2]), Vector3.new(b[3], 40, b[4]), AIR)
	end
end

workspace:SetAttribute("WorldReady", true)
