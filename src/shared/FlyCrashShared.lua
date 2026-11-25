-- FlyCrash: общие данные для сервера и клиента (ливреи, единицы)
local Shared = {}

Shared.KMH = 2.5      -- studs/сек -> км/ч на приборах
Shared.ALT = 0.5      -- studs -> метры высоты на приборах
Shared.REAL_M = 0.28  -- studs -> метры для характеристик в ангаре

-- a = цвет вместо основного цвета модели, b = вместо второго по площади
Shared.LIVERIES = {
	{ name = "Оригинал" },
	{ name = "Лётная школа", a = Color3.fromRGB(245, 245, 245), b = Color3.fromRGB(200, 40, 40) },
	{ name = "Частный", a = Color3.fromRGB(25, 35, 70), b = Color3.fromRGB(200, 160, 60) },
	{ name = "Чартер", a = Color3.fromRGB(250, 250, 250), b = Color3.fromRGB(240, 120, 40) },
	{ name = "Спецвыпуск", a = Color3.fromRGB(60, 110, 220), b = Color3.fromRGB(250, 210, 40) },
	{ name = "Ретро", a = Color3.fromRGB(235, 225, 190), b = Color3.fromRGB(120, 80, 50) },
}

function Shared.applyLivery(model, idx)
	local L = Shared.LIVERIES[idx]
	if not L or not L.a then return end
	local p1 = model:GetAttribute("FCPrimary")
	local p2 = model:GetAttribute("FCSecondary")
	local h1 = typeof(p1) == "Color3" and p1:ToHex() or nil
	local h2 = typeof(p2) == "Color3" and p2:ToHex() or nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local h = d.Color:ToHex()
			if h1 and h == h1 then
				d.Color = L.a
			elseif h2 and h == h2 then
				d.Color = L.b
			end
		end
	end
end

return Shared
