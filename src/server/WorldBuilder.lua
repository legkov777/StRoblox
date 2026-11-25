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
Terrain:FillBlock(CFrame.new(4900, -4, 0), Vector3.new(760, 14, 1900), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(4900, -3, 0), Vector3.new(680, 12, 1800), Enum.Material.Grass)
Terrain:FillBall(Vector3.new(4900, -40, 950), 120, Enum.Material.Sand)
Terrain:FillBall(Vector3.new(4900, -40, -950), 120, Enum.Material.Sand)

---------------------------------------------------------------- ГОРЫ
local rng = Random.new(1978)
local function mountain(x, z, r)
	local base = -r * 0.35
	Terrain:FillBall(Vector3.new(x, base, z), r, Enum.Material.Grass)
	Terrain:FillBall(Vector3.new(x + rng:NextNumber(-r, r) * 0.2, base + r * 0.25, z), r * 0.78, Enum.Material.Rock)
	Terrain:FillBall(Vector3.new(x, base + r * 0.62, z), r * 0.4, Enum.Material.Snow)
	task.wait()
end
for i = 0, 11 do
	mountain(-5300 + rng:NextNumber(-500, 300), -5200 + i * 950 + rng:NextNumber(-200, 200), rng:NextNumber(280, 460))
end
for _ = 1, 10 do
	mountain(rng:NextNumber(-4300, -3300), rng:NextNumber(-4500, 4500), rng:NextNumber(150, 240))
end
for i = 0, 5 do
	mountain(-4000 + i * 1200 + rng:NextNumber(-200, 200), 5600 + rng:NextNumber(-200, 200), rng:NextNumber(250, 400))
	mountain(-4000 + i * 1200 + rng:NextNumber(-200, 200), -5600 + rng:NextNumber(-200, 200), rng:NextNumber(250, 400))
end

workspace:SetAttribute("WorldReady", true)
