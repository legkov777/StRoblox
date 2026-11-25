# Процедурный флот FlyCrash: самолёты из деталей Roblox, нос смотрит на -Z.
import math

def build_fleet(part, container):
    WHITE = (245, 246, 248)
    GLASS = (40, 60, 85)
    DARK = (30, 30, 34)
    GREY = (150, 155, 162)
    METAL = (190, 195, 200)

    class P:
        def __init__(self, ox, oz):
            self.ox, self.oz, self.items = ox, oz, []

        def add(self, name, size, pos, rgb, **kw):
            x, y, z = pos
            self.items.append(part(name, tuple(round(v, 3) for v in size),
                                   (round(x + self.ox, 3), round(y, 3), round(z + self.oz, 3)), rgb, **kw))

        def cylz(self, name, length, d, pos, rgb, **kw):  # цилиндр вдоль Z
            self.add(name, (length, d, d), pos, rgb, shape=2, roty=90, **kw)

        def ball(self, name, d, pos, rgb, **kw):
            self.add(name, (d, d, d), pos, rgb, shape=0, **kw)

        def wheel(self, pos, d, w=None):  # цилиндр по оси X = колесо
            self.add("Wheel", (w or d * 0.45, d, d), pos, DARK, shape=2)

    def fuselage(p, L, d, yc, rgb, nose_frac=0.13, tail_frac=0.26, nose_drop=0.15):
        r = d / 2
        zn = -L / 2
        nl, tl = L * nose_frac, L * tail_frac
        ml = L - nl - tl
        p.cylz("Body", ml, d, (0, yc, zn + nl + ml / 2), rgb)
        segs = 3
        sl = nl / (segs + 1)
        for k in range(segs):
            dk = d * (1 - (k + 1) * 0.17)
            p.cylz("Nose", sl + 0.3, dk, (0, yc - (d - dk) * nose_drop, zn + nl - sl * (k + 0.5)), rgb)
        dk = d * (1 - segs * 0.17)
        p.ball("NoseCap", dk, (0, yc - (d - dk) * nose_drop, zn + sl * 0.7), rgb)
        ts = 4
        tsl = tl / ts
        for k in range(ts):
            dk = d * (1 - (k + 1) * 0.17)
            p.cylz("TailCone", tsl + 0.3, dk, (0, yc + (d - dk) / 2 * 0.9, zn + nl + ml + tsl * (k + 0.5)), rgb)
        # невидимый маркер носа — по нему сервер понимает, куда смотрит самолёт
        p.add("NoseMarker", (0.5, 0.5, 0.5), (0, yc, zn - 1), (255, 0, 0), transp=1, collide=False)
        return zn, zn + nl, zn + nl + ml, L / 2

    def cockpit(p, d, yc, zstart, nose_drop=0.15):
        r = d / 2
        p.add("Windshield", (d * 0.62, d * 0.22, d * 0.34), (0, yc + r * 0.62, zstart + d * 0.05), GLASS,
              cls="WedgePart", mat="glass")

    def stripe(p, d, yc, z0, z1, rgb, yoff=-0.1, h=0.13):
        r = d / 2
        L = z1 - z0
        for s in (1, -1):
            p.add("Cheatline", (0.3, d * h, L), (s * (r * 0.985 + 0.1), yc + r * yoff, (z0 + z1) / 2), rgb, collide=False)

    def windows(p, d, yc, z0, z1, n, rgb=GLASS):
        r = d / 2
        if n <= 0:
            return
        step = (z1 - z0) / n
        for i in range(n):
            z = z0 + step * (i + 0.5)
            for s in (1, -1):
                p.add("Window", (0.25, d * 0.11, d * 0.09), (s * (r * 0.96 + 0.1), yc + r * 0.25, z), rgb, collide=False)

    def wings(p, span, chord, thick, sweep, y, zroot, r, rgb, tip=None):
        L = span / 2 - r * 0.3
        s = math.radians(sweep)
        roots = []
        for side in (1, -1):
            dx, dz = side * math.cos(s), math.sin(s)
            rx = side * r * 0.3
            p.add("Wing", (L, thick, chord), (rx + dx * L / 2, y, zroot + dz * L / 2), rgb,
                  roty=(-sweep if side == 1 else sweep))
            # законцовка крыла
            tx, tz = rx + dx * L, zroot + dz * L
            if tip:
                p.add("Winglet", (thick * 1.2, chord * 0.35, chord * 0.45), (tx, y + chord * 0.17, tz + chord * 0.1), tip,
                      cls="WedgePart")
            roots.append((side, rx, dx, dz, L))
        return roots

    def along(root, f, zroot):
        side, rx, dx, dz, L = root
        return rx + dx * L * f, zroot + dz * L * f

    def jet_engine(p, x, y, z, length, d, rgb, name="Engine"):
        p.cylz(name, length, d, (x, y, z), rgb, mat="metal")
        p.cylz(name + "Intake", 0.4, d * 0.82, (x, y, z - length / 2 - 0.1), DARK)
        p.cylz(name + "Exhaust", length * 0.25, d * 0.55, (x, y, z + length / 2 + length * 0.1), GREY, mat="metal")

    def propeller(p, x, y, z, D, rgb=DARK, name="Prop"):
        p.ball(name + "Spinner", D * 0.22, (x, y, z), WHITE)
        p.add(name, (D * 0.07, D, D * 0.04), (x, y, z - D * 0.02), rgb)
        p.add(name, (D, D * 0.07, D * 0.04), (x, y, z - D * 0.02), rgb)

    def fin(p, h, chord, thick, y0, ztail, rgb):
        p.add("TailFin", (thick, h, chord), (0, y0 + h / 2, ztail - chord / 2), rgb, cls="WedgePart")
        return y0 + h

    def stab(p, span, chord, thick, sweep, y, z, rgb):
        s = math.radians(sweep)
        L = span / 2
        for side in (1, -1):
            dx, dz = side * math.cos(s), math.sin(s)
            p.add("Stabilizer", (L, thick, chord), (dx * L / 2, y, z + dz * L / 2), rgb,
                  roty=(-sweep if side == 1 else sweep))

    def gear(p, x, z, wheel_d, belly_y, n=1, spacing=None):
        strut_h = belly_y - wheel_d / 2 + 0.6
        p.add("Strut", (0.5, strut_h, 0.5), (x, wheel_d / 2 + strut_h / 2, z), METAL)
        sp = spacing or wheel_d * 0.6
        for k in range(n):
            off = (k - (n - 1) / 2) * sp
            p.wheel((x + off, wheel_d / 2, z), wheel_d)

    def seats(p, yc, z0, z1, n):
        p.add("PilotSeat", (2.2, 1, 2.2), (0, yc - 0.6, z0), (240, 120, 50), cls="VehicleSeat", transp=1)
        step = (z1 - z0) / max(1, n)
        for k in range(1, n + 1):
            p.add("PassengerSeat", (2.2, 1, 2.2), (0, yc - 0.6, z0 + step * k), (90, 70, 200), cls="Seat", transp=1)

    planes = []

    # ---------------- Cessna 172 (высокоплан, винт)
    p = P(-900, -600)
    d, L = 4.6, 27
    yc = 4.8
    zn, zc, zm, zt = fuselage(p, L, d, yc, WHITE, nose_frac=0.16, tail_frac=0.42, nose_drop=0.05)
    p.add("Cabin", (d * 0.9, d * 0.5, L * 0.22), (0, yc + d * 0.42, zc + L * 0.13), WHITE)
    p.add("Windshield", (d * 0.8, d * 0.45, d * 0.6), (0, yc + d * 0.42, zc + 0.6), GLASS, cls="WedgePart", mat="glass")
    for s in (1, -1):
        p.add("SideWindow", (0.25, d * 0.35, L * 0.18), (s * (d * 0.45 + 0.05), yc + d * 0.42, zc + L * 0.13), GLASS, collide=False)
    wings(p, 38, 5, 0.7, 0, yc + d * 0.72, zc + L * 0.12, d / 2, WHITE)
    for s in (1, -1):
        p.add("WingStrut", (0.35, d * 0.9, 0.35), (s * 6, yc + d * 0.15, zc + L * 0.14), METAL, collide=False)
        p.add("WingTip", (1.6, 0.75, 5.05), (s * 18.6, yc + d * 0.72, zc + L * 0.12), (240, 205, 40), collide=False)
    stripe(p, d, yc, zn + 2, zt - 2, (240, 205, 40), yoff=-0.05, h=0.12)
    stripe(p, d, yc, zn + 2, zt - 4, (40, 70, 120), yoff=-0.3, h=0.06)
    ftop = fin(p, 6.5, 5.5, 0.5, yc + 0.6, zt, WHITE)
    p.add("FinTip", (0.55, 1.2, 2.4), (0, ftop - 0.6, zt - 1.3), (240, 205, 40))
    stab(p, 12, 3, 0.4, 0, yc + 0.8, zt - 1.8, WHITE)
    propeller(p, 0, yc - 0.1, zn - 0.6, 6.2, name="Prop")
    p.cylz("EngineCowl", 2.2, d * 0.8, (0, yc - 0.1, zn + 1.4), WHITE)
    p.items[-1] = p.items[-1].replace('<string name="Name">EngineCowl</string>', '<string name="Name">Engine</string>')
    gear(p, 0, zn + 2.2, 1.6, yc - d / 2)
    gear(p, 2.8, zc + L * 0.25, 1.9, yc - d / 2)
    gear(p, -2.8, zc + L * 0.25, 1.9, yc - d / 2)
    seats(p, yc, zc + 1, zc + 5, 3)
    planes.append(container("Model", "Cessna 172", p.items))

    # ---------------- Challenger 650 (бизнес-джет, Т-хвост, двигатели у хвоста)
    p = P(-600, -600)
    d, L = 6.2, 48
    yc = 6.0
    zn, zc, zm, zt = fuselage(p, L, d, yc, WHITE, nose_frac=0.17, tail_frac=0.3)
    cockpit(p, d, yc, zc - 3)
    windows(p, d, yc, zc + 2, zm - 2, 7)
    roots = wings(p, 44, 8, 0.9, 25, yc - d * 0.32, zc + L * 0.18, d / 2, WHITE, tip=WHITE)
    for s in (1, -1):
        jet_engine(p, s * (d / 2 + 2.2), yc + d * 0.2, zm + 3, 7, 3.4, WHITE)
        p.add("Pylon", (2.2, 0.6, 3), (s * (d / 2 + 0.9), yc + d * 0.2, zm + 3), WHITE)
    ftop = fin(p, 9, 8, 0.6, yc + d * 0.3, zt, WHITE)
    stab(p, 18, 3.6, 0.5, 25, ftop - 0.3, zt - 4.5, WHITE)
    for k in range(4):
        p.add("FinStripe", (0.7, 0.6, 5), (0, yc + d * 0.3 + 2 + k * 1.6, zt - 2.4 - k * 0.7), DARK, collide=False)
    stripe(p, d, yc, zc, zm, DARK, yoff=-0.35, h=0.05)
    gear(p, 0, zn + 4, 1.8, yc - d / 2)
    gear(p, 2.6, zc + L * 0.3, 2.2, yc - d / 2)
    gear(p, -2.6, zc + L * 0.3, 2.2, yc - d / 2)
    seats(p, yc, zc - 1, zm - 2, 5)
    planes.append(container("Model", "Challenger 650", p.items))

    # ---------------- ATR 72 (высокоплан, 2 турбовинта, Т-хвост)
    p = P(-300, -600)
    d, L = 7.2, 58
    yc = 6.2
    zn, zc, zm, zt = fuselage(p, L, d, yc, WHITE, nose_frac=0.13, tail_frac=0.3)
    cockpit(p, d, yc, zc - 3)
    windows(p, d, yc, zc + 2, zm, 16)
    zr = zc + L * 0.16
    roots = wings(p, 62, 6.5, 0.9, 0, yc + d * 0.5, zr, d / 2, WHITE)
    for root in roots:
        x, z = along(root, 0.32, zr)
        p.cylz("Engine", 8.5, 3.2, (x, yc + d * 0.42, z - 1.2), WHITE, mat="metal")
        propeller(p, x, yc + d * 0.42, z - 5.8, 8, name="Prop")
    stripe(p, d, yc, zn + 3, zt - 3, (30, 90, 170), yoff=-0.3, h=0.08)
    ftop = fin(p, 10, 9, 0.6, yc + d * 0.3, zt, (30, 90, 170))
    stab(p, 20, 3.8, 0.5, 8, ftop - 0.3, zt - 4.5, WHITE)
    p.add("Sponson", (d * 1.3, 2, 9), (0, yc - d * 0.42, zc + L * 0.25), WHITE)
    gear(p, 0, zn + 4, 2.0, yc - d / 2)
    gear(p, 3.4, zc + L * 0.25, 2.3, yc - d / 2, n=2)
    gear(p, -3.4, zc + L * 0.25, 2.3, yc - d / 2, n=2)
    seats(p, yc, zc - 1, zm - 2, 6)
    planes.append(container("Model", "ATR 72", p.items))

    # ---------------- Boeing 737 (низкоплан, 2 двигателя под крылом)
    p = P(0, -600)
    d, L = 9, 78
    yc = 8.8
    zn, zc, zm, zt = fuselage(p, L, d, yc, WHITE, nose_frac=0.12, tail_frac=0.24)
    cockpit(p, d, yc, zc - 4)
    windows(p, d, yc, zc + 3, zm, 26)
    zr = zc + L * 0.2
    roots = wings(p, 72, 11, 1.1, 25, yc - d * 0.35, zr, d / 2, WHITE, tip=(25, 45, 110))
    for root in roots:
        x, z = along(root, 0.33, zr)
        jet_engine(p, x, yc - d * 0.35 - 2.6, z - 5, 9, 4.6, (25, 45, 110))
        p.add("Pylon", (0.8, 2, 6), (x, yc - d * 0.35 - 0.9, z - 2.5), WHITE)
    stripe(p, d, yc, zn + 4, zt - 6, (25, 45, 110), yoff=-0.32, h=0.09)
    stripe(p, d, yc, zc, zt - 6, (240, 180, 40), yoff=-0.46, h=0.04)
    ftop = fin(p, 14, 13, 0.8, yc + d * 0.25, zt, (25, 45, 110))
    stab(p, 28, 5.5, 0.6, 30, yc + d * 0.1, zt - 6, WHITE)
    gear(p, 0, zn + 6, 2.2, yc - d / 2, n=2)
    gear(p, 4.2, zr + 6, 2.8, yc - d / 2, n=2)
    gear(p, -4.2, zr + 6, 2.8, yc - d / 2, n=2)
    seats(p, yc, zc - 2, zm - 2, 8)
    planes.append(container("Model", "Boeing 737", p.items))

    # ---------------- Boeing 747 (джамбо, горб, 4 двигателя)
    p = P(300, -600)
    d, L = 12.5, 112
    yc = 11.8
    zn, zc, zm, zt = fuselage(p, L, d, yc, WHITE, nose_frac=0.11, tail_frac=0.24)
    p.cylz("UpperDeck", L * 0.3, d * 0.7, (0, yc + d * 0.28, zc + L * 0.13), WHITE)
    p.ball("UpperNose", d * 0.7, (0, yc + d * 0.28, zc - 1), WHITE)
    p.add("Windshield", (d * 0.45, d * 0.16, d * 0.25), (0, yc + d * 0.68, zc - 1.5), GLASS, cls="WedgePart", mat="glass")
    windows(p, d, yc, zc + 3, zm, 34)
    zr = zc + L * 0.22
    roots = wings(p, 104, 17, 1.4, 35, yc - d * 0.38, zr, d / 2, WHITE, tip=(200, 30, 40))
    for root in roots:
        for f in (0.3, 0.58):
            x, z = along(root, f, zr)
            jet_engine(p, x, yc - d * 0.38 - 3.2, z - 6, 11, 5.4, WHITE)
            p.add("Pylon", (0.9, 2.4, 7), (x, yc - d * 0.38 - 1.1, z - 3), WHITE)
    stripe(p, d, yc, zn + 5, zt - 8, (200, 30, 40), yoff=-0.28, h=0.07)
    ftop = fin(p, 20, 18, 1.0, yc + d * 0.25, zt, (200, 30, 40))
    stab(p, 40, 8, 0.8, 35, yc + d * 0.1, zt - 8, WHITE)
    gear(p, 0, zn + 9, 2.8, yc - d / 2, n=2)
    for s in (1, -1):
        gear(p, s * 4.5, zr + 9, 3.2, yc - d / 2, n=2)
        gear(p, s * 9, zr + 5, 3.2, yc - d / 2, n=2)
    seats(p, yc, zc - 2, zm - 4, 10)
    planes.append(container("Model", "Boeing 747", p.items))

    # ---------------- Ан-225 «Мрия» (6 двигателей, двухкилевое оперение)
    p = P(600, -600)
    d, L = 14, 132
    yc = 9.8
    zn, zc, zm, zt = fuselage(p, L, d, yc, WHITE, nose_frac=0.1, tail_frac=0.22, nose_drop=0.3)
    cockpit(p, d, yc, zc - 5)
    windows(p, d, yc, zc + 2, zc + 18, 6)
    zr = zc + L * 0.28
    roots = wings(p, 136, 18, 1.5, 15, yc + d * 0.42, zr, d / 2, WHITE)
    for root in roots:
        for f in (0.22, 0.38, 0.54):
            x, z = along(root, f, zr)
            jet_engine(p, x, yc + d * 0.42 - 3.4, z - 6, 10, 5, WHITE)
    stripe(p, d, yc, zn + 6, zt - 10, (30, 90, 190), yoff=-0.2, h=0.06)
    stripe(p, d, yc, zn + 6, zt - 10, (250, 205, 30), yoff=-0.32, h=0.05)
    sy = yc + d * 0.45
    p.add("Stabilizer", (48, 1, 9), (0, sy, zt - 7), WHITE)
    for s in (1, -1):
        p.add("TailFin", (1, 16, 11), (s * 24, sy + 8, zt - 7), (30, 90, 190), cls="WedgePart")
    gear(p, 0, zn + 9, 2.8, yc - d / 2, n=2)
    for s in (1, -1):
        for k in range(5):
            gear(p, s * 6.5, zc + L * 0.18 + k * 4.5, 3, yc - d / 2, n=2)
    seats(p, yc, zc - 3, zc + 20, 8)
    planes.append(container("Model", "Ан-225 Мрия", p.items))

    return planes
