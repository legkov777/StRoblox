import math, random, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(HERE)
def src(p): return os.path.join(ROOT, 'src', p)
from xml.sax.saxutils import escape

random.seed(67)
ref_n = [0]
def ref():
    ref_n[0] += 1
    return "RBX%08X" % ref_n[0]

def color(r, g, b):
    return (0xFF << 24) | (r << 16) | (g << 8) | b

MAT = {"plastic": 256, "smooth": 272, "neon": 288, "wood": 512, "concrete": 816,
       "metal": 1088, "grass": 1280, "glass": 1568, "sand": 1296}

def cf_xml(x, y, z, roty=0.0):
    c, s = math.cos(math.radians(roty)), math.sin(math.radians(roty))
    # rotation about Y
    R = [c, 0, s, 0, 1, 0, -s, 0, c]
    names = ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    rs = "".join("<%s>%s</%s>" % (n, round(v, 6), n) for n, v in zip(names, R))
    return '<CoordinateFrame name="CFrame"><X>%s</X><Y>%s</Y><Z>%s</Z>%s</CoordinateFrame>' % (x, y, z, rs)

def part(name, size, pos, rgb, mat="smooth", cls="Part", shape=1, roty=0, anchored=True,
         collide=True, transp=0.0):
    p = ['<string name="Name">%s</string>' % escape(name),
         '<bool name="Anchored">%s</bool>' % str(anchored).lower(),
         '<bool name="CanCollide">%s</bool>' % str(collide).lower(),
         '<Vector3 name="size"><X>%s</X><Y>%s</Y><Z>%s</Z></Vector3>' % size,
         cf_xml(*pos, roty=roty),
         '<Color3uint8 name="Color3uint8">%d</Color3uint8>' % color(*rgb),
         '<token name="Material">%d</token>' % MAT[mat],
         '<float name="Transparency">%s</float>' % transp,
         '<token name="TopSurface">0</token>', '<token name="BottomSurface">0</token>']
    if cls == "Part":
        p.append('<token name="shape">%d</token>' % shape)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties></Item>' % (cls, ref(), "".join(p))

def container(cls, name, children, extra=""):
    nm = '<string name="Name">%s</string>' % escape(name) if name else ""
    return '<Item class="%s" referent="%s"><Properties>%s%s</Properties>%s</Item>' % (
        cls, ref(), nm, extra, "".join(children))

def script(cls, name, src):
    assert "]]>" not in src
    return ('<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>'
            '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString></Properties></Item>') % (
        cls, ref(), name, src)

MAT["slate"] = 800
from fleet import build_fleet

WHITE = (245, 245, 248); YEL = (240, 200, 40); ASPH = (52, 55, 60); ASPH2 = (62, 65, 70)
world = []

# ================= ФЛОТ (строится прямо здесь — Toolbox не нужен)
fleet = build_fleet(part, container)
world.append(container("Folder", "Hangar", fleet))

# ================= АЭРОПОРТ
RW_HALF_W, RW_HALF_L = 60, 1200
rw = [part("RunwaySeg", (120, 0.4, 1200), (0, 0.2, z), ASPH) for z in (-600, 600)]
rw += [part("SafeRunwaySeg", (100, 0.4, 700), (4900, 3.2, z), ASPH) for z in (-350, 350)]
world.append(container("Model", "Runway", rw))

marks = []
def mk(name, size, pos, rgb=WHITE, roty=0):
    marks.append(part(name, size, pos, rgb, collide=False, roty=roty))
Y = 0.43
# осевая
for z in range(-1080, 1081, 60):
    mk("CenterLine", (1.4, 0.05, 30), (0, Y, z))
# кромки
for s in (-1, 1):
    for z in (-600, 600):
        mk("EdgeLine", (1.2, 0.05, 1200), (s * 57, Y, z))
# «пианино» на торцах, зоны приземления, точки прицеливания
for end in (-1, 1):
    zt = end * 1170
    for k in range(12):
        x = -50 + k * 8.2 + (8 if k >= 6 else 0)
        mk("Threshold", (4, 0.05, 45), (round(x, 1), Y, zt))
    mk("ThresholdBar", (118, 0.05, 2), (0, Y, end * 1196))
    for dist, n in ((260, 3), (380, 2), (500, 2), (620, 1)):
        for s in (-1, 1):
            for j in range(n):
                mk("TouchdownZone", (2.2, 0.05, 24), (s * (14 + j * 5), Y, end * (1170 - dist)))
    for s in (-1, 1):
        mk("AimingPoint", (8, 0.05, 50), (s * 18, Y, end * (1170 - 320)))

# цифры полосы (7-сегментные), читаются со стороны захода
SEG = {"0": "abcfed", "2": "abged", "7": "abc", "9": "abcdfg"}
def digit(ch, cx, cz, flip, w=10, h=22, t=2.4):
    # локальные u (вправо) и v (вверх по экрану = направление полёта)
    segs = {"a": (0, h / 2, w, t), "g": (0, 0, w, t), "d": (0, -h / 2, w, t),
            "f": (-w / 2, h / 4, t, h / 2), "b": (w / 2, h / 4, t, h / 2),
            "e": (-w / 2, -h / 4, t, h / 2), "c": (w / 2, -h / 4, t, h / 2)}
    for sname in SEG[ch]:
        u, v, su, sv = segs[sname]
        # торец +Z: смотрим в сторону -Z, «вправо» = +X, «вверх» = -Z; другой торец — наоборот
        x = cx + (u if not flip else -u)
        z = cz + (-v if not flip else v)
        mk("RunwayNumber", (su, 0.05, sv), (round(x, 2), Y, round(z, 2)))
for text, end in (("27", 1), ("09", -1)):
    flip = end == -1
    base_z = end * 1100
    for i, ch in enumerate(text):
        off = (i - 0.5) * 16
        digit(ch, off if not flip else -off, base_z, flip)
world.append(container("Model", "RunwayMarkings", marks))

# огни: кромка (белые), торцы (зелёные/красные)
lights = []
for s in (-1, 1):
    for z in range(-1180, 1181, 80):
        lights.append(part("EdgeLight", (0.8, 0.8, 0.8), (s * 62, 0.6, z), (255, 250, 230), mat="neon"))
for x in range(-56, 57, 8):
    lights.append(part("ThresholdLight", (0.8, 0.8, 0.8), (x, 0.6, 1203), (60, 255, 90), mat="neon"))
    lights.append(part("ThresholdLight", (0.8, 0.8, 0.8), (x, 0.6, -1203), (255, 60, 60), mat="neon"))
# огни подхода (линия перед торцом)
for k in range(1, 9):
    for x in (-6, 0, 6):
        lights.append(part("ApproachLight", (0.9, 0.9, 0.9), (x, 1.2, 1203 + k * 30), (255, 250, 230), mat="neon"))
world.append(container("Model", "RunwayLights", lights))

# рулёжная дорожка, соединители, перрон, стоянки
taxi = []
TX = -150
for z in (-550, 550):
    taxi.append(part("Taxiway", (110, 0.4, 1100), (TX, 0.2, z), ASPH2))
for z in (-1000, -400, 400, 1000):
    taxi.append(part("Connector", (40, 0.4, 70), (-78, 0.2, z), ASPH2))
for z in range(-1080, 1081, 40):
    taxi.append(part("TaxiLine", (1, 0.05, 22), (TX, Y, z), YEL, collide=False))
for z in (-1000, -400, 400, 1000):
    taxi.append(part("TaxiLine", (36, 0.05, 1), (-80, Y, z), YEL, collide=False))
for s in (-1, 1):
    for z in range(-1080, 1081, 90):
        taxi.append(part("TaxiLight", (0.7, 0.7, 0.7), (TX + s * 57, 0.55, z), (70, 140, 255), mat="neon"))
taxi.append(part("Apron", (110, 0.3, 420), (125, 0.15, -60), ASPH2))
for z in range(-240, 121, 60):
    taxi.append(part("StandLine", (80, 0.05, 1), (125, 0.34, z), YEL, collide=False))
world.append(container("Model", "Taxiways", taxi))

world.append(part("PlaneSpawn", (8, 0.2, 8), (0, 0.35, 1120), (255, 140, 40), mat="neon", collide=False, transp=0.3))
for k, z in enumerate([950, 600, 250, -100], 2):
    world.append(part("PlaneSpawn%d" % k, (8, 0.2, 8), (TX, 0.35, z), (255, 140, 40), mat="neon", collide=False, transp=0.3))

# терминал, башня, ангары техобслуживания
ap = [
    part("Terminal", (60, 26, 300), (230, 13, -60), (225, 228, 232), mat="concrete"),
    part("TerminalGlass", (1, 14, 290), (199.6, 13, -60), (120, 170, 210), mat="glass", transp=0.2),
    part("TerminalRoof", (66, 2, 306), (230, 27, -60), (150, 155, 165), mat="metal"),
    part("Tower", (14, 70, 14), (200, 35, 160), (220, 220, 225), mat="concrete"),
    part("TowerCab", (24, 12, 24), (200, 76, 160), (110, 170, 215), mat="glass", transp=0.25),
    part("TowerRoof", (27, 2, 27), (200, 83, 160), (60, 62, 68)),
]
for k in range(3):
    z = -330 - k * 90
    ap.append(part("MaintHangar", (70, 32, 70), (230, 16, z), (215, 218, 224), mat="metal"))
    ap.append(part("MaintDoor", (1, 26, 60), (194.6, 13, z), (80, 95, 115), mat="metal"))
for k in range(8):
    ap.append(part("Jetway", (24, 4, 4), (188, 9, -200 + k * 40), (200, 200, 205), mat="metal"))
# парковка с машинами
for k in range(14):
    ap.append(part("ParkedCar", (5, 3, 9), (290 + (k % 7) * 9, 1.5, -150 + (k // 7) * 16),
                   random.choice([(200, 40, 40), (240, 240, 240), (30, 30, 35), (40, 90, 180), (230, 190, 40)])))
ap.append(part("Parking", (80, 0.3, 50), (318, 0.15, -142), ASPH2))
ap.append(part("PassengerZone", (2, 2, 2), (130, 2, -60), (255, 150, 50), transp=1, collide=False))
world.append(container("Model", "Airport", ap))
# ---------------- здание ангара-витрины (x=-420, z=300), ворота смотрят на полосу (+X)
HX, HZ = -420, 300
W, D, H = 300, 260, 70
WALL = (150, 160, 175); DARKF = (70, 74, 82)
def light(name, pos):
    p = part(name, (16, 1, 6), pos, (255, 250, 235), mat="neon", collide=False)
    return p.replace("</Properties></Item>",
        '</Properties><Item class="PointLight" referent="%s"><Properties><float name="Brightness">1.6</float>'
        '<float name="Range">60</float></Properties></Item></Item>' % ref())
hb = [
    part("Floor", (W, 1, D), (HX, 0.5, HZ), DARKF, mat="concrete"),
    part("BackWall", (2, H, D), (HX - W / 2, H / 2, HZ), WALL, mat="concrete"),
    part("WallL", (W, H, 2), (HX, H / 2, HZ - D / 2), WALL, mat="concrete"),
    part("WallR", (W, H, 2), (HX, H / 2, HZ + D / 2), WALL, mat="concrete"),
    part("Roof", (W, 2, D), (HX, H + 1, HZ), (110, 115, 125), mat="metal"),
    part("DoorTop", (2, 16, D), (HX + W / 2, H - 8, HZ), WALL, mat="metal"),
    part("YellowLine", (W - 20, 0.1, 3), (HX, 1.06, HZ), (240, 210, 40), collide=False),
    part("HangarDisplay", (70, 0.4, 70), (HX - 20, 1.2, HZ), (55, 58, 66), mat="metal"),
    part("HangarCamera", (2, 2, 2), (HX + 70, 32, HZ + 55), (255, 0, 0), transp=1, collide=False),
]
# окна в задней стене (сетка светлых панелей, как в настоящем ангаре)
for iy in range(2):
    for iz in range(5):
        hb.append(part("Window", (0.4, 18, 36), (HX - W / 2 + 1.3, 22 + iy * 22, HZ - 90 + iz * 45),
                       (200, 225, 245), mat="neon", collide=False, transp=0.15))
for lx in (-80, 0, 80):
    for lz in (-60, 60):
        hb.append(light("CeilingLight", (HX + lx, H - 0.5, HZ + lz)))
# стеллажи по бокам для атмосферы
for side in (-1, 1):
    for k in range(3):
        hb.append(part("Rack", (14, 12, 4), (HX - 100 + k * 40, 6, HZ + side * (D / 2 - 6)), (60, 70, 90), mat="metal"))
world.append(container("Model", "HangarBuilding", hb))
world.append(part("Spawn", (12, 1, 12), (-330, 1.0, 330), (110, 220, 150), cls="SpawnLocation", transp=0.5))

# ================= ЗОНЫ, КУДА НЕ СТАВИМ ПОЛЯ/ДЕРЕВЬЯ/ДОМА
VILLAGES = [(-1300, 900), (950, 1700), (-900, -1900), (1600, -1500), (2250, 450), (-2000, -600),
            (450, 2700), (-450, -2900), (-2600, 1900), (1900, 2600)]
def in_airport(x, z, pad=0):
    if -230 - pad < x < 360 + pad and abs(z) < 1450 + pad: return True
    if abs(x) < 40 + pad and abs(z) < 1500 + pad: return True
    if -640 - pad < x < -190 + pad and 70 - pad < z < 530 + pad: return True
    return False
def near_village(x, z, r=220):
    return any((x - vx) ** 2 + (z - vz) ** 2 < r * r for vx, vz in VILLAGES)

# ================= ДОРОГИ (с разметкой) — от аэропорта к деревням и между ними
ROADS = []
hub = (420, 0)
for (vx, vz) in VILLAGES:
    ROADS.append((hub[0] if vx > -200 else -260, max(-1400, min(1400, vz)) if vx < -200 else 0, vx, vz))
ROADS += [(VILLAGES[0][0], VILLAGES[0][1], VILLAGES[8][0], VILLAGES[8][1]),
          (VILLAGES[2][0], VILLAGES[2][1], VILLAGES[7][0], VILLAGES[7][1]),
          (VILLAGES[1][0], VILLAGES[1][1], VILLAGES[9][0], VILLAGES[9][1]),
          (VILLAGES[3][0], VILLAGES[3][1], VILLAGES[4][0], VILLAGES[4][1])]
roads = []
for (sx, sz, ex, ez) in ROADS:
    dx, dz = ex - sx, ez - sz
    L = math.hypot(dx, dz)
    if L < 60: continue
    ux, uz = dx / L, dz / L
    ang = math.degrees(math.atan2(dx, dz))
    seg = 1600
    n = int(L // seg) + 1
    for k in range(n):
        l = min(seg, L - k * seg)
        mx, mz = sx + ux * (k * seg + l / 2), sz + uz * (k * seg + l / 2)
        roads.append(part("Road", (18, 0.3, l + 2), (round(mx, 1), 0.2, round(mz, 1)), (66, 68, 72), roty=ang))
        for s in (-1, 1):
            px, pz = mx + uz * s * 8.2, mz - ux * s * 8.2
            roads.append(part("RoadEdge", (0.5, 0.05, l), (round(px, 1), 0.37, round(pz, 1)), WHITE, collide=False, roty=ang))
    for t in range(20, int(L) - 10, 45):
        roads.append(part("RoadDash", (0.5, 0.05, 14), (round(sx + ux * t, 1), 0.37, round(sz + uz * t, 1)), WHITE,
                          collide=False, roty=ang))
world.append(container("Model", "Roads", roads))
def near_road(x, z, pad=25):
    for (sx, sz, ex, ez) in ROADS:
        dx, dz = ex - sx, ez - sz
        L2 = dx * dx + dz * dz
        if L2 == 0: continue
        t = max(0, min(1, ((x - sx) * dx + (z - sz) * dz) / L2))
        px, pz = sx + dx * t, sz + dz * t
        if (x - px) ** 2 + (z - pz) ** 2 < pad * pad: return True
    return False

# ================= ПОЛЯ (рисуются ландшафтом в WorldBuilder) + ряды деревьев
FIELD_MATS = ["Sandstone", "Ground", "LeafyGrass", "Limestone", "Grass", "Mud", "Sandstone", "Limestone"]
cells = []
for gx in range(-15, 15):
    for gz in range(-19, 20):
        cx, cz = gx * 190 + random.randint(-10, 10), gz * 160 + random.randint(-10, 10)
        if in_airport(cx, cz, 60) or cx > 2650 or near_village(cx, cz, 200) or random.random() < 0.18:
            continue
        w, d = 190 - random.randint(8, 24), 160 - random.randint(8, 24)
        cells.append((cx, cz, w, d, random.choice(FIELD_MATS)))

def tree(x, z, kind=None, big=1.0):
    kind = kind or random.choice(["round", "round", "cypress", "pine", "wide"])
    x, z = round(x, 1), round(z, 1)
    out = []
    if kind == "cypress":
        h = random.uniform(6, 9) * big
        out.append(part("Trunk", (1.2, h, 1.2), (x, h / 2, z), (95, 68, 45), mat="wood"))
        s = random.uniform(5, 7) * big
        g = (55, random.randint(105, 130), 50)
        out.append(part("Leaves", (s, s * 2.6, s), (x, h + s * 0.9, z), g, mat="grass", shape=0 if False else 1))
        out.append(part("Leaves", (s * 0.75, s * 1.4, s * 0.75), (x, h + s * 2.3, z), g, mat="grass"))
    elif kind == "pine":
        h = random.uniform(5, 8) * big
        out.append(part("Trunk", (1.4, h, 1.4), (x, h / 2, z), (90, 62, 40), mat="wood"))
        g = (40, random.randint(95, 115), 55)
        for k, sz in enumerate((11, 8, 5)):
            out.append(part("Leaves", (sz * big, 4 * big, sz * big), (x, h + k * 3.6 * big, z), g, mat="grass",
                            roty=k * 30))
    else:
        h = random.uniform(9, 14) * big
        out.append(part("Trunk", (1.8, h, 1.8), (x, h / 2, z), (100, 70, 45), mat="wood"))
        base = (random.randint(65, 95), random.randint(135, 175), random.randint(50, 70))
        s = random.uniform(9, 13) * big * (1.3 if kind == "wide" else 1)
        out.append(part("Leaves", (s, s, s), (x, h + s * 0.25, z), base, mat="grass", shape=0))
        for _ in range(2):
            o = s * 0.35
            c2 = tuple(max(0, min(255, v + random.randint(-15, 15))) for v in base)
            out.append(part("Leaves", (s * 0.75,) * 3, (round(x + random.uniform(-o, o), 1), h + s * 0.45,
                                                          round(z + random.uniform(-o, o), 1)), c2, mat="grass", shape=0))
    return out

def bush(x, z):
    s = random.uniform(3, 6)
    return [part("Bush", (s, s * 0.8, s), (round(x, 1), s * 0.3, round(z, 1)),
                 (random.randint(55, 80), random.randint(115, 150), 50), mat="grass", shape=0)]

veg = []
random.shuffle(cells)
for (cx, cz, w, d, m) in cells[:150]:
    edge = random.choice(("z", "x"))
    if edge == "z":
        ez = cz + (d / 2 + 5) * random.choice((-1, 1))
        kind = random.choice(["cypress", "round", "cypress"])
        for k in range(7):
            x = cx - w / 2 + 10 + k * (w - 20) / 6
            if not near_road(x, ez, 14): veg += tree(x, ez, kind)
    else:
        ex = cx + (w / 2 + 5) * random.choice((-1, 1))
        for k in range(5):
            z = cz - d / 2 + 10 + k * (d - 20) / 4
            if not near_road(ex, z, 14): veg += tree(ex, z, "round")
# рощи
for _ in range(18):
    gx, gz = random.uniform(-2700, 2500), random.uniform(-3000, 3000)
    if in_airport(gx, gz, 120) or near_village(gx, gz, 250): continue
    for _ in range(14):
        x, z = gx + random.uniform(-70, 70), gz + random.uniform(-70, 70)
        if not near_road(x, z): veg += tree(x, z, random.choice(["round", "pine", "wide"]), big=random.uniform(0.9, 1.3))
# кусты вдоль дорог
for (sx, sz, ex, ez) in ROADS:
    L = math.hypot(ex - sx, ez - sz)
    for t in range(60, int(L), 120):
        f = t / L
        x, z = sx + (ex - sx) * f, sz + (ez - sz) * f
        ox, oz = -(ez - sz) / L * 16, (ex - sx) / L * 16
        if not in_airport(x, z, 20):
            veg += bush(x + ox, z + oz) if random.random() < 0.6 else tree(x + ox, z + oz, "cypress")
# деревья вокруг аэропорта и ангара
for _ in range(60):
    x, z = random.choice([(random.uniform(-700, -250), random.uniform(560, 900)),
                          (random.uniform(400, 700), random.uniform(-1300, 1300)),
                          (random.uniform(-700, -260), random.uniform(-1300, 40))])
    if not in_airport(x, z, 10) and not near_road(x, z):
        veg += tree(x, z)
world.append(container("Model", "Vegetation", veg))

# ================= ДЕРЕВНИ: дома с крышами, окнами, трубами, заборами
ROOF = [(180, 70, 50), (200, 92, 52), (150, 60, 45), (95, 95, 105), (190, 110, 60), (120, 60, 50)]
WALLS = [(240, 236, 225), (232, 220, 190), (245, 225, 205), (225, 225, 230), (236, 210, 180), (215, 200, 175)]
def house(x, z, rot):
    w, h, d = random.choice([(16, 10, 12), (20, 10, 14), (14, 12, 12), (24, 9, 14), (18, 16, 13)])
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    def at(lx, lz):
        return (round(x + lx * c + lz * s, 2), round(z - lx * s + lz * c, 2))
    roofc = random.choice(ROOF)
    out = [part("House", (w, h, d), (x, h / 2, z), random.choice(WALLS), mat="concrete", roty=rot)]
    ax, az = at(0, -d / 4)
    bx, bz = at(0, d / 4)
    out.append(part("Roof", (w + 1.6, 5.5, d / 2 + 0.8), (ax, h + 2.75, az), roofc, cls="WedgePart", roty=rot))
    out.append(part("Roof", (w + 1.6, 5.5, d / 2 + 0.8), (bx, h + 2.75, bz), roofc, cls="WedgePart", roty=rot + 180))
    cx_, cz_ = at(w * 0.3, d * 0.15)
    out.append(part("Chimney", (1.6, 5, 1.6), (cx_, h + 4, cz_), (150, 80, 60), mat="concrete"))
    dx, dz = at(0, -d / 2 - 0.1)
    out.append(part("Door", (3, 6, 0.4), (dx, 3, dz), (95, 62, 40), mat="wood", roty=rot))
    for lx in (-w * 0.3, w * 0.3):
        wx, wz = at(lx, -d / 2 - 0.1)
        out.append(part("Window", (3, 3, 0.3), (wx, h * 0.55, wz), (70, 110, 150), mat="glass", roty=rot))
        wx, wz = at(lx, d / 2 + 0.1)
        out.append(part("Window", (3, 3, 0.3), (wx, h * 0.55, wz), (70, 110, 150), mat="glass", roty=rot))
    for lz in (-d * 0.2, d * 0.2):
        wx, wz = at(w / 2 + 0.1, lz)
        out.append(part("Window", (0.3, 3, 3), (wx, h * 0.55, wz), (70, 110, 150), mat="glass", roty=rot))
    # садик с забором
    if random.random() < 0.5:
        fx, fz = at(0, -d / 2 - 7)
        out.append(part("Fence", (w + 6, 1.8, 0.4), (fx, 0.9, fz), (235, 235, 230), mat="wood", roty=rot))
        tx, tz = at(-w / 2 - 4, -d / 2 - 3)
        out += tree(tx, tz, "round", big=0.7)
    return out

vparts = []
for (vx, vz) in VILLAGES:
    placed = []
    for _ in range(22):
        for _try in range(6):
            hx, hz = vx + random.uniform(-170, 170), vz + random.uniform(-170, 170)
            if in_airport(hx, hz, 30) or near_road(hx, hz, 22): continue
            if any((hx - px) ** 2 + (hz - pz) ** 2 < 32 ** 2 for px, pz in placed): continue
            placed.append((hx, hz))
            vparts += house(round(hx, 1), round(hz, 1), random.choice((0, 90, 180, 270)) + random.uniform(-6, 6))
            break
    cx_, cz_ = vx + 50, vz - 50
    if not near_road(cx_, cz_, 25):
        vparts.append(part("Church", (18, 22, 30), (cx_, 11, cz_), (238, 232, 222), mat="concrete"))
        vparts.append(part("ChurchRoof", (20, 8, 15.5), (cx_, 26, cz_ - 7.5), (160, 65, 50), cls="WedgePart"))
        vparts.append(part("ChurchRoof", (20, 8, 15.5), (cx_, 26, cz_ + 7.5), (160, 65, 50), cls="WedgePart", roty=180))
        vparts.append(part("Belltower", (8, 44, 8), (cx_, 22, cz_ - 19), (238, 232, 222), mat="concrete"))
        vparts.append(part("Spire", (8.5, 10, 4.3), (cx_, 49, cz_ - 21.1), (90, 95, 105), cls="WedgePart"))
        vparts.append(part("Spire", (8.5, 10, 4.3), (cx_, 49, cz_ - 16.9), (90, 95, 105), cls="WedgePart", roty=180))
world.append(container("Model", "Villages", vparts))

# ================= ГОРОД на горизонте
city = []
for _ in range(80):
    bx, bz = random.uniform(-3100, -2300), random.uniform(2300, 3300)
    h = random.choice([40, 60, 80, 110, 150, 200, 260])
    w = random.choice([30, 40, 50, 60])
    col = random.choice([(150, 170, 190), (205, 205, 210), (120, 140, 165), (215, 205, 190), (90, 115, 145)])
    city.append(part("Tower", (w, h, w), (round(bx, 1), h / 2, round(bz, 1)), col, mat=random.choice(["glass", "concrete"])))
    city.append(part("Roof", (w + 1, 1.5, w + 1), (round(bx, 1), h + 0.75, round(bz, 1)), (90, 92, 98)))
world.append(container("Model", "City", city))


# ================= УБЕЖИЩЕ: остров с аэродромом в море на востоке
SX, SY = 4900, 3.0
safe = [
    part("SafeZone", (2, 2, 2), (SX, SY + 2, 0), (60, 255, 120), transp=1, collide=False),
    part("Beacon", (8, 420, 8), (SX + 140, SY + 210, 0), (80, 255, 140), mat="neon", collide=False, transp=0.35),
    part("BeaconTop", (20, 20, 20), (SX + 140, SY + 430, 0), (120, 255, 160), mat="neon", collide=False, shape=0),
]
for k in range(6):
    tz = -300 + k * 120
    safe.append(part("Tent", (24, 10, 9), (SX + 120, SY + 5, tz - 4.5), (90, 140, 90), cls="WedgePart"))
    safe.append(part("Tent", (24, 10, 9), (SX + 120, SY + 5, tz + 4.5), (90, 140, 90), cls="WedgePart", roty=180))
    safe.append(part("RedCross", (25, 0.3, 4), (SX + 120, SY + 10.2, tz), (220, 40, 40), collide=False))
for k in range(10):
    safe.append(part("Sandbags", (14, 4, 4), (SX + 180, SY + 2, -360 + k * 80), (190, 170, 120), mat="sand"))
safe.append(part("Helipad", (40, 0.3, 40), (SX + 200, SY + 0.15, 420), (60, 62, 66)))
safe.append(part("HelipadH", (4, 0.05, 20), (SX + 194, SY + 0.33, 420), WHITE, collide=False))
safe.append(part("HelipadH", (4, 0.05, 20), (SX + 206, SY + 0.33, 420), WHITE, collide=False))
safe.append(part("HelipadH", (12, 0.05, 3), (SX + 200, SY + 0.33, 420), WHITE, collide=False))
for z in range(-660, 661, 60):
    safe.append(part("SafeCenterLine", (1.4, 0.05, 30), (SX, SY + 0.43, z), WHITE, collide=False))
for s in (-1, 1):
    for z in range(-700, 701, 70):
        safe.append(part("SafeEdgeLight", (0.8, 0.8, 0.8), (SX + s * 52, SY + 0.6, z), (80, 255, 140), mat="neon"))
world.append(container("Model", "SafeAirport", safe))

world.append(container("Folder", "Zombies", []))
world.append(container("Folder", "Birds", []))
world.append(container("Folder", "Drones", []))

# ================= СКРИПТЫ (данные полей и дорог вшиваем в исходники)
def rd(n): return str(int(round(n)))
fields_str = ";".join(",".join([rd(c[0]), rd(c[1]), rd(c[2]), rd(c[3]), c[4]]) for c in cells)
roads_str = ";".join(",".join(rd(v) for v in r) for r in ROADS)
server_src = open(src("server/FlyCrashServer.lua"), encoding="utf-8").read()
client_src = open(src("client/FlyCrashClient.lua"), encoding="utf-8").read()
zombie_src = open(src("server/OutbreakServer.lua"), encoding="utf-8").read()
shared_src = open(src("shared/FlyCrashShared.lua"), encoding="utf-8").read()
world_src = open(src("server/WorldBuilder.lua"), encoding="utf-8").read().replace("__FIELDS__", fields_str)
traffic_src = open(src("server/TrafficServer.lua"), encoding="utf-8").read().replace("__ROADS__", roads_str)

out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
       container("Workspace", "Workspace", world),
       container("ReplicatedStorage", "ReplicatedStorage", [
           container("Folder", "FlyCrash", [
               container("RemoteEvent", "Chaos", []),
               container("RemoteEvent", "PilotInput", []),
               container("RemoteEvent", "Hangar", []),
           ]),
           script("ModuleScript", "FlyCrashShared", shared_src),
           container("Folder", "FlyCrashSounds", [
               container("Sound", n, [], '<float name="Volume">0.8</float>')
               for n in ["EngineLoop", "EngineStart", "Takeoff", "Landing", "Explosion", "Crash",
                         "Fire", "Alarm", "Geese", "Pilots", "Stewardess", "Coin"]
           ])]),
       container("ServerScriptService", "ServerScriptService", [
           script("Script", "FlyCrashServer", server_src),
           script("Script", "OutbreakServer", zombie_src),
           script("Script", "WorldBuilder", world_src),
           script("Script", "TrafficServer", traffic_src)]),
       container("StarterPlayer", "StarterPlayer", [
           container("StarterPlayerScripts", "StarterPlayerScripts", [
               script("LocalScript", "FlyCrashClient", client_src)])],
           '<float name="CharacterWalkSpeed">26</float><float name="CharacterJumpPower">55</float>'),
       container("ServerStorage", "ServerStorage", []),
       '</roblox>']
open(os.path.join(ROOT, "FlyCrash.rbxlx"), "w", encoding="utf-8").write("\n".join(out))
print("ok", ref_n[0], "items;", len(cells), "fields;", len(ROADS), "roads")
