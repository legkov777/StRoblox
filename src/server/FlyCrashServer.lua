-- FlyCrash: сервер — ангар, магазин, свои самолёты у каждого игрока, хаос, крушения
--
-- Самолёты: папка Workspace > Hangar. Любая модель из Toolbox подойдёт.
-- Паспорт самолёта можно задать атрибутами модели (Properties > Add Attribute):
--   Category (string), Description (string), TopSpeed (number, км/ч),
--   Engines (string), FirstFlight (number), Price (number, 0 = бесплатно),
--   NoseYaw (number: 180 / 90 / -90, если самолёт летит хвостом вперёд)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local IS_STUDIO = RunService:IsStudio()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local DataStoreService = game:GetService("DataStoreService")

local Net = ReplicatedStorage:WaitForChild("FlyCrash")
local ChaosEvent = Net:WaitForChild("Chaos")
local InputEvent = Net:WaitForChild("PilotInput")
local HangarEvent = Net:WaitForChild("Hangar")
local Shared = require(ReplicatedStorage:WaitForChild("FlyCrashShared"))

local CFG = {
	FIRE_TIME = 30,         -- секунд горит до взрыва
	CHAOS_COOLDOWN = 1.2,
	LANDING_REWARD = 20,    -- посадка без пассажиров / не в убежище
	FARE = 25,              -- платит каждый спасённый пассажир
	SAFE_RADIUS = 900,      -- радиус убежища вокруг детали SafeZone
	HORDE_FIRST = 40,       -- через сколько секунд стоянки приходит первая орда
	HORDE_EVERY = 30,       -- потом — каждые N секунд, пока стоишь
	HORDE_SIZE = 12,        -- зомби в орде
	OVERRUN_COUNT = 6,      -- столько зомби у самолёта — и он захвачен...
	OVERRUN_TIME = 4,       -- ...если продержатся рядом столько секунд
	CHAOS_BONUS = 50,
	PASSENGER_REWARD = 25,
	ZOMBIE_REWARD = 10,
	START_MONEY = 300,
	HARD_LANDING_VY = -50,  -- studs/с; на приборе это -25 м/с (быстрее — крушение)
	CLIMB_DRAG = 20,
	RESPAWN_AFTER_CRASH = 6,
}

-- ПРОМОКОДЫ: код = сколько денег даёт. Каждый игрок может активировать код один раз.
-- Добавляй свои строки: ["МОЙКОД"] = 1000,
-- Код из одних цифр (например 1250) даёт ровно столько денег — но только владельцу игры
-- и в Studio, чтобы обычные игроки не накручивали.
local NUMERIC_CODES_FOR_OWNER = true
local CODES = {
	["666"] = 666,
	["FLYCRASH"] = 1000,
	["ZOMBIE"] = 500,
	["GLEBOVIC"] = 2026,
}

-- характеристики по классу: 1 лёгкий, 2 средний, 3 тяжёлый
local PERF = {
	{ accel = 0.20, turn = 0.9, pitch = 0.9 },
	{ accel = 0.14, turn = 0.65, pitch = 0.7 },
	{ accel = 0.10, turn = 0.45, pitch = 0.5 },
}

-- справочник известных моделей (ключ ищется в названии модели)
local META = {
	{ key = "cessna", cap = 4, cat = "ЛЁГКИЙ САМОЛЁТ", top = 302, eng = "1 × поршневой", year = 1955, price = 0,
		desc = "Самый массовый самолёт в истории. Медленный, прощает ошибки и складывается как фольга при крушении." },
	{ key = "atr", cap = 30, cat = "ТУРБОВИНТОВОЙ", top = 510, eng = "2 × PW127", year = 1988, price = 600,
		desc = "Региональный лайнер на 48 мест. Неприхотлив, садится почти куда угодно." },
	{ key = "707", cap = 80, cat = "УЗКОФЮЗЕЛЯЖНЫЙ ЛАЙНЕР", top = 1000, eng = "4 × JT3D", year = 1957, price = 2000,
		desc = "Лайнер, открывший эпоху реактивных путешествий. Тяжёлый, быстрый и требует длинной полосы." },
	{ key = "flycrash", cap = 12, cat = "ЭКСПЕРИМЕНТАЛЬНЫЙ", top = 650, eng = "4 × турбовентиляторный", year = 2026, price = 0,
		desc = "Испытательный борт FlyCrash. Построен, чтобы падать красиво." },
	{ key = "challenger", cap = 10, cat = "БИЗНЕС-ДЖЕТ", top = 870, eng = "2 × CF34-3B", year = 2015, price = 300,
		desc = "Просторный бизнес-джет с Т-образным хвостом. Быстрый и послушный." },
	{ key = "737", cap = 60, cat = "УЗКОФЮЗЕЛЯЖНЫЙ ЛАЙНЕР", top = 840, eng = "2 × CFM56", year = 1967, price = 1250,
		desc = "Самый продаваемый лайнер в истории. Рабочая лошадка коротких рейсов." },
	{ key = "747", cap = 120, cat = "ДЖАМБО-ДЖЕТ", top = 920, eng = "4 × PW4056", year = 1969, price = 4000,
		desc = "Королева неба с горбом второй палубы. Огромный, тяжёлый, величественный." },
	{ key = "embraer", cap = 6, cat = "БИЗНЕС-ДЖЕТ", top = 722, eng = "2 × PW617F", year = 2007, price = 400,
		desc = "Лёгкий бизнес-джет: быстрый, послушный, но всего на шесть пассажиров." },
	{ key = "ac-130", cap = 40, cat = "ВОЕННЫЙ ТРАНСПОРТНИК", top = 480, eng = "4 × T56", year = 1990, price = 3000,
		desc = "Тяжёлый четырёхмоторный транспортник. Медленный, но берёт много людей и садится куда угодно." },
	{ key = "jh-7", cap = 2, cat = "ИСТРЕБИТЕЛЬ-БОМБАРДИРОВЩИК", top = 1400, eng = "2 × WS-9", year = 1988, price = 5000,
		desc = "Сверхзвуковой истребитель. Почти без мест, зато быстрее всех уходит от зомби." },
	{ key = "лайнер", cap = 18, cat = "ПАССАЖИРСКИЙ ЛАЙНЕР", top = 700, eng = "2 × реактивный", year = 1980, price = 900,
		desc = "Простой лайнер на 18 мест — хороший шаг после маленьких самолётов." },
	{ key = "тарый", cap = 1, cat = "КЛАССИКА ROBLOX", top = 260, eng = "1 × винт", year = 2009, price = 0,
		desc = "Самолётик из старого Roblox. Для ностальгии." },
	{ key = "225", cap = 200, cat = "ТЯЖЁЛЫЙ ГРУЗОВОЙ", top = 850, eng = "6 × Д-18Т", year = 1988, price = 6000,
		desc = "Самый большой самолёт из когда-либо построенных. Разгоняется долго, падает эпично." },
}

local runwayParts = {}
local rwObj = workspace:FindFirstChild("Runway")
if rwObj then
	if rwObj:IsA("BasePart") then table.insert(runwayParts, rwObj) end
	for _, d in ipairs(rwObj:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(runwayParts, d) end
	end
end

-- точки старта: все детали с именем, начинающимся на PlaneSpawn (первая — на полосе)
local spawns = {}
for _, p in ipairs(workspace:GetChildren()) do
	if p:IsA("BasePart") and string.sub(p.Name, 1, 10) == "PlaneSpawn" then
		local look = p.CFrame.LookVector
		table.insert(spawns, {
			name = p.Name,
			pos = Vector3.new(p.Position.X, p.Position.Y + p.Size.Y / 2, p.Position.Z),
			yaw = math.atan2(-look.X, -look.Z),
		})
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
	end
end
table.sort(spawns, function(a, b) return a.name < b.name end)
if #spawns == 0 then error("FlyCrash: нет детали PlaneSpawn в Workspace") end

---------------------------------------------------------------- ПОДГОТОВКА МОДЕЛЕЙ
local ENGINE_WORDS = { "engine", "prop", "turbine", "nacelle", "motor", "rotor", "fan" }

local function looksLikeEngine(name)
	local n = string.lower(name)
	for _, w in ipairs(ENGINE_WORDS) do
		if string.find(n, w, 1, true) then return true end
	end
	return false
end

local function prepPlane(model)
	-- 1. Убираем чужие скрипты (в бесплатных моделях бывают вирусы) и физику
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyMover") or d:IsA("Constraint")
			or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("NoCollisionConstraint")
			or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
			d:Destroy()
		end
	end
	for _, n in ipairs({ "Root", "Core" }) do
		local old = model:FindFirstChild(n)
		if old and old:IsA("BasePart") and old.Transparency >= 0.95 then old:Destroy() end
	end

	-- 2. Габариты по видимым деталям
	local parts, visible = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			table.insert(parts, d)
			if d.Transparency < 0.95 then table.insert(visible, d) end
		end
	end
	if #visible == 0 then visible = parts end
	if #visible == 0 then return false end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, p in ipairs(visible) do
		local h = p.Size / 2
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local w = p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
					minV = minV:Min(w)
					maxV = maxV:Max(w)
				end
			end
		end
	end
	local size = maxV - minV
	local center = (minV + maxV) / 2

	-- 3. Где нос. Модель может стоять под любым углом — направление НЕ округляем.
	local function flat(v)
		local f = Vector3.new(v.X, 0, v.Z)
		return f.Magnitude > 1e-4 and f.Unit or nil
	end
	-- хвост: самые высокие детали (киль) — их смещение от центра
	local topY = minV.Y + size.Y * 0.75
	local sum, wsum = Vector3.zero, 0
	for _, p in ipairs(visible) do
		if p.Position.Y >= topY then
			local w = p.Size.Magnitude
			sum += Vector3.new(p.Position.X, 0, p.Position.Z) * w
			wsum += w
		end
	end
	local tailOff = wsum > 0 and (sum / wsum - Vector3.new(center.X, 0, center.Z)) or Vector3.zero
	local tailOk = tailOff.Magnitude > math.max(size.X, size.Z) * 0.04
	-- кресла почти всегда смотрят вперёд
	local seatSum, seatN = Vector3.zero, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			local lv = d.CFrame.LookVector
			seatSum += Vector3.new(lv.X, 0, lv.Z)
			seatN += 1
		end
	end
	local seatsOk = seatN > 0 and seatSum.Magnitude > seatN * 0.5
	-- ось фюзеляжа по «массе»: фюзеляж толстый, крылья тонкие
	local mx, mz, W = 0, 0, 0
	local samples = {}
	for _, p in ipairs(visible) do
		local s = p.Size
		local w = math.max(s.X * s.Y * s.Z, 0.01) / 8
		local h = s / 2
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				for sy = -1, 1, 2 do
					local q = p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
					table.insert(samples, { q.X, q.Z, w })
					mx += q.X * w
					mz += q.Z * w
					W += w
				end
			end
		end
	end
	mx /= W
	mz /= W
	local cxx, czz, cxz = 0, 0, 0
	for _, q in ipairs(samples) do
		local dx, dz = q[1] - mx, q[2] - mz
		cxx += q[3] * dx * dx
		czz += q[3] * dz * dz
		cxz += q[3] * dx * dz
	end
	local th = 0.5 * math.atan2(2 * cxz, cxx - czz)
	local pcaAxis = Vector3.new(math.cos(th), 0, math.sin(th))
	local disc = math.sqrt((cxx - czz) ^ 2 + 4 * cxz * cxz)
	local elong = (cxx + czz + disc) / math.max(1e-6, cxx + czz - disc)

	local nose = Vector3.new(0, 0, -1)
	local function signAlong(ax)
		-- нос — в сторону, противоположную хвосту; иначе — куда смотрят кресла; иначе — где фонарь кабины
		if tailOk and math.abs(tailOff.Unit:Dot(ax)) > 0.3 then
			return tailOff:Dot(ax) > 0 and -1 or 1
		end
		if seatsOk then
			return seatSum:Dot(ax) >= 0 and 1 or -1
		end
		local s = 0
		for _, p in ipairs(visible) do
			local n = string.lower(p.Name)
			if string.find(n, "glass", 1, true) or string.find(n, "canopy", 1, true)
				or string.find(n, "cockpit", 1, true) or string.find(n, "windshield", 1, true) then
				s += (p.Position - center):Dot(ax)
			end
		end
		return s >= 0 and 1 or -1
	end
	local how
	if seatsOk then
		nose = flat(seatSum) or nose
		how = "кресла"
	elseif elong >= 1.6 then
		nose = pcaAxis * signAlong(pcaAxis)
		how = "ось фюзеляжа"
	elseif tailOk then
		nose = -(flat(tailOff) or Vector3.new(0, 0, 1))
		how = "хвост"
	else
		local ax = size.X > size.Z and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
		nose = ax * signAlong(ax)
		how = "габариты"
	end

	-- точный нос по маркеру (у встроенных самолётов он есть)
	local marker = model:FindFirstChild("NoseMarker", true)
	if marker and marker:IsA("BasePart") then
		local dir = Vector3.new(marker.Position.X - center.X, 0, marker.Position.Z - center.Z)
		if dir.Magnitude > 0.1 then
			nose = dir.Unit
			how = "маркер"
		end
	end
	local yawAdj = model:GetAttribute("NoseYaw")
	if typeof(yawAdj) == "number" and yawAdj ~= 0 then
		nose = CFrame.Angles(0, math.rad(yawAdj), 0):VectorToWorldSpace(nose)
	end

	local bottom = Vector3.new(center.X, minV.Y, center.Z)
	local rootCF = CFrame.lookAt(bottom, bottom + nose)
	-- длина и размах — по проекциям на нос и на поперечную ось (модель может стоять под углом)
	local rightAx = Vector3.new(-nose.Z, 0, nose.X)
	local lmin, lmax, smin, smax = math.huge, -math.huge, math.huge, -math.huge
	for _, q in ipairs(samples) do
		local v = Vector3.new(q[1], 0, q[2])
		local a, b = v:Dot(nose), v:Dot(rightAx)
		lmin, lmax = math.min(lmin, a), math.max(lmax, a)
		smin, smax = math.min(smin, b), math.max(smax, b)
	end
	local length = lmax - lmin
	local span = smax - smin

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Anchored = true
	root.CFrame = rootCF
	root.Parent = model
	model.PrimaryPart = root

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(2, 2, 2)
	core.Transparency = 1
	core.CanCollide = false
	core.CanQuery = false
	core.Anchored = true
	core.CFrame = CFrame.lookAt(center, center + nose)
	core.Parent = model

	model:SetAttribute("FCLength", length)
	model:SetAttribute("FCSpan", span)
	model:SetAttribute("FCHeight", size.Y)

	-- 4. Кресла: VehicleSeat или самое переднее кресло становится креслом пилота
	local seatList = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then table.insert(seatList, d) end
	end
	local pilot
	for _, s in ipairs(seatList) do
		if s:IsA("VehicleSeat") then pilot = s break end
	end
	if not pilot and #seatList > 0 then
		local best, bestZ = nil, math.huge
		for _, s in ipairs(seatList) do
			local z = rootCF:PointToObjectSpace(s.Position).Z
			if z < bestZ then best, bestZ = s, z end
		end
		local v = Instance.new("VehicleSeat")
		v.Size = best.Size
		v.CFrame = best.CFrame
		v.Color = best.Color
		v.Material = best.Material
		v.Transparency = best.Transparency
		v.CanCollide = best.CanCollide
		v.Anchored = true
		v.Parent = best.Parent
		best:Destroy()
		pilot = v
	end
	if not pilot then
		-- кресел нет: ставим кресло на крышу ближе к носу
		local top = rootCF:PointToWorldSpace(Vector3.new(0, size.Y + 5, -length * 0.3))
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { model }
		local hit = workspace:Raycast(top, Vector3.new(0, -(size.Y + 10), 0), params)
		local y = hit and hit.Position.Y or (minV.Y + size.Y * 0.5)
		local pos = Vector3.new(top.X, y + 0.5, top.Z)
		pilot = Instance.new("VehicleSeat")
		pilot.Size = Vector3.new(3, 1, 3)
		pilot.Color = Color3.fromRGB(240, 120, 50)
		pilot.CFrame = CFrame.lookAt(pos, pos + nose)
		pilot.Anchored = true
		pilot.Parent = model
		-- и пару пассажирских рядом
		for k = 1, 3 do
			local p2 = rootCF:PointToWorldSpace(Vector3.new(0, size.Y + 5, -length * 0.3 + k * 4))
			local h2 = workspace:Raycast(p2, Vector3.new(0, -(size.Y + 10), 0), params)
			if h2 then
				local s = Instance.new("Seat")
				s.Size = Vector3.new(3, 1, 3)
				s.Color = Color3.fromRGB(90, 70, 200)
				s.CFrame = CFrame.lookAt(h2.Position + Vector3.new(0, 0.5, 0), h2.Position + Vector3.new(0, 0.5, 0) + nose)
				s.Anchored = true
				s.Parent = model
			end
		end
	end
	pilot.Name = "PilotSeat"
	pilot:SetAttribute("FCPilot", true)
	pilot:SetAttribute("FCCam", math.clamp(length * 0.9, 20, 120))

	local okEng, errEng = pcall(function()
	-- 5. Четыре «слота» двигателей на крыльях; помечаем детали, которые оторвутся
	local slotX = { -0.33, -0.18, 0.18, 0.33 }
	local centerLocal = rootCF:PointToObjectSpace(center)
	local slots = {}
	for i = 1, 4 do
		slots[i] = Vector3.new(span * slotX[i], size.Y * 0.3, centerLocal.Z)
	end
	local radius = math.max(3, span * 0.09)
	local bigLimit = span * 0.3
	-- сначала детали с «двигательными» именами — к ближайшему слоту
	local named = { {}, {}, {}, {} }
	for _, p in ipairs(visible) do
		if p ~= pilot and not p:IsA("Seat") and looksLikeEngine(p.Name) then
			local lp = rootCF:PointToObjectSpace(p.Position)
			local bi, bd = 1, math.huge
			for i = 1, 4 do
				local d = math.abs(lp.X - slots[i].X)
				if d < bd then bi, bd = i, d end
			end
			p:SetAttribute("FCEngine", bi)
			table.insert(named[bi], lp)
		end
	end
	for i = 1, 4 do
		if #named[i] > 0 then
			local s = Vector3.zero
			for _, v in ipairs(named[i]) do s += v end
			slots[i] = s / #named[i]
		end
	end
	-- потом мелкие детали рядом со слотом
	for _, p in ipairs(visible) do
		if p:GetAttribute("FCEngine") == nil and p ~= pilot and not p:IsA("Seat")
			and math.max(p.Size.X, p.Size.Y, p.Size.Z) <= bigLimit then
			local lp = rootCF:PointToObjectSpace(p.Position)
			for i = 1, 4 do
				if (lp - slots[i]).Magnitude <= radius then
					p:SetAttribute("FCEngine", i)
					break
				end
			end
		end
	end
	for i = 1, 4 do
		model:SetAttribute("FCSlot" .. i, slots[i])
	end

	end)
	if not okEng then warn("FlyCrash: " .. model.Name .. " — двигатели не распознаны: " .. tostring(errEng)) end

	local okGear, errGear = pcall(function()
	-- 6а. Шасси: детали (или их родительские модели) с «колёсными» именами
	local function gearName(n)
		n = string.lower(n)
		if string.find(n, "light", 1, true) then return false end
		for _, w in ipairs({ "gear", "wheel", "tire", "tyre", "bogie", "axle", "шасси", "колес" }) do
			if string.find(n, w, 1, true) then return true end
		end
		return string.sub(n, 1, 5) == "strut"
	end
	local gearCount = 0
	for _, p in ipairs(visible) do
		if not p:IsA("Seat") and not p:IsA("VehicleSeat") and p:GetAttribute("FCEngine") == nil then
			local a = p
			while a and a ~= model do
				if gearName(a.Name) then
					p:SetAttribute("FCGear", true)
					gearCount += 1
					break
				end
				a = a.Parent
			end
		end
	end
	if gearCount == 0 then
		-- имён нет: считаем шасси мелкие детали у самого низа самолёта
		local band = minY + size.Y * 0.14
		for _, p in ipairs(visible) do
			if p:GetAttribute("FCEngine") == nil and not p:IsA("Seat") and not p:IsA("VehicleSeat")
				and p.Position.Y + p.Size.Y / 2 < band and math.max(p.Size.X, p.Size.Y, p.Size.Z) < length * 0.12 then
				p:SetAttribute("FCGear", true)
				gearCount += 1
			end
		end
	end
	model:SetAttribute("FCGearCount", gearCount)
	-- на землю ставим колёса, а не случайную деталь, торчащую ниже них
	if gearCount > 0 then
		local gmin = math.huge
		for _, gp in ipairs(visible) do
			if gp:GetAttribute("FCGear") then
				local hs = gp.Size / 2
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							gmin = math.min(gmin, gp.CFrame:PointToWorldSpace(Vector3.new(hs.X * sx, hs.Y * sy, hs.Z * sz)).Y)
						end
					end
				end
			end
		end
		if gmin < math.huge and gmin - minV.Y > 0.05 and gmin - minV.Y < size.Y * 0.3 then
			local nb = Vector3.new(bottom.X, gmin, bottom.Z)
			root.CFrame = CFrame.lookAt(nb, nb + nose)
		end
	end

	end)
	if not okGear then warn("FlyCrash: " .. model.Name .. " — шасси не распознаны: " .. tostring(errGear)) end

	-- пропеллеры: детали (или их родители) с «винтовыми» именами — крутим их в полёте
	pcall(function()
		local PROP_WORDS = { "prop", "rotor", "blade", "spinner", "винт", "лопаст" }
		local nProp = 0
		for _, part in ipairs(visible) do
			local a = part
			while a and a ~= model do
				local n = string.lower(a.Name)
				local hit = false
				for _, w in ipairs(PROP_WORDS) do
					if string.find(n, w, 1, true) then hit = true break end
				end
				if hit then
					part:SetAttribute("FCProp", true)
					nProp += 1
					break
				end
				a = a.Parent
			end
		end
		model:SetAttribute("FCPropCount", nProp)
	end)

	local okCol, errCol = pcall(function()
	-- 6. Основные цвета (для ливрей): два цвета с наибольшей площадью, не тёмные и не стекло
	local areas = {}
	for _, p in ipairs(visible) do
		if p.Transparency < 0.3 and not p:IsA("Seat") and not p:IsA("VehicleSeat") then
			local c = p.Color
			if (c.R + c.G + c.B) / 3 > 0.15 then
				local s = p.Size
				local key = c:ToHex()
				areas[key] = (areas[key] or 0) + s.X * s.Y + s.Y * s.Z + s.X * s.Z
			end
		end
	end
	local ranked = {}
	for k, a in pairs(areas) do table.insert(ranked, { k = k, a = a }) end
	table.sort(ranked, function(x, y) return x.a > y.a end)
	if ranked[1] then model:SetAttribute("FCPrimary", Color3.fromHex(ranked[1].k)) end
	if ranked[2] then model:SetAttribute("FCSecondary", Color3.fromHex(ranked[2].k)) end

	end)
	if not okCol then warn("FlyCrash: " .. model.Name .. " — цвета для ливрей не найдены: " .. tostring(errCol)) end

	-- 7. Паспорт самолёта: атрибуты модели (можно задать вручную) или справочник
	local meta = nil
	local lname = string.lower(model.Name)
	for _, m in ipairs(META) do
		if string.find(lname, m.key, 1, true) then meta = m break end
	end
	local class = length < 35 and 1 or (length < 80 and 2 or 3)
	local defaults = {
		{ cat = "ЛЁГКИЙ САМОЛЁТ", top = 320, price = 150, eng = "1 × поршневой" },
		{ cat = "СРЕДНИЙ САМОЛЁТ", top = 600, price = 500, eng = "2 × турбовинтовой" },
		{ cat = "ТЯЖЁЛЫЙ ЛАЙНЕР", top = 900, price = 1500, eng = "4 × реактивный" },
	}
	local d = defaults[class]
	local function attr(name, fallback)
		local v = model:GetAttribute(name)
		if v ~= nil then return v end
		return fallback
	end
	model:SetAttribute("FCClass", class)
	model:SetAttribute("FCCategory", attr("Category", meta and meta.cat or d.cat))
	model:SetAttribute("FCDescription", attr("Description", meta and meta.desc or "Самолёт из ангара FlyCrash."))
	model:SetAttribute("FCTopSpeed", attr("TopSpeed", meta and meta.top or d.top))
	model:SetAttribute("FCEngines", attr("Engines", meta and meta.eng or d.eng))
	model:SetAttribute("FCFirstFlight", attr("FirstFlight", meta and meta.year or "—"))
	model:SetAttribute("FCPrice", attr("Price", meta and meta.price or d.price))
	model:SetAttribute("FCCapacity", attr("Capacity", meta and meta.cap or ({ 4, 20, 60 })[class]))
	print(("FlyCrash: «%s» готов — нос по: %s, длина %d, размах %d, шасси %d"):format(
		model.Name, how or "?", math.floor(length), math.floor(span), model:GetAttribute("FCGearCount") or 0))
	return true
end

local hangarStore = Instance.new("Folder")
hangarStore.Name = "FlyCrashHangar"
hangarStore.Parent = ReplicatedStorage -- клиенты рисуют самолёты в ангаре

local planeNames = {}
local hangar = workspace:FindFirstChild("Hangar")
if not hangar then
	hangar = Instance.new("Folder")
	hangar.Name = "Hangar"
	hangar.Parent = workspace
end
-- самолёты, брошенные прямо в Workspace (не в папку Hangar), тоже забираем
local SKIP = {
	Hangar = true, HangarBuilding = true, Airport = true, Trees = true, TreeRows = true, Fields = true,
	Villages = true, Roads = true, City = true, Ground = true, RunwayMarkings = true, Runway = true,
	RunwayLights = true, Taxiways = true, Vegetation = true, Traffic = true,
	Zombies = true, Birds = true, Drones = true, Flights = true, FlyCrashDebris = true, ZombiesLive = true,
	Civilians = true, SafeAirport = true, PassengerGate = true,
}
local PLANE_WORDS = {
	"plane", "cessna", "boeing", "airbus", "atr", "jet", "aircraft", "fly", "самол", "707", "737", "747",
	"embraer", "phenom", "lockheed", "gunship", "c-130", "antonov", "tupolev", "ilyushin", "sukhoi", "mig",
	"fighter", "bomber", "airliner", "bombardier", "concorde", "douglas", "a320", "a380", "piper", "pilatus", "лайнер",
}
for _, m in ipairs(workspace:GetChildren()) do
	if m:IsA("Model") and not SKIP[m.Name] and not m:FindFirstChildOfClass("Humanoid") then
		local n = string.lower(m.Name)
		-- самолёт: есть кресло (пилота или пассажира) или «самолётное» слово в названии
		local looks = m:FindFirstChildWhichIsA("VehicleSeat", true) ~= nil or m:FindFirstChildWhichIsA("Seat", true) ~= nil
		for _, w in ipairs(PLANE_WORDS) do
			if string.find(n, w, 1, true) then looks = true end
		end
		if looks then
			m.Parent = hangar
		end
	end
end
do
	for _, f in ipairs(hangar:GetChildren()) do
		if f:IsA("Folder") then
			for _, m in ipairs(f:GetChildren()) do
				if m:IsA("Model") then m.Parent = hangar end
			end
			f:Destroy()
		end
	end
	-- одинаковые названия мешают выбору — делаем их уникальными
	local usedNames = {}
	for _, m in ipairs(hangar:GetChildren()) do
		if m:IsA("Model") then
			local base, n = m.Name, 1
			while usedNames[m.Name] do
				n += 1
				m.Name = base .. " " .. n
			end
			usedNames[m.Name] = true
		end
	end
	for _, m in ipairs(hangar:GetChildren()) do
		if m:IsA("Model") then
			local ok, res = pcall(prepPlane, m)
			if ok and res then
				m.Parent = hangarStore
				table.insert(planeNames, m.Name)
			else
				warn("FlyCrash: не удалось подготовить модель " .. m.Name .. ": " .. tostring(res))
				m:Destroy()
			end
		elseif m:IsA("LuaSourceContainer") then
			m:Destroy()
		end
	end
	hangar:Destroy()
end
if #planeNames == 0 then error("FlyCrash: в папке Workspace > Hangar нет ни одной модели самолёта") end
-- порядок в ленте: от дешёвых к дорогим
table.sort(planeNames, function(a, b)
	local pa = hangarStore[a]:GetAttribute("FCPrice") or 0
	local pb = hangarStore[b]:GetAttribute("FCPrice") or 0
	if pa == pb then return a < b end
	return pa < pb
end)
Net:SetAttribute("Planes", table.concat(planeNames, "|"))
Net:SetAttribute("SafeVS", math.floor(CFG.HARD_LANDING_VY * Shared.ALT * 0.8)) -- с запасом

local function priceOf(name)
	local m = hangarStore:FindFirstChild(name)
	return m and (m:GetAttribute("FCPrice") or 0) or math.huge
end

---------------------------------------------------------------- ПТИЦЫ И ДРОНЫ (свои модели)
local function prepProps(folderName, targetSize)
	local list = {}
	local f = workspace:FindFirstChild(folderName)
	if not f then return list end
	for _, m in ipairs(f:GetChildren()) do
		if m:IsA("Model") or m:IsA("BasePart") then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") then d:Destroy() end
			end
			local parts = {}
			if m:IsA("BasePart") then table.insert(parts, m) end
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(parts, d) end
			end
			for _, p in ipairs(parts) do
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
			end
			if m:IsA("Model") then
				local ext = m:GetExtentsSize()
				local mx = math.max(ext.X, ext.Y, ext.Z)
				if mx > 0 then
					pcall(function() m:ScaleTo(m:GetScale() * targetSize / mx) end)
				end
			end
			m.Parent = ServerStorage
			table.insert(list, m)
		end
	end
	f:Destroy()
	return list
end
local birdModels = prepProps("Birds", 5)
local droneModels = prepProps("Drones", 5)

---------------------------------------------------------------- ДЕНЬГИ И СОХРАНЕНИЯ
local store = nil
pcall(function() store = DataStoreService:GetDataStore("FlyCrash_v1") end)
local pdata = {} -- [player] = { owned = { [name] = true } }

local function moneyValue(p)
	local ls = p:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Деньги")
end

local function addMoney(p, amount, reason)
	local m = p and moneyValue(p)
	if not m then return end
	m.Value += amount
	-- клиент покажет крупное «+$» с монетками
	if amount > 0 and reason and p.Parent then
		HangarEvent:FireClient(p, "reward", amount, reason)
	end
end

local function publishOwned(p)
	local d = pdata[p]
	if not d then return end
	local list = {}
	for n in pairs(d.owned) do table.insert(list, n) end
	p:SetAttribute("Owned", table.concat(list, "|"))
end

local function loadPlayer(p)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = p
	local m = Instance.new("IntValue")
	m.Name = "Деньги"
	m.Parent = ls

	local saved = nil
	if store then
		local ok, res = pcall(function() return store:GetAsync("p_" .. p.UserId) end)
		if ok then saved = res end
	end
	local rescued = Instance.new("IntValue")
	rescued.Name = "Спасено"
	rescued.Value = (saved and saved.rescued) or 0
	rescued.Parent = ls
	m.Value = (saved and saved.money) or CFG.START_MONEY
	local owned = {}
	if saved and saved.owned then
		for _, n in ipairs(saved.owned) do owned[n] = true end
	end
	for _, n in ipairs(planeNames) do
		if priceOf(n) <= 0 then owned[n] = true end
	end
	local used = {}
	if saved and saved.codes then
		for _, c in ipairs(saved.codes) do used[c] = true end
	end
	pdata[p] = { owned = owned, used = used }
	publishOwned(p)
end

local function savePlayer(p)
	local d = pdata[p]
	local m = moneyValue(p)
	if not store or not d or not m then return end
	local list = {}
	for n in pairs(d.owned) do table.insert(list, n) end
	pcall(function()
		local r = p.leaderstats:FindFirstChild("Спасено")
		local codes = {}
		for c in pairs(d.used or {}) do table.insert(codes, c) end
		store:SetAsync("p_" .. p.UserId, { money = m.Value, owned = list, rescued = r and r.Value or 0, codes = codes })
	end)
end

---------------------------------------------------------------- ЗВУКИ
local SoundLib = ReplicatedStorage:FindFirstChild("FlyCrashSounds")

local function getSound(name)
	local snd = SoundLib and SoundLib:FindFirstChild(name)
	if snd and snd:IsA("Sound") and snd.SoundId ~= "" then return snd end
	return nil
end

local function playSound(name, parent, looped)
	local snd = getSound(name)
	if not snd or not parent then return nil end
	local c = snd:Clone()
	c.RollOffMinDistance = math.max(c.RollOffMinDistance, 40)
	c.Looped = looped == true
	c.Parent = parent
	c:Play()
	if not looped then
		Debris:AddItem(c, math.max(5, (c.TimeLength > 0 and c.TimeLength or 10) + 1))
	end
	return c
end

local debrisFolder = Instance.new("Folder")
debrisFolder.Name = "FlyCrashDebris"
debrisFolder.Parent = workspace

local flightsFolder = Instance.new("Folder")
flightsFolder.Name = "Flights"
flightsFolder.Parent = workspace

local function playSoundAt(name, pos)
	if not getSound(name) then return end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = debrisFolder
	playSound(name, p)
	Debris:AddItem(p, 15)
end

local function boom(pos, size)
	playSoundAt("Explosion", pos)
	local ex = Instance.new("Explosion")
	ex.Position = pos
	ex.BlastRadius = size or 8
	ex.BlastPressure = 0
	ex.DestroyJointRadiusPercent = 0
	ex.Parent = workspace
end

---------------------------------------------------------------- ПОГОДА
local savedLighting = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
}
local weatherToken = 0
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local savedAtmo = atmo and { Density = atmo.Density, Haze = atmo.Haze, Color = atmo.Color } or nil
local function restoreWeather()
	for k, v in pairs(savedLighting) do
		Lighting[k] = v
	end
	atmo = atmo or Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo and savedAtmo then
		for k, v in pairs(savedAtmo) do atmo[k] = v end
	end
end

---------------------------------------------------------------- ПОЛЁТЫ
local flights = {} -- [player] = flight
local hazards = {}

local function flightPlayers(f)
	local list = {}
	local seen = {}
	if f.owner and f.owner.Parent then
		table.insert(list, f.owner)
		seen[f.owner] = true
	end
	for _, s in ipairs(f.seats) do
		if s.Parent and s.Occupant then
			local p = Players:GetPlayerFromCharacter(s.Occupant.Parent)
			if p and not seen[p] then
				table.insert(list, p)
				seen[p] = true
			end
		end
	end
	return list
end

local function msg(f, text)
	for _, p in ipairs(flightPlayers(f)) do
		p:SetAttribute("FCMessage", text)
		p:SetAttribute("FCMessageT", os.clock())
	end
end

local function getPilot(f)
	if f.pilotSeat and f.pilotSeat.Parent and f.pilotSeat.Occupant then
		return Players:GetPlayerFromCharacter(f.pilotSeat.Occupant.Parent)
	end
	return nil
end

local function engineCounts(f)
	local d = f.engineDead
	local l = (d[1] and 0 or 1) + (d[2] and 0 or 1)
	local r = (d[3] and 0 or 1) + (d[4] and 0 or 1)
	return l + r, l, r
end

local function onRunway(pos)
	if #runwayParts == 0 then return true end
	for _, rp in ipairs(runwayParts) do
		local p = rp.CFrame:PointToObjectSpace(pos)
		if math.abs(p.X) <= rp.Size.X / 2 + 10 and math.abs(p.Z) <= rp.Size.Z / 2 + 30 then return true end
	end
	-- рулёжки тоже считаем полосой
	local tw = workspace:FindFirstChild("Taxiways")
	if tw then
		for _, rp in ipairs(tw:GetChildren()) do
			if rp:IsA("BasePart") and rp.Name == "Taxiway" then
				local p = rp.CFrame:PointToObjectSpace(pos)
				if math.abs(p.X) <= rp.Size.X / 2 + 5 and math.abs(p.Z) <= rp.Size.Z / 2 + 10 then return true end
			end
		end
	end
	return false
end

local function pickSpawn(ignore)
	for _, sp in ipairs(spawns) do
		local free = true
		for _, f in pairs(flights) do
			if f ~= ignore and f.core and f.core.Parent and not f.state.crashed then
				local dist = (Vector3.new(f.state.pos.X, sp.pos.Y, f.state.pos.Z) - sp.pos).Magnitude
				if dist < f.length * 0.6 + 40 then
					free = false
					break
				end
			end
		end
		if free then return sp end
	end
	return spawns[1]
end

local destroyFlight, spawnFlight -- объявлены ниже

---------------------------------------------------------------- КРУШЕНИЕ
local function crash(f, reason)
	local st = f.state
	if st.crashed then return end
	st.crashed = true
	local token = f.token
	if f.engineSound then f.engineSound:Stop() end
	if f.fireSound then f.fireSound:Stop() end
	playSoundAt("Crash", f.core.Position)
	playSoundAt("Explosion", f.core.Position)

	local ex = Instance.new("Explosion")
	ex.Position = f.core.Position
	ex.BlastRadius = math.max(30, f.length * 0.5)
	ex.BlastPressure = 150000
	ex.DestroyJointRadiusPercent = 0
	ex.Parent = workspace

	f.plane:SetAttribute("EngineOn", false)
	f.plane:SetAttribute("State", "КРУШЕНИЕ")
	local riders = flightPlayers(f)
	for _, s in ipairs(f.seats) do
		local w = s:FindFirstChild("SeatWeld")
		if w then w:Destroy() end
	end
	local prompt = f.plane:FindFirstChild("BoardPrompt", true)
	if prompt then prompt:Destroy() end

	local fires = 0
	for _, p in ipairs(f.plane:GetDescendants()) do
		if p:IsA("BasePart") and p ~= f.plane.PrimaryPart and p ~= f.core then
			p.Anchored = false
			if p.Transparency < 0.95 then p.CanCollide = true end
			p.AssemblyLinearVelocity = st.vel * 0.5
				+ Vector3.new(math.random(-50, 50), math.random(20, 60), math.random(-50, 50))
			p.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			if fires < 25 and p.Transparency < 0.95 and math.random() < 0.3 then
				fires += 1
				local fire = Instance.new("Fire")
				fire.Size = 10
				fire.Parent = p
			end
		end
	end

	if f.passengers > 0 then
		reason = reason .. ". Погибло пассажиров: " .. f.passengers
		f.passengers = 0
	end
	for _, p in ipairs(riders) do
		p:SetAttribute("FCMessage", "КРУШЕНИЕ: " .. reason)
		p:SetAttribute("FCMessageT", os.clock())
		HangarEvent:FireClient(p, "crashed", reason)
	end
	task.delay(CFG.RESPAWN_AFTER_CRASH, function()
		if f.token == token and flights[f.owner] == f then
			destroyFlight(f.owner)
			if f.owner.Parent then HangarEvent:FireClient(f.owner, "open") end
		end
	end)
end

---------------------------------------------------------------- ДВИГАТЕЛИ
local function detachEngine(f, i)
	if f.engineDead[i] then return false end
	f.engineDead[i] = true
	playSound("EngineFail", f.core)
	local slot = f.plane:GetAttribute("FCSlot" .. i)
	local effectPos = slot and f.plane.PrimaryPart.CFrame:PointToWorldSpace(slot) or f.core.Position
	local pieces = {}
	for _, p in ipairs(f.plane:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("FCEngine") == i then
			table.insert(pieces, p)
		end
	end
	if #pieces == 0 then
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(3, 2.5, 4)
		chunk.Color = Color3.fromRGB(60, 60, 65)
		chunk.Material = Enum.Material.Metal
		chunk.CFrame = CFrame.new(effectPos)
		chunk.Anchored = true
		chunk.Parent = f.plane
		table.insert(pieces, chunk)
	end
	for k, p in ipairs(pieces) do
		p.Parent = debrisFolder
		p.Anchored = false
		p.CanCollide = true
		p.AssemblyLinearVelocity = f.state.vel * 0.6 + Vector3.new(math.random(-15, 15), -10, math.random(-15, 15))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		if k <= 3 then
			Instance.new("Fire", p).Size = 8
			Instance.new("Smoke", p).RiseVelocity = 4
		end
		Debris:AddItem(p, 20)
	end
	boom(effectPos, 10)
	local alive = engineCounts(f)
	if alive == 0 then
		msg(f, "ВСЕ ДВИГАТЕЛИ ПОТЕРЯНЫ! Планируй и садись.")
	else
		msg(f, ("Двигатель %d оторван! Осталось: %d. Самолёт тянет в сторону."):format(i, alive))
	end
	return true
end

local function detachRandomEngine(f)
	local list = {}
	for i = 1, 4 do
		if not f.engineDead[i] then table.insert(list, i) end
	end
	if #list == 0 then return false end
	return detachEngine(f, list[math.random(#list)])
end

---------------------------------------------------------------- УГРОЗЫ
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function addHazard(f, obj, startPos, speed, radius, lifetime, onHit)
	local dir = f.core.Position - startPos
	if dir.Magnitude < 1 then dir = Vector3.new(0, 0, 1) end
	dir = dir.Unit
	obj.Parent = debrisFolder
	obj:PivotTo(CFrame.lookAt(startPos, startPos + dir))
	table.insert(hazards, {
		f = f, obj = obj, vel = dir * speed, radius = math.max(radius, f.length * 0.4),
		expires = os.clock() + lifetime, onHit = onHit,
	})
end

local function updateHazards(dt, now)
	for i = #hazards, 1, -1 do
		local h = hazards[i]
		if not h.obj.Parent or now > h.expires then
			h.obj:Destroy()
			table.remove(hazards, i)
		else
			h.obj:PivotTo(h.obj:GetPivot() + h.vel * dt)
			local f = h.f
			if flights[f.owner] == f and not f.state.crashed and f.core.Parent
				and (h.obj:GetPivot().Position - f.core.Position).Magnitude < h.radius then
				h.obj:Destroy()
				table.remove(hazards, i)
				h.onHit(f)
			end
		end
	end
end

local function ahead(f, minDist)
	local cf = CFrame.Angles(0, f.state.yaw, 0)
	local dist = math.max(minDist, f.state.speed * 3.5)
	return f.core.Position + cf.LookVector * dist, cf.RightVector
end

---------------------------------------------------------------- ШАССИ
local function setGear(f, down)
	if not f.hasGear or f.gearDown == down then return end
	f.gearDown = down
	for _, p in ipairs(f.gearParts) do
		if p.Parent then
			if down then
				p.Transparency = p:GetAttribute("FCGearT") or 0
				p.CanCollide = p:GetAttribute("FCGearC") == true
			else
				p:SetAttribute("FCGearT", p.Transparency)
				p:SetAttribute("FCGearC", p.CanCollide)
				p.Transparency = 1
				p.CanCollide = false
			end
		end
	end
	playSound("Gear", f.core)
end

local CHAOS = {}

CHAOS.gear = function(f)
	if not f.hasGear then return false end
	f.gearJamUntil = os.clock() + 20
	if not f.state.onGround then setGear(f, false) end
	playSound("Alarm", f.core)
	msg(f, "ШАССИ ЗАКЛИНИЛО! 20 секунд их не выпустить — не садись!")
	return true
end

CHAOS.engine = function(f, arg)
	local i = tonumber(arg)
	if not i or i < 1 or i > 4 then return false end
	return detachEngine(f, i)
end

CHAOS.fire = function(f)
	if f.state.fireStart then return false end
	f.state.fireStart = os.clock()
	local fire = Instance.new("Fire")
	fire.Name = "CabinFire"
	fire.Size = math.clamp(f.length * 0.25, 8, 25)
	fire.Heat = 15
	fire.Parent = f.core
	local s = Instance.new("Smoke")
	s.Name = "CabinSmoke"
	s.Size = 6
	s.Opacity = 0.4
	s.Parent = f.core
	f.fireSound = playSound("Fire", f.core, true)
	playSound("Alarm", f.core)
	msg(f, ("ПОЖАР В САЛОНЕ! Посади самолёт и остановись за %d сек!"):format(CFG.FIRE_TIME))
	return true
end

CHAOS.fall = function(f)
	f.state.lostControlUntil = os.clock() + 4
	playSound("Alarm", f.core)
	msg(f, "ПОТЕРЯ КОНТРОЛЯ! Штурвал не слушается 4 секунды!")
	return true
end

CHAOS.explosion = function(f)
	crash(f, "Взрыв на борту")
	return true
end

CHAOS.geese = function(f)
	local center, right = ahead(f, 260)
	for _ = 1, 9 do
		local g
		if #birdModels > 0 then
			g = birdModels[math.random(#birdModels)]:Clone()
		else
			g = makePart({
				Name = "Goose", Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.5, 2.5, 2.5), Color = Color3.fromRGB(235, 235, 225),
			})
		end
		local offset = right * math.random(-18, 18) + Vector3.new(0, math.random(-6, 6), math.random(-10, 10))
		addHazard(f, g, center + offset, 45, 16, 12, function(ff)
			if math.random() < 0.4 then
				if not detachRandomEngine(ff) then msg(ff, "Гуси бьются о фюзеляж!") end
			else
				msg(ff, "Удар птицы! Держи курс.")
			end
		end)
	end
	playSound("Geese", f.core)
	msg(f, "ГУСИ! Стая прямо по курсу — уходи вверх или в сторону!")
	return true
end

CHAOS.drone = function(f)
	local pos = ahead(f, 220) + Vector3.new(0, 2, 0)
	local m
	if #droneModels > 0 then
		m = droneModels[math.random(#droneModels)]:Clone()
	else
		m = Instance.new("Model")
		m.Name = "Drone"
		local body = makePart({ Name = "Body", Size = Vector3.new(3, 1, 3), Color = Color3.fromRGB(30, 30, 35) })
		body.Parent = m
		for _, off in ipairs({ Vector3.new(2, 0.4, 2), Vector3.new(-2, 0.4, 2), Vector3.new(2, 0.4, -2), Vector3.new(-2, 0.4, -2) }) do
			makePart({
				Size = Vector3.new(2.4, 0.2, 2.4), CFrame = CFrame.new(off),
				Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon,
			}).Parent = m
		end
		m.PrimaryPart = body
	end
	local dp = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart", true)
	if dp then playSound("Drone", dp, true) end
	addHazard(f, m, pos, 60, 18, 12, function(ff)
		boom(ff.core.Position, 12)
		if not detachRandomEngine(ff) then msg(ff, "Дрон врезался в корпус!") end
	end)
	msg(f, "ДРОН на курсе! Манёвр уклонения!")
	return true
end

CHAOS.plane = function(f)
	local startPos = ahead(f, 800) + Vector3.new(0, math.random(-4, 4), 0)
	local others = {}
	for _, n in ipairs(planeNames) do
		if n ~= f.name then table.insert(others, n) end
	end
	local m
	if #others > 0 then
		m = hangarStore:FindFirstChild(others[math.random(#others)]):Clone()
		m.PrimaryPart = m:FindFirstChild("Root")
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		startPos -= Vector3.new(0, (m:GetAttribute("FCHeight") or 10) * 0.4, 0)
	else
		local red, white = Color3.fromRGB(200, 40, 40), Color3.fromRGB(230, 230, 230)
		m = Instance.new("Model")
		local b = makePart({ Name = "Body", Size = Vector3.new(6, 6, 46), Color = red, CFrame = CFrame.new() })
		b.Parent = m
		makePart({ Size = Vector3.new(52, 1, 10), Color = white, CFrame = CFrame.new(0, -1, 0) }).Parent = m
		makePart({ Size = Vector3.new(1, 8, 6), Color = red, CFrame = CFrame.new(0, 5, 20) }).Parent = m
		m.PrimaryPart = b
	end
	m.Name = "OncomingPlane"
	addHazard(f, m, startPos, 130, 32, 14, function(ff)
		crash(ff, "Столкновение со встречным бортом")
	end)
	playSound("Alarm", f.core)
	msg(f, "ВСТРЕЧНЫЙ БОРТ! Немедленно уходи с курса!")
	return true
end

CHAOS.weather = function(f)
	f.state.turbulenceUntil = os.clock() + 15
	return true
end

---------------------------------------------------------------- СОЗДАНИЕ / УДАЛЕНИЕ ПОЛЁТА
destroyFlight = function(owner)
	local f = flights[owner]
	if not f then return end
	f.token += 1
	flights[owner] = nil
	if f.plane then f.plane:Destroy() end
	for i = #hazards, 1, -1 do
		if hazards[i].f == f then
			hazards[i].obj:Destroy()
			table.remove(hazards, i)
		end
	end
end

local function newState(sp)
	return {
		pos = sp.pos, yaw = sp.yaw, pitch = 0, roll = 0,
		speed = 0, throttle = 0, onGround = true, crashed = false,
		lostControlUntil = 0, turbulenceUntil = 0, fireStart = nil,
		airborneTime = 0, flew = false, chaosCount = 0, vel = Vector3.zero, groundY = sp.pos.Y,
	}
end

spawnFlight = function(owner, planeName, livery)
	local tmpl = hangarStore:FindFirstChild(planeName)
	if not tmpl then return end
	local prev = flights[owner]
	local token = prev and prev.token + 1 or 1
	destroyFlight(owner)

	local f = {
		owner = owner, name = planeName, livery = livery, token = token,
		input = { pitch = 0, steer = 0 }, engineDead = {}, publishT = 0, passengers = 0,
	}
	local plane = tmpl:Clone()
	plane.Name = owner.Name
	plane.PrimaryPart = plane:FindFirstChild("Root")
	Shared.applyLivery(plane, livery)
	f.plane = plane
	f.core = plane:FindFirstChild("Core")
	f.length = plane:GetAttribute("FCLength") or 60
	f.span = plane:GetAttribute("FCSpan") or 70
	local h = plane:GetAttribute("FCHeight") or 14
	local class = plane:GetAttribute("FCClass") or 2
	local perf = PERF[class]
	local top = (plane:GetAttribute("FCTopSpeed") or 600) / Shared.KMH
	f.perf = {
		max = top, accel = top * perf.accel, turn = perf.turn, pitch = perf.pitch,
		takeoff = top * 0.3, stall = top * 0.24,
	}
	f.probes = {
		{ name = "Нос", offset = Vector3.new(0, h * 0.35, -f.length / 2) },
		{ name = "Левое крыло", offset = Vector3.new(-f.span / 2, h * 0.3, 0) },
		{ name = "Правое крыло", offset = Vector3.new(f.span / 2, h * 0.3, 0) },
		{ name = "Хвост", offset = Vector3.new(0, h * 0.6, f.length / 2) },
	}
	local sp = pickSpawn(nil)
	f.state = newState(sp)
	plane:PivotTo(CFrame.new(sp.pos) * CFrame.Angles(0, sp.yaw, 0))
	plane:SetAttribute("FCOwner", owner.UserId)
	plane:SetAttribute("PlaneName", planeName)
	plane:SetAttribute("TakeoffKmh", math.floor(f.perf.takeoff * Shared.KMH))
	f.capacity = plane:GetAttribute("FCCapacity") or 10
	plane:SetAttribute("Passengers", 0)
	plane:SetAttribute("Capacity", f.capacity)
	plane.Parent = flightsFolder
	flights[owner] = f

	f.pilotSeat = plane:FindFirstChild("PilotSeat", true)
	f.pilotSeat.HeadsUpDisplay = false
	f.pilotSeat.MaxSpeed = 0
	f.pilotSeat.Torque = 0
	f.seats = {}
	for _, d in ipairs(plane:GetDescendants()) do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then table.insert(f.seats, d) end
	end

	f.gearParts = {}
	for _, d in ipairs(plane:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("FCGear") then table.insert(f.gearParts, d) end
	end
	f.hasGear = #f.gearParts > 0
	f.gearDown = true
	f.gearJamUntil = 0
	f.hordeAt = os.clock() + CFG.HORDE_FIRST
	f.overrunT = 0

	-- пропеллеры: группы по двигателям, крутим вокруг втулки
	f.props = {}
	do
		local rootCF = plane.PrimaryPart.CFrame
		local groups, order = {}, {}
		for _, d in ipairs(plane:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("FCProp") then
				local slot = d:GetAttribute("FCEngine")
				local key = slot and ("s" .. slot) or d:GetFullName()
				if not groups[key] then
					groups[key] = { slot = slot, parts = {}, angle = math.random() * 6 }
					table.insert(order, groups[key])
				end
				table.insert(groups[key].parts, { p = d, base = rootCF:ToObjectSpace(d.CFrame) })
			end
		end
		for _, g in ipairs(order) do
			local s = Vector3.zero
			for _, e in ipairs(g.parts) do s += e.base.Position end
			g.hub = s / #g.parts
			table.insert(f.props, g)
		end
	end

	f.engineStarted = false
	f.engineSound = playSound("EngineLoop", f.core, true)
	if f.engineSound then f.engineSound.Volume = 0 end

	-- другие игроки могут сесть пассажирами
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BoardPrompt"
	prompt.ActionText = "Сесть пассажиром"
	prompt.ObjectText = planeName .. " (" .. owner.Name .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = math.max(40, f.length * 0.6 + 25)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = f.core
	f.prompt = prompt
	prompt.Triggered:Connect(function(p)
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or hum.SeatPart then return end
		if p == owner and not f.pilotSeat.Occupant then
			f.pilotSeat:Sit(hum)
			return
		end
		for _, s in ipairs(f.seats) do
			if s ~= f.pilotSeat and not s.Occupant then
				s:Sit(hum)
				return
			end
		end
	end)

	f.pilotSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not f.pilotSeat.Occupant then
			f.input.pitch, f.input.steer = 0, 0
			if f.state.onGround then f.state.throttle = 0 end
		end
	end)

	-- сразу сажаем владельца пилотом
	local char = owner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		if hum.SeatPart then hum.Sit = false end
		task.defer(function()
			if flights[owner] == f and f.pilotSeat.Parent then f.pilotSeat:Sit(hum) end
		end)
	end
	msg(f, planeName .. " на стоянке. Пассажиры бегут к тебе — подожди их и лети на остров-убежище!")
end

---------------------------------------------------------------- СЕТЕВЫЕ СОБЫТИЯ
local function flightOfPlayer(p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat then
		for _, f in pairs(flights) do
			if seat:IsDescendantOf(f.plane) then return f end
		end
	end
	return nil
end

HangarEvent.OnServerEvent:Connect(function(p, action, name, livery)
	if action == "buy" then
		if typeof(name) ~= "string" or not hangarStore:FindFirstChild(name) then return end
		local d = pdata[p]
		local m = moneyValue(p)
		if not d or not m or d.owned[name] then return end
		local price = priceOf(name)
		if m.Value < price then
			HangarEvent:FireClient(p, "toast", "Не хватает денег: нужно $" .. price)
			return
		end
		m.Value -= price
		d.owned[name] = true
		publishOwned(p)
		HangarEvent:FireClient(p, "toast", name .. " куплен!")
		task.spawn(savePlayer, p)
	elseif action == "fly" then
		if typeof(name) ~= "string" then return end
		local d = pdata[p]
		if not d or not d.owned[name] then
			HangarEvent:FireClient(p, "toast", "Сначала купи этот самолёт")
			return
		end
		local idx = tonumber(livery) or 1
		if not Shared.LIVERIES[idx] then idx = 1 end
		spawnFlight(p, name, idx)
	elseif action == "code" then
		if typeof(name) ~= "string" then return end
		local code = string.upper((string.gsub(name, "%s", "")))
		local d = pdata[p]
		if NUMERIC_CODES_FOR_OWNER and string.match(code, "^%d+$") then
			if IS_STUDIO or p.UserId == game.CreatorId then
				local sum = math.clamp(tonumber(code) or 0, 1, 10000000)
				addMoney(p, sum, "Код владельца")
				task.spawn(savePlayer, p)
			else
				HangarEvent:FireClient(p, "toast", "Коды-суммы работают только у владельца игры")
			end
			return
		end
		local amount = CODES[code]
		if not d or not amount then
			HangarEvent:FireClient(p, "toast", "Такого кода нет")
			return
		end
		if d.used[code] then
			HangarEvent:FireClient(p, "toast", "Этот код ты уже активировал")
			return
		end
		d.used[code] = true
		addMoney(p, amount, "Промокод " .. code)
		HangarEvent:FireClient(p, "toast", ("Код активирован: +$%d"):format(amount))
		task.spawn(savePlayer, p)
	elseif action == "gear" then
		for _, f in pairs(flights) do
			if getPilot(f) == p then
				if not f.hasGear then
					msg(f, "У этой модели шасси не убираются.")
				elseif os.clock() < (f.gearJamUntil or 0) then
					msg(f, "Шасси заклинило! Подожди.")
				elseif f.state.onGround and f.gearDown then
					msg(f, "На земле шасси не убрать — сначала взлети.")
				else
					setGear(f, not f.gearDown)
					msg(f, f.gearDown and "Шасси выпущены." or "Шасси убраны. +12% к скорости.")
				end
				return
			end
		end
	elseif action == "respawn" then
		local f = flights[p]
		if f then spawnFlight(p, f.name, f.livery) end
	elseif action == "leave" then
		destroyFlight(p)
	end
end)

local lastChaos = {}
ChaosEvent.OnServerEvent:Connect(function(p, kind, arg)
	if typeof(kind) ~= "string" then return end
	local now = os.clock()
	if now - (lastChaos[p] or 0) < CFG.CHAOS_COOLDOWN then return end
	lastChaos[p] = now

	-- цель: свой самолёт (если сидишь в нём), иначе — все самолёты в небе
	local targets = {}
	local mine = flightOfPlayer(p) or flights[p]
	if mine and not mine.state.crashed then
		targets = { mine }
	else
		for _, f in pairs(flights) do
			if not f.state.crashed then table.insert(targets, f) end
		end
	end

	if kind == "sound" then
		local allowed = { EngineStart = true, Pilots = true, Stewardess = true, Alarm = true, Tower = true, PullUp = true }
		if typeof(arg) == "string" and allowed[arg] then
			for _, f in ipairs(targets) do playSound(arg, f.core) end
		end
		return
	end
	if kind == "weather" then
		weatherToken += 1
		local tok = weatherToken
		Lighting.ClockTime = 19.2
		Lighting.Brightness = 0.6
		Lighting.FogColor = Color3.fromRGB(90, 95, 105)
		Lighting.FogEnd = 500
		atmo = atmo or Lighting:FindFirstChildOfClass("Atmosphere")
		if atmo then
			if not savedAtmo then savedAtmo = { Density = atmo.Density, Haze = atmo.Haze, Color = atmo.Color } end
			atmo.Density = 0.65
			atmo.Haze = 3
			atmo.Color = Color3.fromRGB(110, 115, 125)
		end
		task.delay(15, function()
			if weatherToken == tok then restoreWeather() end
		end)
		for _, f in ipairs(targets) do
			msg(f, "ГРОЗОВОЙ ФРОНТ! Сильная турбулентность 15 секунд.")
		end
	end
	local handler = CHAOS[kind]
	if not handler then return end
	for _, f in ipairs(targets) do
		if handler(f, arg) and not f.state.crashed then
			f.state.chaosCount += 1
		end
	end
end)

InputEvent.OnServerEvent:Connect(function(p, pitch, steer, throttle)
	if typeof(pitch) ~= "number" or typeof(steer) ~= "number" or typeof(throttle) ~= "number" then return end
	if pitch ~= pitch or steer ~= steer or throttle ~= throttle then return end
	for _, f in pairs(flights) do
		if getPilot(f) == p then
			f.input.pitch = math.clamp(pitch, -1, 1)
			f.input.steer = math.clamp(steer, -1, 1)
			f.state.throttle = math.clamp(throttle, 0, 1)
			return
		end
	end
end)

---------------------------------------------------------------- ФИЗИКА (аркадная)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function setFilter(f)
	local list = { debrisFolder, f.plane }
	local zf = workspace:FindFirstChild("ZombiesLive")
	if zf then table.insert(list, zf) end
	local cf = workspace:FindFirstChild("Civilians")
	if cf then table.insert(list, cf) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	rayParams.FilterDescendantsInstances = list
end

local function groundBelow(pos, fromY)
	local hit = workspace:Raycast(Vector3.new(pos.X, fromY, pos.Z), Vector3.new(0, -3000, 0), rayParams)
	return hit and hit.Position.Y or -math.huge
end

local function hitWalkers(f)
	if f.state.speed < 15 then return end
	local zf = workspace:FindFirstChild("ZombiesLive")
	if not zf then return end
	local r = math.max(10, f.length * 0.45)
	local center = f.core.Position
	for _, z in ipairs(zf:GetChildren()) do
		local h = z:FindFirstChildOfClass("Humanoid")
		local root = z:FindFirstChild("HumanoidRootPart") or z:FindFirstChild("Torso")
		if h and root and h.Health > 0 and (root.Position - center).Magnitude < r then
			h.Health = 0
			root.AssemblyLinearVelocity = f.state.vel * 0.8 + Vector3.new(0, 60, 0)
			addMoney(getPilot(f), CFG.ZOMBIE_REWARD, "Сбит зомби")
			msg(f, "Сбит зомби! +$" .. CFG.ZOMBIE_REWARD)
		end
	end
end

local function stepFlight(f, dt, now)
	local st, perf = f.state, f.perf
	local pitchIn, steerIn = f.input.pitch, f.input.steer
	if now < st.lostControlUntil then
		pitchIn = -1
		steerIn = math.sin(now * 2.5)
	end

	local alive, left, right = engineCounts(f)
	if not f.engineStarted and st.throttle > 0.02 then
		f.engineStarted = true
		playSound("EngineStart", f.core)
	end
	if f.engineSound then
		f.engineSound.Volume = f.engineStarted and (0.25 + st.throttle * 0.75) * (alive / 4) or 0
		f.engineSound.PlaybackSpeed = 0.7 + st.throttle * 0.5 + (st.speed / perf.max) * 0.3
	end

	-- автоматические звуки по ходу полёта
	if st.onGround then
		if st.throttle > 0.05 and st.speed < 3 and f.passengers > 0 and not f.announced then
			-- готовимся к взлёту — объявление стюардессы
			f.announced = true
			playSound("Stewardess", f.core)
		end
		if not f.rollSound and st.throttle > 0.5 and st.speed > perf.takeoff * 0.25 then
			f.rollSound = true
			playSound("Takeoff", f.core)
		end
	else
		f.rollSound = false
		local altM = (st.pos.Y - (st.groundY or 0)) * Shared.ALT
		local vsM = st.vel.Y * Shared.ALT
		-- «PULL UP»: низко и быстро снижаешься
		if altM < 80 and vsM < -12 and now - (f.lastPullUp or 0) > 3 then
			f.lastPullUp = now
			playSound("PullUp", f.core)
		end
		-- переговоры пилотов в спокойном полёте
		if st.airborneTime > 20 and now - (f.lastChatter or 0) > 75 then
			f.lastChatter = now
			playSound("Pilots", f.core)
		end
	end
	local target = st.throttle * perf.max * (alive / 4) * ((f.hasGear and not f.gearDown) and 1.12 or 1)
	local diff = target - st.speed
	local rate = (diff > 0) and perf.accel or perf.accel * 0.6
	st.speed += math.clamp(diff, -rate * dt, rate * dt)
	if not st.onGround then
		st.speed -= math.sin(st.pitch) * CFG.CLIMB_DRAG * dt
	elseif st.throttle < 0.05 then
		st.speed -= perf.accel * 1.6 * dt -- тормоза на земле
	end
	st.speed = math.clamp(st.speed, 0, perf.max * 1.3)

	local targetRoll = 0
	if st.onGround then
		if st.speed >= perf.takeoff then
			st.pitch = math.clamp(st.pitch + pitchIn * perf.pitch * dt, 0, 0.45)
		else
			st.pitch = 0
		end
		st.yaw -= steerIn * 0.6 * dt * math.clamp(st.speed / 15, 0, 1)
	else
		st.pitch = math.clamp(st.pitch + pitchIn * perf.pitch * dt, -1.2, 1.0)
		st.yaw -= steerIn * perf.turn * dt
		st.yaw += (right - left) * 0.06 * dt
		targetRoll = -steerIn * 0.7 + (right - left) * 0.08
		if st.speed < perf.stall then
			st.pitch -= 0.6 * dt
		end
		if now < st.turbulenceUntil then
			st.pitch += math.noise(now * 1.7, 3.1) * 1.2 * dt
			targetRoll += math.noise(now * 2.3, 7.7) * 0.6
		end
	end
	st.roll += (targetRoll - st.roll) * math.min(dt * 3, 1)

	local rot = CFrame.Angles(0, st.yaw, 0) * CFrame.Angles(st.pitch, 0, 0)
	local vel = rot.LookVector * st.speed
	if not st.onGround and st.speed < perf.stall then
		vel += Vector3.new(0, -(perf.stall - st.speed) * 0.8, 0)
	end
	st.vel = vel

	local oldPos = st.pos
	local newPos = oldPos + vel * dt
	local newCF = CFrame.new(newPos) * rot * CFrame.Angles(0, 0, st.roll)

	setFilter(f)
	local gY = groundBelow(newPos, math.max(oldPos.Y, newPos.Y) + 3)
	st.groundY = gY
	if gY == -math.huge and newPos.Y < -300 then
		crash(f, "Упал в пустоту")
		return
	end

	if st.speed > 5 then
		local oldCF = f.plane.PrimaryPart.CFrame
		for _, probe in ipairs(f.probes) do
			local a = oldCF:PointToWorldSpace(probe.offset)
			local b = newCF:PointToWorldSpace(probe.offset)
			local d = b - a
			if d.Magnitude > 0.01 then
				local hit = workspace:Raycast(a, d + d.Unit * 2, rayParams)
				if hit then
					local wall = hit.Normal.Y < 0.7
					local hard = vel.Y < CFG.HARD_LANDING_VY or st.pitch < -0.45
					if wall or hard then
						st.pos = newPos
						local what = hit.Instance.Name
						if hit.Instance == workspace.Terrain then
							what = hit.Material == Enum.Material.Water and "воду" or "гору"
						end
						-- врезался в чужой самолёт — разбиваются оба
						for _, other in pairs(flights) do
							if other ~= f and hit.Instance:IsDescendantOf(other.plane) then
								what = "самолёт " .. other.owner.Name
								crash(other, "В тебя врезался " .. f.owner.Name)
							end
						end
						crash(f, probe.name .. " врезался в " .. what)
						return
					end
				end
			end
		end
	end

	if newPos.Y <= gY then
		if not st.onGround then
			if f.hasGear and not f.gearDown then
				st.pos = newPos
				crash(f, "Посадка без шасси")
				return
			end
			if vel.Y < CFG.HARD_LANDING_VY or st.pitch < -0.45 or math.abs(st.roll) > 0.8 then
				st.pos = newPos
				crash(f, "Жёсткая посадка")
				return
			end
			if not onRunway(newPos) and st.speed > perf.takeoff * 1.8 then
				st.pos = newPos
				crash(f, "Посадка мимо полосы")
				return
			end
			st.onGround = true
			f.hordeAt = os.clock() + CFG.HORDE_FIRST
			f.overrunT = 0
			playSound("Landing", f.core)
			msg(f, "Касание! Сбрось газ (S) и остановись.")
		end
		newPos = Vector3.new(newPos.X, gY, newPos.Z)
		if st.pitch < 0 then st.pitch = 0 end
	elseif st.onGround and newPos.Y > gY + 2 then
		if st.speed >= perf.takeoff * 0.9 then
			st.onGround = false
			msg(f, "Взлёт! Набирай высоту.")
		else
			newPos = Vector3.new(newPos.X, math.max(gY, newPos.Y - 40 * dt), newPos.Z)
		end
	elseif st.onGround then
		newPos = Vector3.new(newPos.X, math.max(gY, newPos.Y), newPos.Z)
	end

	hitWalkers(f)

	if not st.onGround then
		st.airborneTime += dt
		if st.airborneTime > 5 then st.flew = true end
	end

	st.pos = newPos
	f.plane:PivotTo(CFrame.new(newPos) * rot * CFrame.Angles(0, 0, st.roll))
	-- пропеллеры крутит клиент (плавно, каждый кадр); сервер только сообщает, что двигатель запущен
	f.plane:SetAttribute("EngineOn", f.engineStarted == true)

	if st.fireStart and now - st.fireStart > CFG.FIRE_TIME then
		crash(f, "Пожар уничтожил самолёт")
		return
	end

	if st.onGround and st.flew and st.speed < 1.5 then
		st.flew = false
		st.airborneTime = 0
		local pilot = getPilot(f)
		local safe = workspace:FindFirstChild("SafeZone", true)
		local atSafe = safe and (Vector3.new(st.pos.X - safe.Position.X, 0, st.pos.Z - safe.Position.Z)).Magnitude < CFG.SAFE_RADIUS
		local bonus
		local delivered = 0
		if atSafe and f.passengers > 0 then
			delivered = f.passengers
			bonus = delivered * CFG.FARE + st.chaosCount * CFG.CHAOS_BONUS
			f.passengers = 0
			f.announced = false
			f.plane:SetAttribute("Passengers", 0)
			local r = pilot and pilot:FindFirstChild("leaderstats") and pilot.leaderstats:FindFirstChild("Спасено")
			if r then r.Value += delivered end
		else
			bonus = CFG.LANDING_REWARD + st.chaosCount * CFG.CHAOS_BONUS
		end
		addMoney(pilot, bonus, delivered > 0 and ("Спасено пассажиров: " .. delivered) or "Мягкая посадка")
		for _, s in ipairs(f.seats) do
			if s ~= f.pilotSeat and s.Occupant then
				addMoney(Players:GetPlayerFromCharacter(s.Occupant.Parent), CFG.PASSENGER_REWARD, "Долетел пассажиром")
			end
		end
		if st.fireStart then
			st.fireStart = nil
			if f.fireSound then f.fireSound:Destroy() f.fireSound = nil end
			for _, n in ipairs({ "CabinFire", "CabinSmoke" }) do
				local o = f.core:FindFirstChild(n)
				if o then o:Destroy() end
			end
		end
		if delivered > 0 then
			msg(f, ("УБЕЖИЩЕ! Спасено пассажиров: %d. Пилот +$%d. Лети обратно за новыми!"):format(delivered, bonus))
		elseif atSafe then
			msg(f, ("Сел в убежище, но без пассажиров. +$%d. Возвращайся в аэропорт за людьми."):format(bonus))
		else
			msg(f, ("Мягкая посадка! +$%d. Пережито ЧП: %d"):format(bonus, st.chaosCount))
		end
		st.chaosCount = 0
		if pilot then task.spawn(savePlayer, pilot) end
	end
end

local function publish(f)
	local st = f.state
	local alive = engineCounts(f)
	local text
	if st.crashed then
		text = "КРУШЕНИЕ"
	elseif st.onGround then
		text = "НА ЗЕМЛЕ"
	elseif st.speed < f.perf.stall then
		text = "СВАЛИВАНИЕ"
	else
		text = "В ВОЗДУХЕ"
	end
	local gY = st.groundY
	if gY == -math.huge then gY = 0 end
	local pl = f.plane
	pl:SetAttribute("Speed", math.floor(st.speed * Shared.KMH + 0.5))
	pl:SetAttribute("Altitude", math.max(0, math.floor((st.pos.Y - gY) * Shared.ALT)))
	pl:SetAttribute("Throttle", math.floor(st.throttle * 100 + 0.5))
	pl:SetAttribute("Pitch", math.floor(math.deg(st.pitch) * 10) / 10)
	pl:SetAttribute("VSpeed", math.floor(st.vel.Y * Shared.ALT * 10 + 0.5) / 10)
	pl:SetAttribute("State", text)
	pl:SetAttribute("Engines", alive)
	pl:SetAttribute("Flew", st.flew)
	pl:SetAttribute("Gear", not f.hasGear and "NONE" or (f.gearDown and "DOWN" or "UP"))
	pl:SetAttribute("GearJam", os.clock() < (f.gearJamUntil or 0))
	-- садиться можно только в стоящий самолёт
	if f.prompt and f.prompt.Parent then
		f.prompt.Enabled = st.onGround and st.speed < 5 and not st.crashed
	end
end

---------------------------------------------------------------- ПАССАЖИРЫ (API для OutbreakServer)
local api = Instance.new("BindableFunction")
api.Name = "FlyCrashAPI"
api.Parent = ServerStorage
api.OnInvoke = function(action, id)
	if action == "boardable" then
		local list = {}
		for owner, f in pairs(flights) do
			local st = f.state
			if not st.crashed and st.onGround and st.speed < 8 and f.passengers < f.capacity and f.core.Parent then
				table.insert(list, { id = owner.UserId, pos = f.core.Position, radius = f.length * 0.5 + 10 })
			end
		end
		return list
	elseif action == "groundPlanes" then
		local list = {}
		for _, f in pairs(flights) do
			local st = f.state
			if not st.crashed and st.onGround and f.core.Parent then
				table.insert(list, { pos = f.core.Position, radius = f.length * 0.5 })
			end
		end
		return list
	elseif action == "board" then
		for owner, f in pairs(flights) do
			if owner.UserId == id and f.passengers < f.capacity and not f.state.crashed and f.state.onGround then
				f.passengers += 1
				f.plane:SetAttribute("Passengers", f.passengers)
				if f.passengers >= f.capacity and not f.announced then
					f.announced = true
					playSound("Stewardess", f.core)
				end
				if f.passengers >= f.capacity then
					msg(f, ("Салон полон: %d / %d! Взлетай и лети на остров-убежище (восток)."):format(f.passengers, f.capacity))
				else
					msg(f, ("Пассажир на борту: %d / %d"):format(f.passengers, f.capacity))
				end
				return true
			end
		end
		return false
	end
	return nil
end

local hordeEvent = Instance.new("BindableEvent")
hordeEvent.Name = "FlyCrashHorde"
hordeEvent.Parent = ServerStorage

local function atSafeZone(pos)
	local safe = workspace:FindFirstChild("SafeZone", true)
	return safe and Vector3.new(pos.X - safe.Position.X, 0, pos.Z - safe.Position.Z).Magnitude < CFG.SAFE_RADIUS
end

-- зомби у стоящего самолёта съедают пассажиров, а толпой — захватывают самолёт
local function zombiesAttackPlanes()
	local zf = workspace:FindFirstChild("ZombiesLive")
	if not zf then return end
	for _, f in pairs(flights) do
		local st = f.state
		if f.passengers > 0 and not st.crashed and st.speed < 15 and f.core.Parent then
			local c = f.core.Position
			local r = f.length * 0.5 + 6
			local eaten = 0
			for _, z in ipairs(zf:GetChildren()) do
				local root = z:FindFirstChild("HumanoidRootPart") or z:FindFirstChild("Torso")
				local h = z:FindFirstChildOfClass("Humanoid")
				if root and h and h.Health > 0 and Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z).Magnitude < r then
					eaten += 1
				end
			end
			f.zombiesNear = eaten
			if eaten > 0 then
				eaten = math.min(eaten, f.passengers)
				f.passengers -= eaten
				f.plane:SetAttribute("Passengers", f.passengers)
				msg(f, ("ЗОМБИ ВОРВАЛИСЬ В САЛОН! Потеряно пассажиров: %d. Взлетай!"):format(eaten))
			end
		end
	end
end

-- фон в аэропорту: переговоры диспетчеров из башни
task.spawn(function()
	local ap = workspace:FindFirstChild("Airport")
	local tower = ap and ap:FindFirstChild("Tower")
	if tower and tower:IsA("BasePart") then
		local s = playSound("Tower", tower, true)
		if s then
			s.Volume = 0.5
			s.RollOffMaxDistance = 600
		end
	end
end)

---------------------------------------------------------------- ИГРОКИ
Players.PlayerAdded:Connect(loadPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, p)
end
Players.PlayerRemoving:Connect(function(p)
	destroyFlight(p)
	savePlayer(p)
	pdata[p] = nil
	lastChaos[p] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		savePlayer(p)
	end
end)
task.spawn(function()
	while true do
		task.wait(120)
		for _, p in ipairs(Players:GetPlayers()) do
			savePlayer(p)
		end
	end
end)

---------------------------------------------------------------- ГЛАВНЫЙ ЦИКЛ
-- орды и захват самолёта
local function hordesAndOverrun()
	local zf = workspace:FindFirstChild("ZombiesLive")
	local now = os.clock()
	for _, f in pairs(flights) do
		local st = f.state
		if not st.crashed and f.core.Parent then
			-- сколько зомби у самолёта (даже если пассажиров нет)
			local near = 0
			if zf then
				local c = f.core.Position
				local r = f.length * 0.5 + 8
				for _, z in ipairs(zf:GetChildren()) do
					local root = z:FindFirstChild("HumanoidRootPart") or z:FindFirstChild("Torso")
					local h = z:FindFirstChildOfClass("Humanoid")
					if root and h and h.Health > 0 and Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z).Magnitude < r then
						near += 1
					end
				end
			end
			f.plane:SetAttribute("ZombiesNear", near)
			if st.onGround and st.speed < 15 and not atSafeZone(st.pos) then
				if near >= CFG.OVERRUN_COUNT then
					f.overrunT += 1
					msg(f, ("ЗОМБИ ЛОМЯТСЯ В САМОЛЁТ! Взлетай! (%d/%d)"):format(f.overrunT, CFG.OVERRUN_TIME))
					if f.overrunT >= CFG.OVERRUN_TIME then
						crash(f, "Зомби захватили самолёт")
					end
				else
					f.overrunT = 0
				end
				if now >= (f.hordeAt or math.huge) then
					f.hordeAt = now + CFG.HORDE_EVERY
					hordeEvent:Fire(f.core.Position, CFG.HORDE_SIZE)
					playSound("Alarm", f.core)
					msg(f, "ОРДА ИДЁТ! Толпа зомби бежит к самолёту — взлетай, пока не поздно!")
				end
				f.plane:SetAttribute("HordeIn", math.max(0, math.ceil((f.hordeAt or now) - now)))
			else
				f.overrunT = 0
				f.plane:SetAttribute("HordeIn", -1)
			end
		end
	end
end

local eatT = 0
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local now = os.clock()
	updateHazards(dt, now)
	eatT += dt
	if eatT >= 1 then
		eatT = 0
		zombiesAttackPlanes()
		hordesAndOverrun()
	end
	for owner, f in pairs(flights) do
		if not owner.Parent then
			destroyFlight(owner)
		else
			if not f.state.crashed then
				stepFlight(f, dt, now)
			end
			f.publishT += dt
			if f.publishT >= 0.1 and f.plane.Parent then
				f.publishT = 0
				publish(f)
			end
		end
	end
end)
