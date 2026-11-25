-- FlyCrash: клиент — ангар-витрина, приборы, подсказки, пульт хаоса, управление
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Net = ReplicatedStorage:WaitForChild("FlyCrash")
local ChaosEvent = Net:WaitForChild("Chaos")
local InputEvent = Net:WaitForChild("PilotInput")
local HangarEvent = Net:WaitForChild("Hangar")
local Shared = require(ReplicatedStorage:WaitForChild("FlyCrashShared"))
local hangarRS = ReplicatedStorage:WaitForChild("FlyCrashHangar")
local flightsFolder = workspace:WaitForChild("Flights")

local C = {
	bg = Color3.fromRGB(13, 19, 27),
	panel = Color3.fromRGB(24, 31, 41),
	line = Color3.fromRGB(55, 70, 86),
	text = Color3.fromRGB(236, 240, 245),
	dim = Color3.fromRGB(140, 152, 166),
	accent = Color3.fromRGB(238, 104, 64),
	green = Color3.fromRGB(110, 220, 150),
	blue = Color3.fromRGB(110, 190, 230),
	red = Color3.fromRGB(255, 80, 70),
	yellow = Color3.fromRGB(255, 210, 80),
	white = Color3.new(1, 1, 1),
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o)
end
local function stroke(o, color, th)
	make("UIStroke", { Color = color or C.line, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function label(parent, props)
	local base = {
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14,
		TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do base[k] = v end
	return make("TextLabel", base, parent)
end

local gui = make("ScreenGui", {
	Name = "FlyCrashUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local flightUI = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 }, gui)
local hangarUI = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false }, gui)

local function toast(text)
	local t = label(gui, {
		Size = UDim2.new(0, 420, 0, 44), Position = UDim2.new(0.5, -210, 0, 120),
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.05, Font = Enum.Font.GothamBold,
		TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Text = text, ZIndex = 50,
	})
	corner(t, 8)
	stroke(t, C.yellow, 2)
	task.delay(2.5, function() t:Destroy() end)
end

local function money()
	local ls = player:FindFirstChild("leaderstats")
	local m = ls and ls:FindFirstChild("Деньги")
	return m and m.Value or 0
end

local function owned(name)
	for _, n in ipairs(string.split(player:GetAttribute("Owned") or "", "|")) do
		if n == name then return true end
	end
	return false
end

---------------------------------------------------------------- ПРИБОРЫ
local hud = make("Frame", {
	BackgroundTransparency = 1, Size = UDim2.new(0, 660, 0, 56), Position = UDim2.new(0.5, -330, 0, 44),
}, flightUI)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
}, hud)
local statOrder = 0
local function stat(title, width)
	statOrder += 1
	local f = make("Frame", {
		Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, LayoutOrder = statOrder,
	}, hud)
	corner(f)
	label(f, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -14, 0, 14), TextSize = 11, TextColor3 = C.dim, Text = title })
	return label(f, { Position = UDim2.new(0, 10, 0, 20), Size = UDim2.new(1, -14, 0, 30), Font = Enum.Font.GothamBold, TextSize = 20, Text = "0" })
end
local speedL = stat("СКОРОСТЬ", 110)
local altL = stat("ВЫСОТА", 95)
local thrL = stat("ГАЗ", 75)
local pitchL = stat("ТАНГАЖ", 80)
local vsL = stat("ВЕРТ. СКОРОСТЬ", 115)
local stateL = stat("СОСТОЯНИЕ", 150)
hud.Visible = false

-- задание и пассажиры
local mission = make("Frame", {
	Size = UDim2.new(0, 300, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, -310, 0, 92),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = false,
}, flightUI)
corner(mission, 8)
make("UIStroke", { Color = C.green, Thickness = 2 }, mission)
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, mission)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, mission)
label(mission, { Size = UDim2.new(1, 0, 0, 14), TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.green, Text = "ЭВАКУАЦИЯ", LayoutOrder = 1 })
local paxL = label(mission, { Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Font = Enum.Font.GothamBlack, Text = "0 / 0", LayoutOrder = 2 })
local goalL = label(mission, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamMedium, LayoutOrder = 3 })
local distL = label(mission, { Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.yellow, LayoutOrder = 4 })

-- метка убежища в мире (видна сквозь всё)
task.spawn(function()
	local safe = workspace:FindFirstChild("SafeZone", true)
	local t0 = os.clock()
	while not safe and os.clock() - t0 < 30 do
		task.wait(1)
		safe = workspace:FindFirstChild("SafeZone", true)
	end
	if not safe then return end
	local bb = make("BillboardGui", {
		Adornee = safe, Size = UDim2.new(0, 220, 0, 54), AlwaysOnTop = true, MaxDistance = 100000,
		StudsOffsetWorldSpace = Vector3.new(0, 60, 0), Name = "SafeMarker",
	}, gui)
	local t = label(bb, {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(20, 70, 40),
		Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "УБЕЖИЩЕ",
	})
	corner(t, 8)
	RunService.Heartbeat:Connect(function()
		local d = (camera.CFrame.Position - safe.Position).Magnitude * Shared.REAL_M / 1000 * 3
		t.Text = ("УБЕЖИЩЕ  %.1f км"):format(d)
		bb.Enabled = not hangarUI.Visible
	end)
end)

local msgBox = make("Frame", {
	Size = UDim2.new(0, 360, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 10, 0, 110),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
}, flightUI)
corner(msgBox)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, msgBox)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, msgBox)
label(msgBox, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.blue, Text = "СИСТЕМА" })
local msgL = label(msgBox, {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
	Font = Enum.Font.Gotham, TextSize = 15, TextWrapped = true, Text = "Нажми САМОЛЁТЫ, чтобы выбрать борт.",
}, msgBox)
player:GetAttributeChangedSignal("FCMessageT"):Connect(function()
	msgL.Text = player:GetAttribute("FCMessage") or ""
end)

-- подсказка по шагам
local coach = make("Frame", {
	Visible = false, Size = UDim2.new(0, 520, 0, 92), Position = UDim2.new(0.5, -260, 0, 108),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0,
}, flightUI)
corner(coach, 8)
stroke(coach, C.yellow, 2)
local coachStep = label(coach, { Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 16), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.yellow })
local coachText = label(coach, { Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -28, 0, 40), Font = Enum.Font.GothamBold, TextSize = 19, TextWrapped = true })
local barBg = make("Frame", { Position = UDim2.new(0, 14, 1, -18), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = C.line, BorderSizePixel = 0 }, coach)
corner(barBg, 4)
local bar = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.green, BorderSizePixel = 0 }, barBg)
corner(bar, 4)
local function setCoach(step, text, progress)
	coach.Visible = true
	coachStep.Text = step
	coachText.Text = text
	barBg.Visible = progress ~= nil
	if progress then bar.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0) end
end

-- панель клавиш (как в настоящих играх)
local controls = make("Frame", {
	Visible = false, Size = UDim2.new(0, 210, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.new(0, 10, 1, -330), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
}, flightUI)
corner(controls, 8)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, controls)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, controls)
label(controls, { Size = UDim2.new(1, 0, 0, 16), TextSize = 11, TextColor3 = C.dim, Font = Enum.Font.GothamBold, Text = "УПРАВЛЕНИЕ", LayoutOrder = 0 })
for i, row in ipairs({
	{ "W", "Газ больше" }, { "S", "Газ меньше" }, { "A D", "Поворот" },
	{ "↑ ↓", "Нос вверх / вниз" }, { "V", "Камера" }, { "ПКМ", "Осмотреться" }, { "R", "Заново" }, { "F", "Выйти" }, { "H", "Ангар" },
}) do
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i }, controls)
	local k = label(r, {
		Size = UDim2.new(0, 44, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = C.text, TextColor3 = C.bg,
		Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
		Text = row[1] == "↑ ↓" and "Стрел." or row[1],
	})
	corner(k, 4)
	label(r, { Position = UDim2.new(0, 54, 0, 0), Size = UDim2.new(1, -54, 1, 0), TextSize = 13, Text = row[2] })
end

---------------------------------------------------------------- ВЕРХНИЕ КНОПКИ
local menuBtn = make("TextButton", {
	Text = "САМОЛЁТЫ", Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(1, -250, 0, 44),
	BackgroundColor3 = C.blue, TextColor3 = C.bg, Font = Enum.Font.GothamBold, TextSize = 15,
}, flightUI)
corner(menuBtn)
local toggle = make("TextButton", {
	Text = "ХАОС", Size = UDim2.new(0, 110, 0, 36), Position = UDim2.new(1, -120, 0, 44),
	BackgroundColor3 = C.accent, TextColor3 = C.white, Font = Enum.Font.GothamBold, TextSize = 15,
}, flightUI)
corner(toggle)

---------------------------------------------------------------- ПУЛЬТ ХАОСА
local panel = make("ScrollingFrame", {
	Size = UDim2.new(0, 236, 0.5, 0), Position = UDim2.new(1, -246, 0, 86),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0,
	ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Visible = false,
}, flightUI)
corner(panel)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, panel)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
toggle.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

local order = 0
local function nextOrder() order += 1 return order end
local function section(title)
	label(panel, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.dim, Text = title })
	local grid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() }, panel)
	make("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 38), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	return grid
end
local function pbutton(grid, text, color, onClick)
	local b = make("TextButton", {
		Text = text, BackgroundColor3 = C.panel, TextColor3 = color, Font = Enum.Font.GothamBold,
		TextSize = 13, LayoutOrder = nextOrder(), TextWrapped = true,
	}, grid)
	corner(b, 4)
	stroke(b)
	b.MouseButton1Click:Connect(onClick)
end
label(panel, {
	Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nextOrder(), TextSize = 11, TextColor3 = C.dim, TextWrapped = true,
	Text = "Сидишь в самолёте — бьёт по тебе. Стоишь на земле — по всем самолётам.",
})
local g1 = section("01  ОТКАЗ ДВИГАТЕЛЕЙ")
for i = 1, 4 do
	pbutton(g1, "Двигатель " .. i, C.accent, function() ChaosEvent:FireServer("engine", i) end)
end
local g2 = section("02  АВАРИЙНЫЕ СОБЫТИЯ")
for _, e in ipairs({ { "Пожар", "fire" }, { "Падение", "fall" }, { "Взрыв", "explosion" }, { "Гуси", "geese" }, { "Дрон", "drone" }, { "Встречный", "plane" }, { "Гроза", "weather" } }) do
	pbutton(g2, e[1], C.accent, function() ChaosEvent:FireServer(e[2]) end)
end
local g3 = section("03  СВЯЗЬ И ЗВУКИ")
for _, e in ipairs({ { "Запуск двиг.", "EngineStart" }, { "Пилоты", "Pilots" }, { "Стюардесса", "Stewardess" }, { "Тревога", "Alarm" } }) do
	pbutton(g3, e[1], C.blue, function() ChaosEvent:FireServer("sound", e[2]) end)
end

---------------------------------------------------------------- КНОПКИ ПИЛОТА (для телефона)
local pilotUI = make("Frame", {
	Visible = false, BackgroundTransparency = 1, Size = UDim2.new(0, 230, 0, 230), Position = UDim2.new(1, -240, 1, -330),
}, flightUI)
local function padButton(text, x, y, w, h, color)
	local b = make("TextButton", {
		Text = text, Size = UDim2.new(0, w, 0, h), Position = UDim2.new(0, x, 0, y),
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, TextColor3 = color,
		Font = Enum.Font.GothamBold, TextSize = 16, TextWrapped = true,
	}, pilotUI)
	corner(b)
	stroke(b)
	return b
end
local autoBtn = padButton("АВТОВЗЛЁТ", 0, 0, 112, 46, C.yellow)
local landBtn = padButton("АВТО-\nПОСАДКА", 118, 0, 112, 46, C.green)
local camBtn = make("TextButton", {
	Text = "КАМЕРА", Size = UDim2.new(0, 230, 0, 40), Position = UDim2.new(0, 0, 0, -48),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, TextColor3 = C.blue,
	Font = Enum.Font.GothamBold, TextSize = 15,
}, pilotUI)
corner(camBtn)
stroke(camBtn)
local upBtn = padButton("ВВЕРХ", 0, 56, 110, 80, C.blue)
local thrUpBtn = padButton("ГАЗ +", 120, 56, 110, 80, C.green)
local downBtn = padButton("ВНИЗ", 0, 146, 110, 80, C.blue)
local thrDownBtn = padButton("ГАЗ −", 120, 146, 110, 80, C.green)

local held = {}
local function bindHold(btn, name)
	local function isPress(io)
		return io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1
	end
	btn.InputBegan:Connect(function(io) if isPress(io) then held[name] = true end end)
	btn.InputEnded:Connect(function(io) if isPress(io) then held[name] = false end end)
	btn.MouseLeave:Connect(function() held[name] = false end)
end
bindHold(upBtn, "up")
bindHold(downBtn, "down")
bindHold(thrUpBtn, "thrUp")
bindHold(thrDownBtn, "thrDown")
local auto = false
local autoLand = false
autoBtn.MouseButton1Click:Connect(function() auto = not auto autoLand = false end)
landBtn.MouseButton1Click:Connect(function() autoLand = not autoLand auto = false end)

---------------------------------------------------------------- АНГАР
local names = {}
local sel = 1
local livery = 1
local preview = nil
local previewAngle = 0
local hangarOpen = false

-- детали витрины лежат внутри модели здания ангара — ищем вглубь
local function findDeep(name)
	local o = workspace:FindFirstChild(name, true)
	local t0 = os.clock()
	while not o do
		if os.clock() - t0 > 5 then warn("FlyCrash: жду деталь " .. name) t0 = os.clock() end
		task.wait(0.3)
		o = workspace:FindFirstChild(name, true)
	end
	return o
end
local displayPart = findDeep("HangarDisplay")
local camPart = findDeep("HangarCamera")

-- заголовок
label(hangarUI, { Position = UDim2.new(0.5, -150, 0, 50), Size = UDim2.new(0, 300, 0, 30), Font = Enum.Font.GothamBlack, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Text = "АНГАР" })
local countL = label(hangarUI, { Position = UDim2.new(0.5, -150, 0, 80), Size = UDim2.new(0, 300, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center })

-- паспорт самолёта слева
local info = make("Frame", {
	Position = UDim2.new(0, 24, 0, 60), Size = UDim2.new(0, 340, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0,
}, hangarUI)
corner(info, 8)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14) }, info)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, info)
local catL = label(info, { Size = UDim2.new(1, 0, 0, 14), TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.dim, LayoutOrder = 1 })
local nameL = label(info, { Size = UDim2.new(1, 0, 0, 32), TextSize = 28, Font = Enum.Font.GothamBlack, LayoutOrder = 2, TextTruncate = Enum.TextTruncate.AtEnd })
local descL = label(info, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, TextColor3 = C.dim, TextWrapped = true, LayoutOrder = 3, Font = Enum.Font.Gotham })
local statBars = {}
local function statRow(title, order)
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order }, info)
	label(r, { Size = UDim2.new(0.6, 0, 0, 14), TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.dim, Text = title })
	local v = label(r, { Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 14), TextSize = 12, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Right })
	local bg = make("Frame", { Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.line, BorderSizePixel = 0 }, r)
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 }, bg)
	statBars[title] = { v = v, fill = fill }
end
statRow("МАКС. СКОРОСТЬ", 4)
statRow("РАЗМАХ КРЫЛА", 5)
statRow("ДЛИНА", 6)
statRow("ВЫСОТА", 7)
local bottomRow = make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 8 }, info)
label(bottomRow, { Size = UDim2.new(0.5, 0, 0, 14), TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.dim, Text = "ДВИГАТЕЛИ" })
local engL = label(bottomRow, { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(0.5, 0, 0, 18), TextSize = 13, Font = Enum.Font.GothamBold })
label(bottomRow, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 14), TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.dim, Text = "ПЕРВЫЙ ПОЛЁТ" })
local yearL = label(bottomRow, { Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.new(0.5, 0, 0, 18), TextSize = 13, Font = Enum.Font.GothamBold })

local function setBar(title, text, frac)
	statBars[title].v.Text = text
	statBars[title].fill.Size = UDim2.new(math.clamp(frac, 0.02, 1), 0, 1, 0)
end

-- стрелки
local function arrow(text, xScale, xOff)
	local b = make("TextButton", {
		Text = text, Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(xScale, xOff, 0.42, 0),
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, TextColor3 = C.text, Font = Enum.Font.GothamBlack, TextSize = 26,
	}, hangarUI)
	corner(b, 28)
	return b
end
local leftBtn = arrow("<", 0, 380)
local rightBtn = arrow(">", 1, -80)

-- ливреи
local liveryBox = make("Frame", {
	Size = UDim2.new(0, 640, 0, 92), Position = UDim2.new(0.5, -320, 1, -250),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0,
}, hangarUI)
corner(liveryBox, 8)
local liveryTitle = label(liveryBox, { Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.dim })
local liveryRow = make("Frame", { Position = UDim2.new(0, 10, 0, 26), Size = UDim2.new(1, -20, 0, 58), BackgroundTransparency = 1 }, liveryBox)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, liveryRow)
local liveryButtons = {}

-- лента самолётов
local strip = make("ScrollingFrame", {
	Size = UDim2.new(1, -260, 0, 124), Position = UDim2.new(0, 24, 1, -142),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
}, hangarUI)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, strip)
local cards = {}

-- деньги + кнопка ЛЕТЕТЬ
local moneyBox = label(hangarUI, {
	Size = UDim2.new(0, 200, 0, 48), Position = UDim2.new(1, -224, 1, -210), BackgroundTransparency = 0.1,
	BackgroundColor3 = C.bg, Font = Enum.Font.GothamBlack, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Text = "$0",
})
corner(moneyBox, 8)
local flyBtn = make("TextButton", {
	Size = UDim2.new(0, 200, 0, 124), Position = UDim2.new(1, -224, 1, -142),
	BackgroundColor3 = C.white, TextColor3 = C.bg, Font = Enum.Font.GothamBlack, TextSize = 30, Text = "ЛЕТЕТЬ",
}, hangarUI)
corner(flyBtn, 8)
local flyHint = label(flyBtn, { Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 20), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center, Text = "Enter" })

-- промокоды
local codesBtn = make("TextButton", {
	Text = "КОДЫ", Size = UDim2.new(0, 200, 0, 40), Position = UDim2.new(1, -224, 1, -258),
	BackgroundColor3 = C.panel, TextColor3 = C.yellow, Font = Enum.Font.GothamBold, TextSize = 16,
}, hangarUI)
corner(codesBtn, 8)
stroke(codesBtn, C.yellow, 1)
local codesPanel = make("Frame", {
	Visible = false, Size = UDim2.new(0, 380, 0, 170), Position = UDim2.new(0.5, -190, 0.5, -85),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 30,
}, hangarUI)
corner(codesPanel, 10)
stroke(codesPanel, C.yellow, 2)
label(codesPanel, { Position = UDim2.new(0, 16, 0, 12), Size = UDim2.new(1, -32, 0, 24), Font = Enum.Font.GothamBlack, TextSize = 20, Text = "ПРОМОКОД", ZIndex = 31 })
local codeBox = make("TextBox", {
	Position = UDim2.new(0, 16, 0, 48), Size = UDim2.new(1, -32, 0, 44), BackgroundColor3 = C.panel,
	TextColor3 = C.text, PlaceholderText = "Введи код, например 666", PlaceholderColor3 = C.dim,
	Font = Enum.Font.GothamBold, TextSize = 20, Text = "", ClearTextOnFocus = false, ZIndex = 31,
}, codesPanel)
corner(codeBox, 6)
local redeemBtn = make("TextButton", {
	Position = UDim2.new(0, 16, 1, -60), Size = UDim2.new(0.6, -20, 0, 44), BackgroundColor3 = C.yellow,
	TextColor3 = C.bg, Font = Enum.Font.GothamBlack, TextSize = 16, Text = "АКТИВИРОВАТЬ", ZIndex = 31,
}, codesPanel)
corner(redeemBtn, 6)
local codesClose = make("TextButton", {
	Position = UDim2.new(0.6, 4, 1, -60), Size = UDim2.new(0.4, -20, 0, 44), BackgroundColor3 = C.panel,
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 15, Text = "ЗАКРЫТЬ", ZIndex = 31,
}, codesPanel)
corner(codesClose, 6)
local function redeem()
	if codeBox.Text ~= "" then
		HangarEvent:FireServer("code", codeBox.Text)
		codeBox.Text = ""
		codesPanel.Visible = false
	end
end
codesBtn.MouseButton1Click:Connect(function()
	codesPanel.Visible = not codesPanel.Visible
	if codesPanel.Visible then codeBox:CaptureFocus() end
end)
redeemBtn.MouseButton1Click:Connect(redeem)
codesClose.MouseButton1Click:Connect(function() codesPanel.Visible = false end)
codeBox.FocusLost:Connect(function(enter) if enter then redeem() end end)

local closeBtn = make("TextButton", {
	Text = "НАЗАД", Size = UDim2.new(0, 110, 0, 36), Position = UDim2.new(1, -134, 0, 50),
	BackgroundColor3 = C.panel, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 14,
}, hangarUI)
corner(closeBtn)

local function curTemplate()
	return hangarRS:FindFirstChild(names[sel] or "")
end

local function buildPreview()
	if preview then preview:Destroy() preview = nil end
	local t = curTemplate()
	if not t then return end
	preview = t:Clone()
	Shared.applyLivery(preview, livery)
	for _, d in ipairs(preview:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false d.CanQuery = false end
	end
	preview.PrimaryPart = preview:FindFirstChild("Root")
	preview.Parent = workspace
end

local function refreshInfo()
	local t = curTemplate()
	if not t then return end
	local name = names[sel]
	countL.Text = ("САМОЛЁТ %d / %d"):format(sel, #names)
	catL.Text = t:GetAttribute("FCCategory") or ""
	nameL.Text = name
	descL.Text = t:GetAttribute("FCDescription") or ""
	local top = t:GetAttribute("FCTopSpeed") or 0
	local span = (t:GetAttribute("FCSpan") or 0) * Shared.REAL_M
	local len = (t:GetAttribute("FCLength") or 0) * Shared.REAL_M
	local h = (t:GetAttribute("FCHeight") or 0) * Shared.REAL_M
	setBar("МАКС. СКОРОСТЬ", top .. " км/ч", top / 1200)
	setBar("РАЗМАХ КРЫЛА", ("%.1f м"):format(span), span / 70)
	setBar("ДЛИНА", ("%.1f м"):format(len), len / 75)
	setBar("ВЫСОТА", ("%.1f м"):format(h), h / 20)
	engL.Text = tostring(t:GetAttribute("FCEngines") or "—")
	yearL.Text = tostring(t:GetAttribute("FCFirstFlight") or "—")
	liveryTitle.Text = "ЛИВРЕЯ   " .. Shared.LIVERIES[livery].name
	for i, b in ipairs(liveryButtons) do
		b.stroke.Color = (i == livery) and C.white or C.line
		b.stroke.Thickness = (i == livery) and 2 or 1
	end
	for i, c in ipairs(cards) do
		c.stroke.Color = (i == sel) and C.white or C.line
		c.stroke.Thickness = (i == sel) and 2 or 1
		c.badge.Text = owned(c.name) and "ЕСТЬ" or ("$" .. (c.price or 0))
		c.badge.TextColor3 = owned(c.name) and C.green or C.yellow
	end
	local price = t:GetAttribute("FCPrice") or 0
	if owned(name) then
		flyBtn.Text = "ЛЕТЕТЬ"
		flyBtn.BackgroundColor3 = C.white
	else
		flyBtn.Text = "КУПИТЬ\n$" .. price
		flyBtn.BackgroundColor3 = money() >= price and C.yellow or Color3.fromRGB(120, 120, 120)
	end
	moneyBox.Text = "$" .. money()
end

local function select(i)
	if #names == 0 then return end
	sel = ((i - 1) % #names) + 1
	buildPreview()
	refreshInfo()
	local c = cards[sel]
	if c then
		strip.CanvasPosition = Vector2.new(math.max(0, c.frame.AbsolutePosition.X - strip.AbsolutePosition.X + strip.CanvasPosition.X - 200), 0)
	end
end

local function buildLiveries()
	for _, b in ipairs(liveryButtons) do b.frame:Destroy() end
	liveryButtons = {}
	for i, L in ipairs(Shared.LIVERIES) do
		local b = make("TextButton", { Size = UDim2.new(0, 96, 1, 0), BackgroundColor3 = C.panel, Text = "", LayoutOrder = i }, liveryRow)
		corner(b, 6)
		local s = make("UIStroke", { Color = C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local ca, cb = L.a, L.b
		if not ca then
			local t = curTemplate()
			ca = t and t:GetAttribute("FCPrimary") or C.text
			cb = t and t:GetAttribute("FCSecondary") or C.dim
		end
		local sw = make("Frame", { Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 0, 24), BackgroundColor3 = ca, BorderSizePixel = 0 }, b)
		corner(sw, 4)
		make("Frame", { Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), BackgroundColor3 = cb, BorderSizePixel = 0 }, sw)
		label(b, { Position = UDim2.new(0, 6, 1, -20), Size = UDim2.new(1, -12, 0, 16), TextSize = 11, TextColor3 = C.dim, Text = L.name, TextTruncate = Enum.TextTruncate.AtEnd })
		b.MouseButton1Click:Connect(function()
			livery = i
			buildPreview()
			refreshInfo()
		end)
		table.insert(liveryButtons, { frame = b, stroke = s })
	end
end

local function buildCards()
	for _, c in ipairs(cards) do c.frame:Destroy() end
	cards = {}
	names = {}
	for _, n in ipairs(string.split(Net:GetAttribute("Planes") or "", "|")) do
		if n ~= "" and hangarRS:FindFirstChild(n) then table.insert(names, n) end
	end
	for i, name in ipairs(names) do
		local t = hangarRS:FindFirstChild(name)
		local b = make("TextButton", { Size = UDim2.new(0, 170, 1, -8), BackgroundColor3 = C.panel, Text = "", LayoutOrder = i }, strip)
		corner(b, 6)
		local s = make("UIStroke", { Color = C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local vp = make("ViewportFrame", {
			Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0, 66), BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(180, 180, 190), LightColor = C.white, LightDirection = Vector3.new(-1, -2, -1),
		}, b)
		local clone = t:Clone()
		clone.Parent = vp
		local cf, size = clone:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 35
		cam.Parent = vp
		vp.CurrentCamera = cam
		local dist = size.Magnitude * 1.05
		cam.CFrame = CFrame.lookAt(cf.Position + (CFrame.Angles(0, math.rad(35), 0) * Vector3.new(0, dist * 0.45, dist)), cf.Position)
		local num = label(b, { Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(0, 20, 0, 20), BackgroundTransparency = 0, BackgroundColor3 = C.text, TextColor3 = C.bg, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Text = tostring(i) })
		corner(num, 4)
		local badge = label(b, { Position = UDim2.new(1, -76, 0, 6), Size = UDim2.new(0, 70, 0, 20), BackgroundTransparency = 0.2, BackgroundColor3 = C.bg, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center })
		corner(badge, 4)
		label(b, { Position = UDim2.new(0, 8, 1, -42), Size = UDim2.new(1, -16, 0, 18), Font = Enum.Font.GothamBold, TextSize = 14, Text = name, TextTruncate = Enum.TextTruncate.AtEnd })
		label(b, { Position = UDim2.new(0, 8, 1, -22), Size = UDim2.new(1, -16, 0, 14), TextSize = 10, TextColor3 = C.dim, Text = t:GetAttribute("FCCategory") or "", TextTruncate = Enum.TextTruncate.AtEnd })
		b.MouseButton1Click:Connect(function() select(i) end)
		table.insert(cards, { frame = b, stroke = s, badge = badge, name = name, price = t:GetAttribute("FCPrice") })
	end
	if sel > #names then sel = 1 end
end

local function openHangar()
	hangarOpen = true
	hangarUI.Visible = true
	flightUI.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	buildCards()
	buildLiveries()
	select(sel)
end

local function closeHangar()
	hangarOpen = false
	hangarUI.Visible = false
	flightUI.Visible = true
	if preview then preview:Destroy() preview = nil end
	camera.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
end

local function flyOrBuy()
	local name = names[sel]
	if not name then return end
	if owned(name) then
		HangarEvent:FireServer("fly", name, livery)
		closeHangar()
	else
		HangarEvent:FireServer("buy", name)
	end
end

flyBtn.MouseButton1Click:Connect(flyOrBuy)
leftBtn.MouseButton1Click:Connect(function() select(sel - 1) end)
rightBtn.MouseButton1Click:Connect(function() select(sel + 1) end)
closeBtn.MouseButton1Click:Connect(closeHangar)
menuBtn.MouseButton1Click:Connect(openHangar)
player:GetAttributeChangedSignal("Owned"):Connect(function() if hangarOpen then refreshInfo() end end)
Net:GetAttributeChangedSignal("Planes"):Connect(function() if hangarOpen then buildCards() select(sel) end end)
-- модели самолётов могут дойти до клиента позже списка — перестраиваем ленту
local rebuildQueued = false
hangarRS.ChildAdded:Connect(function()
	if rebuildQueued then return end
	rebuildQueued = true
	task.delay(0.5, function()
		rebuildQueued = false
		if hangarOpen then buildCards() buildLiveries() select(sel) end
	end)
end)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 30)
	local m = ls and ls:WaitForChild("Деньги", 10)
	if m then m.Changed:Connect(function() if hangarOpen then refreshInfo() end end) end
end)

HangarEvent.OnClientEvent:Connect(function(action, text)
	if action == "toast" then
		toast(text)
	elseif action == "open" then
		openHangar()
	elseif action == "crashed" then
		toast("КРУШЕНИЕ: " .. tostring(text))
	end
end)

---------------------------------------------------------------- КЛАВИШИ
UserInputService.InputBegan:Connect(function(io, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local k = io.KeyCode
	if hangarOpen then
		if k == Enum.KeyCode.Left or k == Enum.KeyCode.A then
			select(sel - 1)
		elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.D then
			select(sel + 1)
		elseif k == Enum.KeyCode.Return then
			flyOrBuy()
		elseif k == Enum.KeyCode.Escape or k == Enum.KeyCode.H then
			closeHangar()
		else
			local n = k.Value - Enum.KeyCode.One.Value + 1
			if n >= 1 and n <= 9 and n <= #names then select(n) end
		end
		return
	end
	if k == Enum.KeyCode.H then
		openHangar()
	elseif k == Enum.KeyCode.R then
		HangarEvent:FireServer("respawn")
	elseif k == Enum.KeyCode.F then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then hum.Sit = false end
	end
end)

---------------------------------------------------------------- ЦИКЛ
local throttle = 0
local wasPilot = false
local sendTimer = 0
local airTime = 0
---------------------------------------------------------------- КАМЕРА В ПОЛЁТЕ
-- V — сменить вид, правая кнопка мыши — осмотреться, колесо — приблизить/отдалить
local CAM_MODES = { "СЗАДИ", "ДАЛЬНИЙ ВИД", "КАБИНА", "СБОКУ" }
local camMode = 1
local orbitYaw, orbitPitch, zoom = 0, 0, 0
local camCF = nil
local inPlaneCam = false
local rmb = false

local function nextCam()
	camMode = camMode % #CAM_MODES + 1
	orbitYaw, orbitPitch, zoom = 0, 0, 0
	camCF = nil
	toast("Камера: " .. CAM_MODES[camMode])
end
camBtn.MouseButton1Click:Connect(nextCam)

UserInputService.InputBegan:Connect(function(io, processed)
	if processed or hangarUI.Visible then return end
	if io.KeyCode == Enum.KeyCode.V and inPlaneCam then
		nextCam()
	elseif io.UserInputType == Enum.UserInputType.MouseButton2 and inPlaneCam then
		rmb = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)
UserInputService.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton2 then
		rmb = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)
UserInputService.InputChanged:Connect(function(io, processed)
	if not inPlaneCam then return end
	if io.UserInputType == Enum.UserInputType.MouseMovement and rmb then
		orbitYaw -= io.Delta.X * 0.006
		orbitPitch = math.clamp(orbitPitch - io.Delta.Y * 0.004, -0.9, 0.9)
	elseif io.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		zoom = math.clamp(zoom - io.Position.Z * 6, -40, 400)
	elseif io.UserInputType == Enum.UserInputType.Touch and not processed and io.Delta.Magnitude > 0 then
		-- на телефоне: свайп по экрану крутит камеру
		orbitYaw -= io.Delta.X * 0.008
		orbitPitch = math.clamp(orbitPitch - io.Delta.Y * 0.005, -0.9, 0.9)
	end
end)

local camRay = RaycastParams.new()
camRay.FilterType = Enum.RaycastFilterType.Exclude

local function updatePlaneCam(pl, dt)
	local pivot = pl:GetPivot()
	local len = pl:GetAttribute("FCLength") or 50
	local h = pl:GetAttribute("FCHeight") or 12
	local speed = pl:GetAttribute("Speed") or 0
	local center = (pivot * CFrame.new(0, h * 0.5, 0)).Position
	local look = pivot.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit

	-- если не крутим камеру мышью — плавно возвращаем её за хвост
	if not rmb and camMode ~= 3 then
		orbitYaw *= math.max(0, 1 - dt * 1.5)
		orbitPitch *= math.max(0, 1 - dt * 1.5)
	end

	if camMode == 3 then
		local eye = pivot * CFrame.new(0, h * 0.62, -len * 0.4)
		camera.CFrame = eye * CFrame.Angles(orbitPitch, orbitYaw, 0)
		camera.FieldOfView = 80
		camCF = nil
		return
	end

	local dist, up, side = len * 1.3 + 12, 0.2, 0
	if camMode == 2 then dist, up = len * 2.6 + 30, 0.32 end
	if camMode == 4 then side, up = math.rad(90), 0.12 end
	dist = math.max(8, dist + zoom)
	local base = CFrame.lookAt(center, center + flat)
	local boom = base * CFrame.Angles(0, orbitYaw + side, 0) * CFrame.Angles(-up + orbitPitch, 0, 0)
	local pos = (boom * CFrame.new(0, 0, dist)).Position
	-- не уходим под землю и сквозь здания
	camRay.FilterDescendantsInstances = { pl, player.Character }
	local hit = workspace:Raycast(center, pos - center, camRay)
	if hit then pos = hit.Position + (center - hit.Position).Unit * 2 end
	local aim = center + flat * len * 0.35
	local desired = CFrame.lookAt(pos, aim)
	camCF = camCF and camCF:Lerp(desired, math.min(1, dt * 7)) or desired
	camera.CFrame = camCF
	camera.FieldOfView = 70 + math.clamp(speed / 60, 0, 14)
end

local stateColors = { ["НА ЗЕМЛЕ"] = C.green, ["В ВОЗДУХЕ"] = C.blue, ["СВАЛИВАНИЕ"] = C.accent, ["КРУШЕНИЕ"] = C.red }

local function key(k) return UserInputService:IsKeyDown(k) end
local function pad(k) return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, k) end

local function myPlane(seat)
	if seat then
		local a = seat
		while a and a.Parent ~= flightsFolder do a = a.Parent end
		if a then return a end
	end
	return flightsFolder:FindFirstChild(player.Name)
end

---------------------------------------------------------------- ПРИБОРЫ ПОСАДКИ
local landPanel = make("Frame", {
	Visible = false, Size = UDim2.new(0, 420, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.new(0.5, -210, 0, 108), BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0,
}, flightUI)
corner(landPanel, 8)
make("UIStroke", { Color = C.green, Thickness = 2 }, landPanel)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, landPanel)
make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, landPanel)
local landTitle = label(landPanel, { Size = UDim2.new(1, 0, 0, 16), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.green, Text = "ЗАХОД НА ПОСАДКУ", LayoutOrder = 0 })
local function landRow(title, order)
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order }, landPanel)
	label(r, { Size = UDim2.new(0, 110, 1, 0), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.dim, Text = title })
	local v = label(r, { Position = UDim2.new(0, 110, 0, 0), Size = UDim2.new(0, 120, 1, 0), TextSize = 19, Font = Enum.Font.GothamBlack })
	local need = label(r, { Position = UDim2.new(0, 232, 0, 0), Size = UDim2.new(1, -232, 1, 0), TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = C.dim })
	return v, need
end
local lSpeed, lSpeedNeed = landRow("СКОРОСТЬ", 1)
local lVS, lVSNeed = landRow("СНИЖЕНИЕ", 2)
local lRw, lRwNeed = landRow("ПОЛОСА", 3)
local landHint = label(landPanel, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Font = Enum.Font.GothamBold, TextWrapped = true, TextColor3 = C.yellow, LayoutOrder = 4 })

local runwaySegs = {}
task.spawn(function()
	local rw = workspace:WaitForChild("Runway", 30)
	if rw then
		for _, p in ipairs(rw:GetChildren()) do
			if p:IsA("BasePart") then table.insert(runwaySegs, p) end
		end
	end
end)
-- где ближайшая полоса: смещение от осевой, расстояние, угол к оси
local function runwayInfo(pos, look)
	local best, bd = nil, nil
	for _, p in ipairs(runwaySegs) do
		local lp = p.CFrame:PointToObjectSpace(pos)
		local dz = math.max(0, math.abs(lp.Z) - p.Size.Z / 2)
		local d = math.sqrt(lp.X * lp.X + dz * dz)
		if not bd or d < bd then best, bd = p, d end
	end
	if not best then return nil end
	local lp = best.CFrame:PointToObjectSpace(pos)
	local lf = best.CFrame:VectorToObjectSpace(look)
	local dir = (lf.Z < 0) and -1 or 1
	return { x = lp.X, dist = bd, dir = dir, ang = math.atan2(dir * lf.X, math.abs(lf.Z)), halfW = best.Size.X / 2 }
end

local function updateLanding(pl, st, spd, alt, vs)
	local takeoff = pl:GetAttribute("TakeoffKmh") or 175
	local safe = Net:GetAttribute("SafeVS") or -20
	local show = autoLand or (st ~= "НА ЗЕМЛЕ" and alt < 150 and airTime > 6 and (throttle < 0.6 or vs < -3))
	landPanel.Visible = show
	if not show then return false end
	landTitle.Text = autoLand and "АВТОПОСАДКА — самолёт садится сам" or "ЗАХОД НА ПОСАДКУ"
	local lo, hi = math.floor(takeoff * 1.1), math.floor(takeoff * 1.6)
	lSpeed.Text = spd .. " км/ч"
	lSpeedNeed.Text = ("нужно %d–%d"):format(lo, hi)
	lSpeed.TextColor3 = (spd < takeoff * 0.95) and C.red or ((spd >= lo and spd <= hi) and C.green or C.yellow)
	lVS.Text = ("%.1f м/с"):format(vs)
	lVSNeed.Text = ("не быстрее %d м/с"):format(math.abs(safe))
	lVS.TextColor3 = (vs < safe) and C.red or ((vs < safe * 0.5) and C.yellow or C.green)
	local info = (#runwaySegs > 0) and runwayInfo(pl:GetPivot().Position, pl:GetPivot().LookVector) or nil
	local hint
	if info then
		lRw.Text = ("%.1f км"):format(info.dist * Shared.REAL_M / 1000 * 3)
		if math.abs(info.ang) > math.rad(30) then
			lRwNeed.Text = "развернись вдоль полосы"
			lRw.TextColor3 = C.red
		elseif math.abs(info.x) < info.halfW * 0.6 then
			lRwNeed.Text = "по центру — отлично"
			lRw.TextColor3 = C.green
		else
			local right = info.x * info.dir > 0
			lRwNeed.Text = (right and "полоса правее на " or "полоса левее на ") .. math.floor(math.abs(info.x) * Shared.REAL_M * 3) .. " м"
			lRw.TextColor3 = C.yellow
		end
	end
	if vs < safe then
		hint = "СЛИШКОМ БЫСТРО ПАДАЕШЬ! Стрелка вверх — подними нос."
	elseif spd < takeoff * 0.95 then
		hint = "Мало скорости — добавь газ (W), иначе свалишься."
	elseif spd > hi then
		hint = "Слишком быстро — сбрось газ (S)."
	elseif alt < 12 then
		hint = "Почти земля: чуть нос вверх, газ на 0 (S) — и тормози."
	else
		hint = "Держи цифры зелёными и плавно снижайся к полосе."
	end
	landHint.Text = autoLand and "Любая кнопка управления — отключить." or hint
	return true
end

local function updateCoach(pl, st, spd, alt)
	local takeoff = pl:GetAttribute("TakeoffKmh") or 175
	local flew = pl:GetAttribute("Flew") == true
	if st == "КРУШЕНИЕ" then
		setCoach("КРУШЕНИЕ", "Бывает! Сейчас откроется ангар.", nil)
	elseif auto then
		setCoach("АВТОВЗЛЁТ", ("Самолёт взлетает сам... %d / %d км/ч. Любая кнопка — отменить."):format(spd, takeoff), spd / takeoff)
	elseif st == "НА ЗЕМЛЕ" and flew then
		setCoach("ПОСАДКА", "Отлично! Держи S — сбрось газ до 0 и остановись.", nil)
	elseif st == "НА ЗЕМЛЕ" and spd < takeoff then
		if throttle < 0.95 then
			setCoach("ШАГ 1 из 3", "Зажми W — дай полный газ. Или нажми АВТОВЗЛЁТ.", throttle)
		else
			setCoach("ШАГ 2 из 3", ("Разгон по полосе... %d / %d км/ч"):format(spd, takeoff), spd / takeoff)
		end
	elseif st == "НА ЗЕМЛЕ" then
		setCoach("ШАГ 3 из 3", "СКОРОСТЬ ЕСТЬ! Жми СТРЕЛКУ ВВЕРХ — взлетай!", 1)
	elseif st == "СВАЛИВАНИЕ" then
		setCoach("ВНИМАНИЕ", "Мало скорости! Газ W до упора и опусти нос (стрелка вниз).", nil)
	elseif alt < 40 then
		setCoach("НАБОР ВЫСОТЫ", ("Держи нос вверх, не убирай газ. Высота %d м"):format(alt), alt / 40)
	elseif airTime < 8 then
		setCoach("ЛЕТИМ!", "A/D — поворот, стрелки — нос. Для посадки: меньше газа и плавно вниз.", nil)
	elseif airTime < 25 then
		setCoach("КАК СЕСТЬ", "Выйди на полосу, сбрось газ (S) — появятся приборы посадки. Или жми АВТОПОСАДКА.", nil)
	else
		coach.Visible = false
	end
end

RunService.RenderStepped:Connect(function(dt)
	-- ангар: вращаем самолёт и ставим камеру
	if hangarOpen then
		local t = curTemplate()
		previewAngle += dt * 0.25
		if preview and t then
			local base = displayPart.CFrame * CFrame.new(0, displayPart.Size.Y / 2, 0)
			preview:PivotTo(base * CFrame.Angles(0, previewAngle, 0))
			local size = math.max(t:GetAttribute("FCLength") or 40, t:GetAttribute("FCSpan") or 40)
			local h = t:GetAttribute("FCHeight") or 10
			local target = base.Position + Vector3.new(0, h * 0.45, 0)
			local dir = (camPart.Position - displayPart.Position).Unit
			camera.CFrame = CFrame.lookAt(target + dir * (size * 0.95 + 12), target)
		else
			camera.CFrame = camPart.CFrame
		end
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local pl = myPlane(seat)
	local isPilot = seat ~= nil and seat:IsA("VehicleSeat") and seat:GetAttribute("FCPilot") == true

	hud.Visible = pl ~= nil
	local seatedInPlane = seat ~= nil and seat:IsDescendantOf(flightsFolder) and pl ~= nil
	-- кто сидит в самолёте, тому подсказки «Сесть пассажиром» не нужны
	ProximityPromptService.Enabled = not seatedInPlane
	if seatedInPlane then
		if not inPlaneCam or camera.CameraType ~= Enum.CameraType.Scriptable then
			inPlaneCam = true
			camCF = nil
			camera.CameraType = Enum.CameraType.Scriptable
		end
		updatePlaneCam(pl, dt)
	elseif inPlaneCam then
		inPlaneCam = false
		rmb = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		if hum then camera.CameraSubject = hum end
	end
	if pl then
		local spd = pl:GetAttribute("Speed") or 0
		local alt = pl:GetAttribute("Altitude") or 0
		local st = pl:GetAttribute("State") or "НА ЗЕМЛЕ"
		speedL.Text = spd .. " км/ч"
		altL.Text = alt .. " м"
		pitchL.Text = tostring(pl:GetAttribute("Pitch") or 0) .. "°"
		stateL.Text = st
		stateL.TextColor3 = stateColors[st] or C.text
		if not isPilot then thrL.Text = tostring(pl:GetAttribute("Throttle") or 0) .. "%" end
		local pax, cap = pl:GetAttribute("Passengers") or 0, pl:GetAttribute("Capacity") or 0
		mission.Visible = true
		paxL.Text = ("%d / %d пассажиров"):format(pax, cap)
		paxL.TextColor3 = pax >= cap and C.green or C.text
		local safe = workspace:FindFirstChild("SafeZone", true)
		local dist = safe and (Vector3.new(safe.Position.X, 0, safe.Position.Z) - Vector3.new(pl:GetPivot().Position.X, 0, pl:GetPivot().Position.Z)).Magnitude or 0
		local km = dist * Shared.REAL_M / 1000 * 3
		if dist < 900 then
			goalL.Text = pax > 0 and "Ты в убежище! Сядь и остановись — пассажиры выйдут и заплатят." or "Ты в убежище. Лети обратно в аэропорт за новыми пассажирами."
		elseif pax == 0 then
			goalL.Text = (st == "НА ЗЕМЛЕ") and "Стой на месте — пассажиры бегут к самолёту. Не подпускай зомби!" or "Вернись в аэропорт и сядь — там ждут пассажиры."
		elseif pax < cap and st == "НА ЗЕМЛЕ" then
			goalL.Text = "Пассажиры садятся. Ждать ещё или взлетать? Зомби рядом!"
		else
			goalL.Text = "Лети на остров-убежище на востоке (зелёный маяк) и сядь там."
		end
		distL.Text = ("До убежища: %.1f км"):format(km)
	else
		mission.Visible = false
	end

	if isPilot ~= wasPilot then
		wasPilot = isPilot
		pilotUI.Visible = isPilot and UserInputService.TouchEnabled
		controls.Visible = isPilot and not UserInputService.TouchEnabled
		coach.Visible = false
		auto = false
		if isPilot then
			throttle = (pl and pl:GetAttribute("Throttle") or 0) / 100
			local camDist = seat:GetAttribute("FCCam") or 45
			task.spawn(function()
				player.CameraMinZoomDistance = camDist
				task.wait(0.3)
				player.CameraMinZoomDistance = 0.5
			end)
		end
	end
	if not isPilot or not pl then
		if not isPilot then coach.Visible = false end
		return
	end
	-- на ПК тоже показываем кнопку автовзлёта
	pilotUI.Visible = true
	upBtn.Visible = UserInputService.TouchEnabled
	downBtn.Visible = UserInputService.TouchEnabled
	thrUpBtn.Visible = UserInputService.TouchEnabled
	thrDownBtn.Visible = UserInputService.TouchEnabled

	local st = pl:GetAttribute("State") or "НА ЗЕМЛЕ"
	local spd = pl:GetAttribute("Speed") or 0
	local alt = pl:GetAttribute("Altitude") or 0
	local pitchDeg = pl:GetAttribute("Pitch") or 0
	local vs = pl:GetAttribute("VSpeed") or 0
	vsL.Text = ("%+.1f м/с"):format(vs)
	vsL.TextColor3 = (vs < (Net:GetAttribute("SafeVS") or -20)) and C.red or C.text
	if st == "В ВОЗДУХЕ" or st == "СВАЛИВАНИЕ" then airTime += dt else airTime = 0 end

	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local arrows = key(Enum.KeyCode.Up) or key(Enum.KeyCode.Down)
	local pitch = 0
	if held.up or (not typing and key(Enum.KeyCode.Up)) or pad(Enum.KeyCode.DPadUp) then
		pitch = 1
	elseif held.down or (not typing and key(Enum.KeyCode.Down)) or pad(Enum.KeyCode.DPadDown) then
		pitch = -1
	end
	local thrIn = 0
	if held.thrUp or (not typing and key(Enum.KeyCode.W)) then
		thrIn = 1
	elseif held.thrDown or (not typing and key(Enum.KeyCode.S)) then
		thrIn = -1
	elseif not arrows then
		thrIn = seat.ThrottleFloat
	end
	local steer = seat.SteerFloat
	if not typing then
		if key(Enum.KeyCode.D) or key(Enum.KeyCode.Right) then
			steer = 1
		elseif key(Enum.KeyCode.A) or key(Enum.KeyCode.Left) then
			steer = -1
		end
	end

	if auto then
		if pitch ~= 0 or thrIn ~= 0 or st == "КРУШЕНИЕ" then
			auto = false
		else
			throttle = 1
			local takeoff = pl:GetAttribute("TakeoffKmh") or 175
			if spd >= takeoff - 2 or st ~= "НА ЗЕМЛЕ" then
				pitch = (pitchDeg < 12) and 1 or 0
			end
			if alt >= 60 then auto = false end
		end
	end
	autoBtn.Text = auto and "ВЗЛЁТ: ВКЛ" or "АВТОВЗЛЁТ"

	-- автопосадка: держит скорость захода, плавное снижение, выравнивание на полосу, тормоз
	if autoLand then
		local userThr = held.thrUp or held.thrDown or (not typing and (key(Enum.KeyCode.W) or key(Enum.KeyCode.S)))
		if pitch ~= 0 or userThr or st == "КРУШЕНИЕ" then
			autoLand = false
		elseif st == "НА ЗЕМЛЕ" then
			throttle = 0
			pitch = 0
			if spd < 2 then
				autoLand = false
				toast("Посадка завершена!")
			end
		else
			local takeoff = pl:GetAttribute("TakeoffKmh") or 175
			local tgt = takeoff * 1.3
			throttle = math.clamp(throttle + math.clamp((tgt - spd) / tgt, -1, 1) * 0.8 * dt, 0.05, 1)
			local spStuds = math.max(spd / Shared.KMH, 1)
			local tvs = (alt > 100) and -12 or ((alt > 40) and -6 or ((alt > 12) and -3 or -1.2))
			-- глиссада: если полоса впереди, снижаемся так, чтобы коснуться у её начала
			local g = runwayInfo(pl:GetPivot().Position, pl:GetPivot().LookVector)
			if g and g.dist > 60 and math.abs(g.ang) < math.rad(40) and alt > 12 then
				local timeTo = (g.dist / spStuds)
				tvs = math.clamp(-alt / math.max(timeTo, 1), -12, -1.5)
			end
			local dp = math.deg(math.asin(math.clamp((tvs / Shared.ALT) / spStuds, -0.3, 0.3))) + (tvs - vs) * 0.6
			dp = math.clamp(dp, -12, 12)
			pitch = math.clamp((dp - pitchDeg) * 0.35, -1, 1)
			local info = runwayInfo(pl:GetPivot().Position, pl:GetPivot().LookVector)
			if info and info.dist < 6000 then
				local desired = math.clamp(-info.dir * info.x * 0.004, -0.6, 0.6)
				steer = math.clamp((info.ang - desired) * 2.5, -1, 1)
			end
		end
	end
	landBtn.Text = autoLand and "ПОСАДКА: ВКЛ" or "АВТО-\nПОСАДКА"

	throttle = math.clamp(throttle + thrIn * 0.5 * dt, 0, 1)
	thrL.Text = math.floor(throttle * 100 + 0.5) .. "%"
	if updateLanding(pl, st, spd, alt, vs) then
		coach.Visible = false
	else
		updateCoach(pl, st, spd, alt)
	end

	sendTimer += dt
	if sendTimer >= 1 / 15 then
		sendTimer = 0
		InputEvent:FireServer(pitch, steer, throttle)
	end
end)

-- бег: обычная скорость 26, с Shift — 46
RunService.Heartbeat:Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and not hum.SeatPart then
		local sprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		hum.WalkSpeed = sprint and 46 or 26
	end
end)

-- при входе в игру сразу открываем ангар
task.wait(1)
openHangar()
