-- FlyCrash: ЭВАКУАЦИЯ. Пассажиры-NPC и зомби.
-- Пассажиры толпятся у терминала и бегут к любому стоящему самолёту игрока, где есть места.
-- Зомби охотятся на игроков и пассажиров. Укушенный пассажир сам становится зомби.
-- Свои модели зомби можно положить в папку Workspace > Zombies.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CFG = {
	ZOMBIES = 14,              -- сколько зомби одновременно
	CIVILIANS = 30,            -- сколько пассажиров ждут эвакуации
	AGGRO = 130,               -- с какого расстояния зомби замечают жертву
	ZOMBIE_WALK = 8,
	ZOMBIE_RUN = 15,
	CIV_RUN = 20,              -- пассажиры бегают быстрее зомби, но не намного
	DAMAGE = 15,               -- урон игроку за укус
	HIT_COOLDOWN = 1,
	ZOMBIE_RESPAWN = 8,
	CIV_RESPAWN = 5,
	BOARD_SEARCH = 700,        -- с какого расстояния пассажир видит самолёт
	ZOMBIE_AREA = { x = { 450, 1100 }, z = { -900, 900 } },   -- поля к востоку от аэропорта
	HORDE_RUN = 17,            -- орда бежит к самолёту быстрее обычных зомби
	MAX_ZOMBIES = 70,          -- больше зомби одновременно не бывает
	HORDE_LIFETIME = 150,      -- зомби из орды исчезают через N секунд
	CIV_AREA = { x = { -250, -216 }, z = { -120, 960 } },     -- посадочный перрон у рулёжки (где стоят самолёты)
}

local ANIM = {
	R15 = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766388" },
	R6 = { walk = "rbxassetid://180426354", idle = "rbxassetid://180435571" },
}

local zombiesLive = Instance.new("Folder")
zombiesLive.Name = "ZombiesLive"
zombiesLive.Parent = workspace
local civFolder = Instance.new("Folder")
civFolder.Name = "Civilians"
civFolder.Parent = workspace
local store = Instance.new("Folder")
store.Name = "ZombieTemplates"
store.Parent = ServerStorage

local api = ServerStorage:WaitForChild("FlyCrashAPI", 30)

---------------------------------------------------------------- ШАБЛОНЫ ЗОМБИ
local function prepTemplate(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") and d.Name ~= "Animate" then d:Destroy() end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
	m.Parent = store
end
local candidates = {}
local folder = workspace:FindFirstChild("Zombies")
if folder then
	for _, m in ipairs(folder:GetChildren()) do table.insert(candidates, m) end
end
for _, m in ipairs(workspace:GetChildren()) do
	local n = string.lower(m.Name)
	if m:IsA("Model") and (string.find(n, "zombie", 1, true) or string.find(m.Name, "омби", 1, true)) then
		table.insert(candidates, m)
	end
end
for _, m in ipairs(candidates) do
	if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then prepTemplate(m) end
end
if folder then folder:Destroy() end

local function rig(skin, torso, legs, name)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = torso
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and m then
		m.Name = name
		return m
	end
	warn("FlyCrash: не удалось создать персонажа: " .. tostring(m))
	return nil
end

if #store:GetChildren() == 0 then
	local z = rig(Color3.fromRGB(95, 145, 75), Color3.fromRGB(105, 85, 70), Color3.fromRGB(55, 60, 80), "Зомби")
	if z then z.Parent = store end
end

-- несколько вариантов пассажиров (разная одежда)
local civTemplates = {}
local SKINS = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(235, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(120, 85, 60) }
local SHIRTS = { Color3.fromRGB(40, 90, 180), Color3.fromRGB(200, 50, 50), Color3.fromRGB(240, 240, 240), Color3.fromRGB(235, 120, 40), Color3.fromRGB(240, 180, 40), Color3.fromRGB(120, 60, 160) }
local PANTS = { Color3.fromRGB(40, 45, 60), Color3.fromRGB(90, 70, 50), Color3.fromRGB(30, 30, 35), Color3.fromRGB(70, 90, 130) }
for i = 1, 6 do
	local c = rig(SKINS[(i - 1) % #SKINS + 1], SHIRTS[i], PANTS[(i - 1) % #PANTS + 1], "Пассажир")
	if c then
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayName = "Пассажир" end
		table.insert(civTemplates, c)
	end
end

---------------------------------------------------------------- АНИМАЦИЯ
local function setupAnimation(m, hum)
	if m:FindFirstChild("Animate") then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local set = hum.RigType == Enum.HumanoidRigType.R15 and ANIM.R15 or ANIM.R6
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		return ok and track or nil
	end
	local walk, idle = load(set.walk), load(set.idle)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	hum.Running:Connect(function(speed)
		if not walk then return end
		if speed > 0.5 then
			if not walk.IsPlaying then walk:Play() end
			walk:AdjustSpeed(speed / 14)
		elseif walk.IsPlaying then
			walk:Stop()
		end
	end)
end

---------------------------------------------------------------- ОБЩЕЕ
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { zombiesLive, civFolder }

local function groundPos(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), params)
	return Vector3.new(x, (hit and hit.Position.Y or 0) + 4, z)
end

local function randIn(area)
	return groundPos(math.random(area.x[1], area.x[2]), math.random(area.z[1], area.z[2]))
end

local function rootOf(m)
	return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
end

local spawnZombie, spawnCivilian -- объявлены ниже

---------------------------------------------------------------- ЗОМБИ
local function nearestPrey(pos)
	local best, bestD = nil, CFG.AGGRO
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 and not h.SeatPart then
			local d = (r.Position - pos).Magnitude
			if d < bestD then best, bestD = { hum = h, root = r }, d end
		end
	end
	for _, c in ipairs(civFolder:GetChildren()) do
		local h = c:FindFirstChildOfClass("Humanoid")
		local r = rootOf(c)
		if h and r and h.Health > 0 then
			local d = (r.Position - pos).Magnitude
			if d < bestD then best, bestD = { hum = h, root = r, civ = c }, d end
		end
	end
	return best, bestD
end

local planeCache, planeCacheT = {}, 0
local function groundPlanes()
	if os.clock() - planeCacheT > 0.5 and api then
		planeCacheT = os.clock()
		local ok, list = pcall(function() return api:Invoke("groundPlanes") end)
		planeCache = (ok and list) or {}
	end
	return planeCache
end

local function nearestPlane(pos, maxD)
	local best, bd = nil, maxD
	for _, pl in ipairs(groundPlanes()) do
		local d = Vector3.new(pl.pos.X - pos.X, 0, pl.pos.Z - pos.Z).Magnitude
		if d < bd then best, bd = pl, d end
	end
	return best, bd
end

local function zombieBrain(m, hum, root, rusher)
	local lastHit, nextWander, stuckT = 0, 0, 0
	local lastPos = root.Position
	while m.Parent and hum.Health > 0 do
		local now = os.clock()
		local prey, dist = nearestPrey(root.Position)
		-- орда сначала бежит к самолёту; обычные зомби идут к нему, если рядом нет людей
		local plane, pd = nearestPlane(root.Position, rusher and 1500 or 450)
		if plane and (rusher or not prey) and not (prey and dist < 12) then
			hum.WalkSpeed = rusher and CFG.HORDE_RUN or CFG.ZOMBIE_RUN
			hum:MoveTo(Vector3.new(plane.pos.X, root.Position.Y, plane.pos.Z))
			if pd < plane.radius + 10 and math.random() < 0.3 then
				hum.Jump = true -- колотят по самолёту
			end
			prey = nil
		elseif prey then
			hum.WalkSpeed = CFG.ZOMBIE_RUN
			hum:MoveTo(prey.root.Position)
			if dist < 5 and now - lastHit > CFG.HIT_COOLDOWN then
				lastHit = now
				if prey.civ then
					-- заражение: пассажир превращается в зомби
					local pos = prey.root.Position
					prey.civ:Destroy()
					task.delay(CFG.CIV_RESPAWN, spawnCivilian)
					task.spawn(spawnZombie, pos, true)
				else
					prey.hum:TakeDamage(CFG.DAMAGE)
				end
			end
		elseif now > nextWander then
			nextWander = now + math.random(3, 6)
			hum.WalkSpeed = CFG.ZOMBIE_WALK
			hum:MoveTo(root.Position + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40)))
		end
		local moved = (root.Position - lastPos).Magnitude
		if prey and moved < 0.5 then
			stuckT += 0.25
		else
			stuckT = 0
		end
		if stuckT > 1 then
			hum.Jump = true
			stuckT = 0
		end
		lastPos = root.Position
		task.wait(0.25)
	end
end

local zombieCount = 0
spawnZombie = function(atPos, infected, rusher)
	local templates = store:GetChildren()
	if #templates == 0 or #zombiesLive:GetChildren() >= CFG.MAX_ZOMBIES then return end
	local m = templates[math.random(#templates)]:Clone()
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = rootOf(m)
	if not hum or not root then
		m:Destroy()
		return
	end
	local pos = atPos or randIn(CFG.ZOMBIE_AREA)
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = CFG.ZOMBIE_WALK
	m.Parent = zombiesLive
	pcall(function() root:SetNetworkOwner(nil) end)
	setupAnimation(m, hum)
	if not infected then zombieCount += 1 end
	hum.Died:Connect(function()
		task.delay(4, function() m:Destroy() end)
		-- обычные зомби возрождаются; «заражённые» — нет (их становится больше только от укусов)
		if not infected then
			zombieCount -= 1
			task.delay(CFG.ZOMBIE_RESPAWN, function()
				if zombieCount < CFG.ZOMBIES then spawnZombie() end
			end)
		end
	end)
	if rusher then
		task.delay(CFG.HORDE_LIFETIME, function()
			if m.Parent and hum.Health > 0 then m:Destroy() end
		end)
	end
	task.spawn(zombieBrain, m, hum, root, rusher)
end

-- ОРДА: толпа зомби появляется кольцом вокруг самолёта и бежит к нему
local hordeEvent = ServerStorage:WaitForChild("FlyCrashHorde", 30)
if hordeEvent then
	hordeEvent.Event:Connect(function(pos, count)
		for i = 1, count do
			local ang = math.random() * math.pi * 2
			local r = math.random(160, 240)
			local p = groundPos(pos.X + math.cos(ang) * r, pos.Z + math.sin(ang) * r)
			task.spawn(spawnZombie, p, true, true)
			if i % 4 == 0 then task.wait(0.1) end
		end
	end)
end

---------------------------------------------------------------- ПАССАЖИРЫ
local function nearestZombie(pos, radius)
	local best, bestD = nil, radius
	for _, z in ipairs(zombiesLive:GetChildren()) do
		local h = z:FindFirstChildOfClass("Humanoid")
		local r = rootOf(z)
		if h and r and h.Health > 0 then
			local d = (r.Position - pos).Magnitude
			if d < bestD then best, bestD = r, d end
		end
	end
	return best, bestD
end

local function civBrain(m, hum, root)
	local nextWander = 0
	while m.Parent and hum.Health > 0 do
		local now = os.clock()
		local pos = root.Position
		-- ищем ближайший самолёт со свободными местами
		local best, bestD = nil, CFG.BOARD_SEARCH
		if api then
			local ok, list = pcall(function() return api:Invoke("boardable") end)
			if ok and list then
				for _, pl in ipairs(list) do
					local d = Vector3.new(pl.pos.X - pos.X, 0, pl.pos.Z - pos.Z).Magnitude
					if d < bestD then best, bestD = pl, d end
				end
			end
		end
		local z = nearestZombie(pos, 60)
		if best then
			hum.WalkSpeed = CFG.CIV_RUN
			hum:MoveTo(Vector3.new(best.pos.X, pos.Y, best.pos.Z))
			if bestD < best.radius then
				local ok, boarded = pcall(function() return api:Invoke("board", best.id) end)
				if ok and boarded then
					m:Destroy()
					task.delay(CFG.CIV_RESPAWN, spawnCivilian)
					return
				end
			end
		elseif z then
			hum.WalkSpeed = CFG.CIV_RUN
			local away = pos - z.Position
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
			hum:MoveTo(pos + away.Unit * 40)
		elseif now > nextWander then
			nextWander = now + math.random(3, 7)
			hum.WalkSpeed = 8
			-- гуляем только в пределах посадочного перрона
			local a = CFG.CIV_AREA
			local tx = math.clamp(pos.X + math.random(-20, 20), a.x[1], a.x[2])
			local tz = math.clamp(pos.Z + math.random(-30, 30), a.z[1], a.z[2])
			hum:MoveTo(Vector3.new(tx, pos.Y, tz))
		end
		task.wait(0.4)
	end
end

spawnCivilian = function()
	if #civTemplates == 0 or #civFolder:GetChildren() >= CFG.CIVILIANS then return end
	local m = civTemplates[math.random(#civTemplates)]:Clone()
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = rootOf(m)
	if not hum or not root then
		m:Destroy()
		return
	end
	m:PivotTo(CFrame.new(randIn(CFG.CIV_AREA)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	hum.WalkSpeed = 8
	m.Parent = civFolder
	pcall(function() root:SetNetworkOwner(nil) end)
	setupAnimation(m, hum)
	hum.Died:Connect(function()
		task.delay(3, function() m:Destroy() end)
		task.delay(CFG.CIV_RESPAWN, spawnCivilian)
	end)
	task.spawn(civBrain, m, hum, root)
end

---------------------------------------------------------------- СТАРТ
local t0 = os.clock()
while not workspace:GetAttribute("WorldReady") and os.clock() - t0 < 60 do
	task.wait(0.5)
end
for _ = 1, CFG.CIVILIANS do
	spawnCivilian()
	task.wait(0.1)
end
for _ = 1, CFG.ZOMBIES do
	spawnZombie()
	task.wait(0.2)
end
