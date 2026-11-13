class_name Bank
extends Node3D
## خريطة «بنك الاتحاد الوطني»: الصالة الرئيسية، الطابق العلوي، قبو الخزنة، الكراج، نفق الهروب، والشارع.

const B := -5.0   # أرضية القبو
const G := 0.0    # الطابق الأرضي
const U := 5.0    # الطابق العلوي
const R := 10.0   # السطح
const H := 4.6    # ارتفاع الغرفة الصافي

var b: Builder
var pts := {}                 # نقاط مسمّاة للقصة
var hostage_spots: Array = [] # [موقع، اتجاه]
var gates := {}               # بوابات متحركة: اسم -> Node3D
var nav: NavigationRegion3D
var police_lights: Array = []
var alarm_lights: Array = []
var _t := 0.0
var police_on := false
var alarm_on := false


func build() -> void:
	b = Builder.new(self)
	_shell()
	_lobby()
	_wings_ground()
	_back_ground()
	_upper()
	_basement()
	_tunnel()
	_exterior()
	b.commit()
	_gates()
	_nav()


# ---------------------------------------------------------------- الهيكل
func _shell() -> void:
	b.zone = "shell"
	# بلاطة الأرضي مع فتحتي درج القبو
	b.slab(-21.2, -30, 21.2, 22, G, "concrete")
	for sx in [-1.0, 1.0]:
		var xa: float = min(sx * 21.2, sx * 24.0)
		var xb: float = max(sx * 21.2, sx * 24.0)
		b.slab(xa, -30, xb, -4.5, G, "concrete")
		b.slab(xa, 4.5, xb, 22, G, "concrete")
	# بلاطة القبو والسطح
	b.slab(-24, -30, 24, 22, B, "concrete", 0.5)
	b.slab(-24.4, -30.4, 24.4, 22.4, R, "concrete_dark", 0.4)
	# الجدران الخارجية (أرضي + علوي)
	b.wall_z(-24, -30, 22, G, R - 0.4, "plaster")
	b.wall_z(24, -30, 22, G, R - 0.4, "plaster")
	b.wall_x(-30, -24, 24, G, R - 0.4, "plaster", [[13.0, 19.0, 4.0]])
	b.wall_x(22, -24, -14, G, R - 0.4, "plaster")
	b.wall_x(22, 14, 24, G, R - 0.4, "plaster")
	# باب التحميل (مغلق)
	b.box(Vector3(16, 2.0, -30), Vector3(6, 4, 0.2), "steel_dark")
	for i in 8:
		b.box(Vector3(16, 0.25 + i * 0.5, -29.88), Vector3(6, 0.06, 0.05), "#22252b:0.5:0.6", false)
	# جدران القبو الخارجية
	b.wall_z(-24, -10, 22, B, G - 0.4, "concrete", [[12.5, 15.5, 2.8]])
	b.wall_z(24, -10, 22, B, G - 0.4, "concrete")
	b.wall_x(22, -24, 24, B, G - 0.4, "concrete", [[-3.5, 3.5, 3.4]])


# ---------------------------------------------------------------- الصالة الرئيسية
func _lobby() -> void:
	b.zone = "lobby"
	# أرضية رخام فوق البلاطة
	b.slab(-14, -6, 14, 22, G + 0.02, "marble", 0.03, false)
	b.slab(-3.0, -2, 3.0, 22, G + 0.03, "marble_dark", 0.02, false)
	# الواجهة الزجاجية
	for i in 8:
		var x := -14.0 + i * 4.0
		b.box(Vector3(x, 4.8, 22), Vector3(0.5, 9.6, 0.6), "marble_dark", true, true)
	b.box(Vector3(0, 9.3, 22), Vector3(28, 0.6, 0.5), "marble_dark")
	b.box(Vector3(0, 3.3, 22), Vector3(28, 0.25, 0.3), "steel_dark", false)
	b.box(Vector3(0, 6.4, 22), Vector3(28, 0.15, 0.2), "steel_dark", false)
	for i in 7:
		var x0 := -14.0 + i * 4.0 + 0.25
		if i == 3:
			b.box(Vector3(x0 + 1.75, 6.3, 22), Vector3(3.5, 6.0, 0.08), "glass")
			continue
		b.box(Vector3(x0 + 1.75, 4.8, 22), Vector3(3.5, 9.4, 0.08), "glass")
	# السقف وثريات
	b.box(Vector3(0, 9.5, 8), Vector3(20, 0.2, 28), "plaster", false)
	for z in [2.0, 10.0, 18.0]:
		b.box(Vector3(0, 9.3, z), Vector3(5.0, 0.12, 1.6), "emit#fff2d6:3.0", false)
		b.light(Vector3(0, 7.6, z), Color(1.0, 0.94, 0.82), 2.4, 16.0)
	b.light(Vector3(-11.5, 3.6, 3.0), Color(1.0, 0.9, 0.75), 1.2, 9.0)
	b.light(Vector3(11.5, 3.6, 3.0), Color(1.0, 0.9, 0.75), 1.2, 9.0)
	# الأعمدة
	for sx in [-1.0, 1.0]:
		for z in [1.0, 8.0, 15.0]:
			b.box(Vector3(sx * 8.0, 0.3, z), Vector3(1.3, 0.6, 1.3), "marble_dark")
			b.cyl(Vector3(sx * 8.0, 0.6, z), Vector3(sx * 8.0, 9.2, z), 0.48, "marble", 14)
			b.box(Vector3(sx * 8.0, 9.35, z), Vector3(1.3, 0.3, 1.3), "marble_dark", false)
	# الدرج الكبير والشرفات
	for sx in [-1.0, 1.0]:
		b.stairs(Vector3(sx * 12.4, G, 20), Vector3(0, 0, -1), 2.4, 5.0, 9.0, "marble", "")
		b.box(Vector3(sx * 11.15, 3.05, 15.5), Vector3(0.1, 1.0, 10.3), "glass", true, false, Basis(Vector3.RIGHT, atan2(5.0, 9.0)))
		var xa: float = min(sx * 14.0, sx * 10.0)
		var xb: float = max(sx * 14.0, sx * 10.0)
		b.slab(xa, -6, xb, 11, U, "marble_dark", 0.4)
		# درابزين زجاجي
		b.box(Vector3(sx * 10.0, U + 0.55, 4.5), Vector3(0.08, 1.1, 13), "glass")
		b.box(Vector3(sx * 10.0, U + 1.12, 4.5), Vector3(0.12, 0.06, 13), "#c9a24a:0.3:0.9", false)
		b.box(Vector3(sx * 10.6, U + 0.55, 11), Vector3(1.2, 1.1, 0.08), "glass")
	b.slab(-10, -6, 10, -2, U, "marble_dark", 0.4)
	b.box(Vector3(0, U + 0.55, -2), Vector3(20, 1.1, 0.08), "glass")
	b.box(Vector3(0, U + 1.12, -2), Vector3(20, 0.06, 0.12), "#c9a24a:0.3:0.9", false)
	# كاونتر الصرافين
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 7.5, 0.55, -1.6), Vector3(9.0, 1.1, 0.9), "wood_dark")
		b.box(Vector3(sx * 7.5, 1.13, -1.6), Vector3(9.2, 0.06, 1.1), "marble")
		b.box(Vector3(sx * 7.5, 1.75, -1.9), Vector3(9.0, 1.2, 0.05), "glass", false)
		for k in 3:
			var cx: float = sx * (4.5 + k * 3.0)
			b.box(Vector3(cx, 1.35, -1.35), Vector3(0.5, 0.35, 0.06), "#111418:0.4", false)
			b.box(Vector3(cx, 1.35, -1.32), Vector3(0.44, 0.29, 0.01), "emit#3a78c2:1.2", false)
			b.box(Vector3(cx - 1.5, 2.2, -1.9), Vector3(0.08, 2.2, 0.08), "#c9a24a:0.3:0.9", false)
	b.label("بنك الاتحاد الوطني", Vector3(0, 7.4, -1.95), 0.0, 1.5, Color(0.86, 0.68, 0.25))
	b.label("الصرّافون", Vector3(-7.5, 3.9, -1.95), 0.0, 0.5, Color(0.9, 0.9, 0.85))
	b.label("خدمة العملاء", Vector3(7.5, 3.9, -1.95), 0.0, 0.5, Color(0.9, 0.9, 0.85))
	b.box(Vector3(0, 7.4, -2.05), Vector3(13, 2.2, 0.1), "#1b2a3a:0.6", false)
	# منطقة الانتظار
	for sx in [-1.0, 1.0]:
		for z in [6.0, 12.0]:
			_bench(Vector3(sx * 4.5, 0, z), 0.0)
		_plant(Vector3(sx * 9.6, 0, 20.0))
		_plant(Vector3(sx * 5.0, 0, -0.6))
		# حواجز الطابور
		for k in 4:
			b.cyl(Vector3(sx * 2.2, 0, 1.0 + k * 1.6), Vector3(sx * 2.2, 0.95, 1.0 + k * 1.6), 0.05, "#c9a24a:0.3:0.9", 8, false)
			if k < 3:
				b.box(Vector3(sx * 2.2, 0.85, 1.8 + k * 1.6), Vector3(0.04, 0.05, 1.6), "#7a1420:0.8", false)
	# مكتب الاستقبال الدائري
	b.cyl(Vector3(0, 0, 12), Vector3(0, 1.05, 12), 1.5, "wood_dark", 16)
	b.cyl(Vector3(0, 1.05, 12), Vector3(0, 1.12, 12), 1.65, "marble", 16, false)
	# لوحة قفل الأبواب
	b.box(Vector3(3.2, 1.4, 21.6), Vector3(0.5, 0.7, 0.12), "#20242a:0.5:0.5", false)
	b.box(Vector3(3.2, 1.5, 21.53), Vector3(0.34, 0.3, 0.02), "emit#33d17a:1.5", false)
	pts["lock_panel"] = Vector3(3.2, 1.4, 21.3)
	pts["lobby"] = Vector3(0, 0, 8)
	pts["lobby_door_in"] = Vector3(0, 0, 20)
	# رهائن الصالة
	hostage_spots = [[Vector3(-4.5, 0, 7.2), 0.0], [Vector3(4.5, 0, 7.2), 0.0], [Vector3(-4.5, 0, 13.2), PI], [Vector3(4.5, 0, 13.4), PI],
		[Vector3(-1.2, 0, 3.0), PI], [Vector3(1.4, 0, 4.5), PI], [Vector3(-6.0, 0, -3.6), 0.0], [Vector3(6.5, 0, -3.6), 0.0]]


func _bench(p: Vector3, yaw: float) -> void:
	var bs := Basis(Vector3.UP, yaw)
	b.box(p + Vector3(0, 0.42, 0), Vector3(2.6, 0.12, 0.7), "wood", true, false, bs)
	for sx in [-1.0, 1.0]:
		b.box(p + bs * Vector3(sx * 1.1, 0.2, 0), Vector3(0.1, 0.4, 0.6), "steel_dark", false, false, bs)


func _plant(p: Vector3) -> void:
	b.cyl(p, p + Vector3(0, 0.7, 0), 0.32, "#d8d2c4:0.6", 10, true, Color.WHITE, 0.42)
	for i in 7:
		var a := TAU * i / 7.0
		var d := Vector3(cos(a), 0, sin(a))
		b.box(p + Vector3(0, 1.25, 0) + d * 0.28, Vector3(0.1, 1.1, 0.34), "#2d6b3c:0.8", false, false, Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.38))
	b.box(p + Vector3(0, 1.5, 0), Vector3(0.12, 1.4, 0.3), "#3b8048:0.8", false)


func _desk(p: Vector3, yaw: float, pc := true) -> void:
	var bs := Basis(Vector3.UP, yaw)
	b.box(p + Vector3(0, 0.74, 0), Vector3(1.8, 0.06, 0.85), "wood", true, false, bs)
	b.box(p + bs * Vector3(-0.8, 0.36, 0), Vector3(0.06, 0.72, 0.8), "wood_dark", false, false, bs)
	b.box(p + bs * Vector3(0.8, 0.36, 0), Vector3(0.06, 0.72, 0.8), "wood_dark", false, false, bs)
	b.box(p + bs * Vector3(0, 0.45, -0.38), Vector3(1.6, 0.5, 0.04), "wood_dark", false, false, bs)
	if pc:
		b.box(p + bs * Vector3(0.2, 1.08, -0.15), Vector3(0.62, 0.38, 0.04), "#101216:0.4", false, false, bs)
		b.box(p + bs * Vector3(0.2, 1.08, -0.127), Vector3(0.56, 0.32, 0.01), "emit#5b8fd0:1.0", false, false, bs)
		b.box(p + bs * Vector3(0.2, 0.83, -0.15), Vector3(0.08, 0.14, 0.08), "#101216:0.4", false, false, bs)
		b.box(p + bs * Vector3(0.2, 0.78, 0.15), Vector3(0.45, 0.02, 0.15), "#1c1e22:0.5", false, false, bs)
	# كرسي
	var c := p + bs * Vector3(0, 0, 0.75)
	b.box(c + Vector3(0, 0.45, 0), Vector3(0.5, 0.08, 0.5), "#1c1f26:0.7", false, false, bs)
	b.box(c + bs * Vector3(0, 0.82, 0.24), Vector3(0.48, 0.7, 0.06), "#1c1f26:0.7", false, false, bs)
	b.cyl(c, c + Vector3(0, 0.42, 0), 0.04, "steel", 6, false)


func _crate(p: Vector3, s := 1.0, mat := "wood") -> void:
	b.box(p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), mat)
	b.box(p + Vector3(0, s * 0.5, 0), Vector3(s + 0.04, 0.08, s + 0.04), "wood_dark", false)


func _shelf(p: Vector3, yaw: float, w := 2.0, mat := "steel_dark") -> void:
	var bs := Basis(Vector3.UP, yaw)
	b.box(p + Vector3(0, 1.1, 0), Vector3(w, 2.2, 0.5), mat, true, false, bs)
	for i in 4:
		b.box(p + bs * Vector3(0, 0.35 + i * 0.5, 0.26), Vector3(w - 0.1, 0.04, 0.04), "steel", false, false, bs)


func _room_light(x: float, z: float, floor_y: float, col := Color(1.0, 0.96, 0.9), e := 1.5, rng := 11.0) -> void:
	b.box(Vector3(x, floor_y + H - 0.04, z), Vector3(1.6, 0.06, 0.5), "emit#fff6e4:2.6", false)
	b.light(Vector3(x, floor_y + H - 0.9, z), col, e, rng)


# ---------------------------------------------------------------- الأجنحة (أرضي)
func _wings_ground() -> void:
	for sx in [-1.0, 1.0]:
		b.zone = "wing_w" if sx < 0 else "wing_e"
		var xa: float = min(sx * 24.0, sx * 14.0)
		var xb: float = max(sx * 24.0, sx * 14.0)
		# الجدار بين الصالة والجناح (أرضي ثم علوي)
		b.wall_z(sx * 14.0, -6, 22, G, H, "plaster", [[-1.2, 1.2, 2.6], [7.0, 9.4, 2.6]])
		b.wall_z(sx * 14.0, -6, 22, U, R - 0.4, "plaster", [[1.0, 3.4, 2.6]])
		b.slab(xa, -6, xb, 22, U, "concrete", 0.4)
		# فاصل المكتب عن بهو الدرج
		var dx0: float = min(sx * 18.5, sx * 16.1)
		b.wall_x(6, xa, xb, G, H, "plaster", [[dx0, dx0 + 2.4, 2.6]])
		# درج القبو + درابزين
		b.stairs(Vector3(sx * 22.4, B, -4.5), Vector3(0, 0, 1), 2.4, 5.0, 9.0, "concrete", "")
		b.box(Vector3(sx * 21.2, G + 0.55, 0), Vector3(0.08, 1.1, 9.0), "steel_dark")
		b.box(Vector3(sx * 22.4, G + 0.55, -4.5), Vector3(2.4, 1.1, 0.08), "steel_dark")
		b.slab(xa, -6, xb, 6, G + 0.02, "terrazzo", 0.03, false)
		_room_light(sx * 18.0, 0.0, G)
		b.label("الخزنة ↓", Vector3(sx * 23.75, 2.6, 2.0), -sx * PI / 2, 0.45, Color(0.9, 0.75, 0.3))
		# المكتب
		b.slab(xa, 6, xb, 22, G + 0.02, "carpet_blue" if sx < 0 else "carpet", 0.03, false)
		_room_light(sx * 19.0, 10.0, G)
		_room_light(sx * 19.0, 17.5, G)
		if sx < 0:
			for z in [10.0, 14.0, 18.0]:
				_desk(Vector3(-21.0, 0, z), PI / 2)
			_shelf(Vector3(-15.0, 0, 16.0), PI / 2, 3.0, "wood_dark")
			_plant(Vector3(-15.2, 0, 20.8))
			b.label("خدمة كبار العملاء", Vector3(-14.25, 3.3, 8.2), -PI / 2, 0.35, Color(0.9, 0.9, 0.85))
		else:
			# صناديق الأمانات
			for z in [9.0, 12.0, 15.0, 18.0]:
				b.box(Vector3(23.4, 1.4, z), Vector3(0.7, 2.8, 2.6), "steel")
				for r in 5:
					for c in 4:
						b.box(Vector3(23.02, 0.4 + r * 0.5, z - 0.95 + c * 0.63), Vector3(0.04, 0.4, 0.52), "steel_dark", false)
			b.box(Vector3(18.5, 0.45, 14.0), Vector3(1.4, 0.9, 3.0), "wood_dark")
			b.label("صناديق الأمانات", Vector3(14.25, 3.3, 8.2), PI / 2, 0.35, Color(0.9, 0.9, 0.85))
	pts["office_w"] = Vector3(-19, 0, 14)
	pts["deposit"] = Vector3(19, 0, 14)
	pts["stairs_w_top"] = Vector3(-22.4, 0, 5.3)
	pts["stairs_e_top"] = Vector3(22.4, 0, 5.3)


# ---------------------------------------------------------------- الخلفية (أرضي)
func _back_ground() -> void:
	b.zone = "back"
	b.wall_x(-6, -24, 24, G, H, "plaster", [[-20.2, -17.8, 2.6], [-9.2, -6.8, 2.6], [6.8, 9.2, 2.6], [17.8, 20.2, 2.6]])
	b.wall_x(-10, -24, 24, G, H, "plaster", [[-17.2, -14.8, 2.6], [-1.2, 1.2, 2.6], [13.5, 18.5, 3.6]])
	b.wall_z(-8, -30, -10, G, H, "plaster")
	b.wall_z(8, -30, -10, G, H, "plaster")
	b.slab(-24, -30, 24, -6, U, "concrete", 0.4)
	b.slab(-24, -10, 24, -6, G + 0.02, "terrazzo", 0.03, false)
	for x in [-16.0, 0.0, 16.0]:
		_room_light(x, -8.0, G, Color(1, 0.97, 0.92), 1.2, 9.0)
	b.label("غرفة العدّ", Vector3(0, 3.0, -9.75), 0.0, 0.35, Color(0.9, 0.9, 0.85))
	b.label("استراحة الموظفين", Vector3(-16, 3.0, -9.75), 0.0, 0.35, Color(0.9, 0.9, 0.85))
	b.label("رصيف التحميل", Vector3(16, 4.0, -9.75), 0.0, 0.35, Color(0.9, 0.9, 0.85))
	# استراحة الموظفين
	b.zone = "staff"
	b.slab(-24, -30, -8, -10, G + 0.02, "woodfloor", 0.03, false)
	_room_light(-16, -17, G)
	_room_light(-16, -25, G)
	b.box(Vector3(-16, 0.4, -20), Vector3(2.4, 0.8, 1.2), "wood")
	for i in 5:
		b.box(Vector3(-23.3, 1.0, -14.0 - i * 1.0), Vector3(0.6, 2.0, 0.9), "#3d5a78:0.5:0.4")
	b.box(Vector3(-12.0, 0.45, -28.9), Vector3(6.0, 0.9, 0.9), "wood_dark")
	b.box(Vector3(-12.0, 0.93, -28.9), Vector3(6.1, 0.05, 1.0), "marble")
	b.box(Vector3(-20.0, 0.45, -24.0), Vector3(1.0, 0.9, 2.6), "#5a2d2d:0.9")
	# غرفة العدّ
	b.zone = "count"
	b.slab(-8, -30, 8, -10, G + 0.02, "tiles", 0.03, false)
	_room_light(-3, -18, G)
	_room_light(3, -25, G)
	for x in [-3.5, 3.5]:
		b.box(Vector3(x, 0.45, -19), Vector3(2.2, 0.9, 5.0), "steel")
		for k in 6:
			b.box(Vector3(x - 0.5 + (k % 2) * 1.0, 0.98, -20.8 + (k / 2) * 1.6), Vector3(0.7, 0.16, 0.4), "#3c7a4a:0.8", false)
	_shelf(Vector3(0, 0, -29.3), 0.0, 6.0)
	_shelf(Vector3(-7.3, 0, -24), PI / 2, 4.0)
	# رصيف التحميل
	b.zone = "dock"
	b.slab(8, -30, 24, -10, G + 0.02, "concrete_dark", 0.03, false)
	b.light(Vector3(16, 3.8, -20), Color(0.95, 0.97, 1.0), 2.0, 14.0)
	b.box(Vector3(16, H - 0.05, -20), Vector3(0.4, 0.06, 5.0), "emit#eef4ff:2.6", false)
	_van(Vector3(16, 0, -24.5), 0.0)
	_crate(Vector3(10.2, 0, -13), 1.2)
	_crate(Vector3(10.2, 1.2, -13), 0.9)
	_crate(Vector3(11.6, 0, -12.6), 1.0)
	_crate(Vector3(22.5, 0, -14), 1.3)
	_crate(Vector3(22.6, 0, -18), 1.0)
	_shelf(Vector3(23.4, 0, -24), PI / 2, 5.0)
	for i in 3:
		b.cyl(Vector3(9.0, 0, -18.0 - i * 1.3), Vector3(9.0, 1.2, -18.0 - i * 1.3), 0.45, "#2f5f8f:0.5:0.5", 12)
	pts["start"] = Vector3(13.2, 0, -22.5)
	pts["dock_exit"] = Vector3(16, 0, -11.5)
	pts["counting"] = Vector3(0, 0, -14)
	pts["staff"] = Vector3(-16, 0, -14)


func _van(p: Vector3, yaw: float) -> void:
	var bs := Basis(Vector3.UP, yaw)
	b.box(p + Vector3(0, 1.35, 0), Vector3(2.2, 2.0, 5.2), "#e8e8ea:0.4:0.2", true, false, bs)
	b.box(p + bs * Vector3(0, 0.95, -3.2), Vector3(2.2, 1.2, 1.3), "#e8e8ea:0.4:0.2", true, false, bs)
	b.box(p + bs * Vector3(0, 1.75, -2.75), Vector3(2.0, 0.75, 0.5), "#12161c:0.1:0.6", false, false, bs)
	b.box(p + bs * Vector3(0, 1.3, 2.61), Vector3(2.0, 1.7, 0.04), "#d0d0d4:0.4:0.2", false, false, bs)
	b.box(p + bs * Vector3(1.11, 1.5, 0.3), Vector3(0.02, 0.5, 3.4), "#1f6f78:0.6", false, false, bs)
	b.box(p + bs * Vector3(-1.11, 1.5, 0.3), Vector3(0.02, 0.5, 3.4), "#1f6f78:0.6", false, false, bs)
	for sx in [-1.0, 1.0]:
		for sz in [-2.4, 1.7]:
			b.cyl(p + bs * Vector3(sx * 0.95, 0.38, sz), p + bs * Vector3(sx * 1.15, 0.38, sz), 0.38, "#101012:0.9", 12, false)


# ---------------------------------------------------------------- الطابق العلوي
func _upper() -> void:
	b.zone = "upper_back"
	b.wall_x(-6, -24, 24, U, R - 0.4, "plaster", [[-20.2, -17.8, 2.6], [-7.2, -4.8, 2.6], [4.8, 7.2, 2.6], [17.8, 20.2, 2.6]])
	b.wall_x(-10, -24, 24, U, R - 0.4, "plaster", [[-17.2, -14.8, 2.6], [-1.2, 1.2, 2.6], [14.8, 17.2, 2.6]])
	b.wall_z(-8, -30, -10, U, R - 0.4, "plaster")
	b.wall_z(8, -30, -10, U, R - 0.4, "plaster")
	b.slab(-24, -10, 24, -6, U + 0.02, "carpet", 0.03, false)
	for x in [-16.0, 0.0, 16.0]:
		_room_light(x, -8.0, U, Color(1, 0.95, 0.88), 1.2, 9.0)
	b.label("المدير العام", Vector3(0, U + 3.0, -9.75), 0.0, 0.35, Color(0.86, 0.68, 0.25))
	b.label("غرفة الأمن والمراقبة", Vector3(16, U + 3.0, -9.75), 0.0, 0.35, Color(0.9, 0.4, 0.35))
	b.label("قاعة الاجتماعات", Vector3(-16, U + 3.0, -9.75), 0.0, 0.35, Color(0.9, 0.9, 0.85))
	# مكتب المدير
	b.zone = "manager"
	b.slab(-8, -30, 8, -10, U + 0.02, "woodfloor", 0.03, false)
	_room_light(0, -16, U, Color(1.0, 0.9, 0.75), 1.5)
	_room_light(0, -25, U, Color(1.0, 0.9, 0.75), 1.3)
	b.box(Vector3(0, U + 0.02, -22), Vector3(6, 0.03, 8), "carpet", false)
	b.box(Vector3(0, U + 0.4, -25.5), Vector3(3.2, 0.8, 1.4), "wood_dark")
	b.box(Vector3(0, U + 0.83, -25.5), Vector3(3.4, 0.06, 1.6), "marble_dark", false)
	b.box(Vector3(0.6, U + 1.15, -25.7), Vector3(0.7, 0.42, 0.04), "#101216:0.4", false)
	b.box(Vector3(0, U + 0.6, -27.3), Vector3(0.8, 1.2, 0.8), "#3a2420:0.6")
	_shelf(Vector3(-7.3, U, -20), PI / 2, 6.0, "wood_dark")
	_shelf(Vector3(7.3, U, -20), -PI / 2, 6.0, "wood_dark")
	b.box(Vector3(-4.5, U + 0.4, -13.5), Vector3(2.4, 0.8, 1.0), "#5a2d2d:0.9")
	b.box(Vector3(4.5, U + 0.4, -13.5), Vector3(2.4, 0.8, 1.0), "#5a2d2d:0.9")
	b.box(Vector3(0, U + 2.6, -29.75), Vector3(3.0, 1.8, 0.06), "#c9a24a:0.3:0.9", false)
	b.box(Vector3(0, U + 2.6, -29.71), Vector3(2.7, 1.5, 0.02), "#1b3a4a:0.7", false)
	_plant(Vector3(-6.8, U, -29.0))
	_plant(Vector3(6.8, U, -29.0))
	pts["manager_desk"] = Vector3(0, U, -23.6)
	pts["manager_spot"] = Vector3(0, U, -27.2)
	# غرفة الأمن
	b.zone = "security"
	b.slab(8, -30, 24, -10, U + 0.02, "tiles", 0.03, false)
	b.light(Vector3(16, U + 3.4, -20), Color(0.55, 0.75, 1.0), 1.5, 13.0)
	b.box(Vector3(16, U + 0.45, -28.6), Vector3(9.0, 0.9, 1.4), "#22262d:0.5:0.3")
	for i in 6:
		var mx := 12.0 + i * 1.6
		b.box(Vector3(mx, U + 1.75 + (i % 2) * 0.0, -29.6), Vector3(1.4, 0.9, 0.08), "#0c0e12:0.4", false)
		b.box(Vector3(mx, U + 1.75, -29.55), Vector3(1.3, 0.8, 0.02), "emit#%s:1.3" % ["2f6fa8", "3b8a6a", "2f6fa8", "8a6a3b", "3b8a6a", "2f6fa8"][i], false)
		b.box(Vector3(mx, U + 2.75, -29.6), Vector3(1.4, 0.9, 0.08), "#0c0e12:0.4", false)
		b.box(Vector3(mx, U + 2.75, -29.55), Vector3(1.3, 0.8, 0.02), "emit#%s:1.1" % ["3b8a6a", "2f6fa8", "8a6a3b", "2f6fa8", "2f6fa8", "3b8a6a"][i], false)
	for i in 4:
		b.box(Vector3(23.3, U + 1.1, -13.0 - i * 1.4), Vector3(0.9, 2.2, 1.0), "#15181d:0.5:0.5")
		b.box(Vector3(22.83, U + 1.5, -13.0 - i * 1.4), Vector3(0.02, 0.1, 0.6), "emit#33d17a:2.0", false)
	b.box(Vector3(9.2, U + 1.0, -20), Vector3(0.7, 2.0, 3.0), "steel_dark")
	b.label("خزانة السلاح", Vector3(9.6, U + 2.4, -20), PI / 2, 0.3, Color(0.9, 0.5, 0.3))
	pts["console"] = Vector3(16, U + 1.0, -27.7)
	pts["security_room"] = Vector3(16, U, -18)
	pts["gun_locker"] = Vector3(9.9, U + 1.0, -20)
	# قاعة الاجتماعات
	b.zone = "meeting"
	b.slab(-24, -30, -8, -10, U + 0.02, "carpet_blue", 0.03, false)
	_room_light(-16, -20, U)
	b.box(Vector3(-16, U + 0.72, -20), Vector3(3.0, 0.08, 9.0), "wood_dark")
	b.box(Vector3(-16, U + 0.36, -20), Vector3(1.2, 0.72, 6.0), "wood_dark", false)
	for i in 5:
		for sx in [-1.0, 1.0]:
			b.box(Vector3(-16 + sx * 2.1, U + 0.45, -23.6 + i * 1.8), Vector3(0.55, 0.9, 0.55), "#1c1f26:0.7")
	b.box(Vector3(-16, U + 2.4, -29.7), Vector3(5.0, 2.4, 0.06), "#e8e8e8:0.3", false)
	# الأجنحة العلوية
	for sx in [-1.0, 1.0]:
		b.zone = "upper_w" if sx < 0 else "upper_e"
		var xa: float = min(sx * 24.0, sx * 14.0)
		var xb: float = max(sx * 24.0, sx * 14.0)
		b.slab(xa, -6, xb, 22, U + 0.02, "carpet_blue" if sx < 0 else "tiles", 0.03, false)
		for z in [0.0, 9.0, 17.0]:
			_room_light(sx * 19.0, z, U)
		if sx < 0:
			for z in [-2.0, 3.0, 8.0, 13.0, 18.0]:
				_desk(Vector3(-21.5, U, z), PI / 2)
			for z in [8.0, 13.0, 18.0]:
				_desk(Vector3(-16.5, U, z), -PI / 2)
			b.label("إدارة الحسابات", Vector3(-14.25, U + 3.2, 2.2), -PI / 2, 0.35, Color(0.9, 0.9, 0.85))
		else:
			for z in [-3.0, 0.5, 9.0, 12.5, 16.0, 19.5]:
				b.box(Vector3(20.5, U + 1.1, z), Vector3(5.0, 2.2, 0.9), "#15181d:0.5:0.5")
				for k in 5:
					b.box(Vector3(18.4 + k * 1.0, U + 1.6, z + 0.46), Vector3(0.6, 0.06, 0.02), "emit#3aa0ff:1.6", false)
			b.label("الأرشيف والخوادم", Vector3(14.25, U + 3.2, 2.2), PI / 2, 0.35, Color(0.9, 0.9, 0.85))
	pts["balcony_n"] = Vector3(0, U, -4)
	pts["upper_corridor"] = Vector3(0, U, -8)


# ---------------------------------------------------------------- القبو
func _basement() -> void:
	b.zone = "bsm_lobby"
	var top := G - 0.4
	b.wall_x(-10, -24, 24, B, top, "concrete", [[-1.7, 1.7, 3.4]], 0.8)
	b.wall_z(-14, -10, 22, B, top, "concrete", [[-3.2, -0.8, 2.6]])
	b.wall_z(14, -10, 22, B, top, "concrete", [[-3.2, -0.8, 2.6]])
	b.wall_x(6, -24, 24, B, top, "concrete", [[-20.2, -17.8, 2.6], [-2.2, 2.2, 3.0], [17.8, 20.2, 2.6]])
	b.slab(-14, -10, 14, 6, B + 0.02, "tiles", 0.03, false)
	for x in [-8.0, 0.0, 8.0]:
		b.box(Vector3(x, top - 0.04, -2), Vector3(0.4, 0.06, 4.0), "emit#e8f2ff:2.8", false)
		b.light(Vector3(x, top - 1.0, -2), Color(0.85, 0.92, 1.0), 1.6, 11.0)
	# إطار الخزنة والشريط التحذيري
	b.box(Vector3(0, B + 1.7, -9.55), Vector3(4.4, 3.9, 0.3), "steel_dark", false)
	b.box(Vector3(0, B + 0.03, -8.2), Vector3(6.0, 0.02, 0.3), "#d8b020:0.7", false)
	b.label("الخزنة الرئيسية", Vector3(0, B + 4.0, -9.35), 0.0, 0.5, Color(0.9, 0.75, 0.3))
	b.label("منطقة محظورة", Vector3(0, B + 3.5, -9.35), 0.0, 0.25, Color(0.9, 0.3, 0.25))
	# مكتب الحراسة وحواجز
	b.box(Vector3(-8, B + 0.55, 2.5), Vector3(3.0, 1.1, 1.0), "#22262d:0.5:0.3")
	b.box(Vector3(8, B + 0.55, 2.5), Vector3(3.0, 1.1, 1.0), "#22262d:0.5:0.3")
	for x in [-4.5, 4.5]:
		b.box(Vector3(x, B + 0.6, -4.5), Vector3(1.6, 1.2, 0.5), "concrete_dark")
	for x in [-11.0, 11.0]:
		_crate(Vector3(x, B, -7.5), 1.2, "steel_dark")
		_crate(Vector3(x, B, 4.0), 1.0)
	pts["vault_door"] = Vector3(0, B, -8.6)
	pts["drill"] = Vector3(0, B + 1.2, -9.2)
	pts["vault_lobby"] = Vector3(0, B, -2)
	# الخزنة
	b.zone = "vault"
	b.wall_z(-10, -28, -10, B, top, "vault", [], 0.8)
	b.wall_z(10, -28, -10, B, top, "vault", [], 0.8)
	b.wall_x(-28, -10, 10, B, top, "vault", [], 0.8)
	b.slab(-10, -28, 10, -10, B + 0.02, "vault", 0.03, false)
	b.box(Vector3(0, top - 0.02, -19), Vector3(20, 0.04, 18), "steel_dark", false)
	for z in [-14.0, -22.0]:
		b.box(Vector3(0, top - 0.08, z), Vector3(6.0, 0.06, 0.5), "emit#fff0cc:3.0", false)
		b.light(Vector3(0, top - 1.2, z), Color(1.0, 0.88, 0.62), 2.2, 12.0)
	var gi := 0
	for gx in [-5.0, 0.0, 5.0]:
		for gz in [-16.0, -22.5]:
			_gold_pallet(Vector3(gx, B, gz))
			pts["gold%d" % gi] = Vector3(gx, B, gz + 1.3)
			gi += 1
	for z in [-13.0, -17.0, -21.0, -25.0]:
		for sx in [-1.0, 1.0]:
			b.box(Vector3(sx * 9.2, B + 1.4, z), Vector3(0.7, 2.8, 3.2), "steel")
			for r in 5:
				b.box(Vector3(sx * 8.83, B + 0.4 + r * 0.5, z), Vector3(0.03, 0.03, 3.0), "steel_dark", false)
	for x in [-6.0, 6.0]:
		b.box(Vector3(x, B + 0.5, -27.0), Vector3(3.0, 1.0, 0.9), "steel_dark")
		for k in 8:
			b.box(Vector3(x - 1.1 + (k % 4) * 0.72, B + 1.1 + (k / 4) * 0.18, -27.0), Vector3(0.6, 0.16, 0.34), "#3c7a4a:0.8", false)
	pts["vault"] = Vector3(0, B, -15)
	# البهوان الجانبيان
	for sx in [-1.0, 1.0]:
		b.zone = "bsm_w" if sx < 0 else "bsm_e"
		var xa: float = min(sx * 24.0, sx * 14.0)
		var xb: float = max(sx * 24.0, sx * 14.0)
		b.slab(xa, -10, xb, 6, B + 0.02, "concrete_dark", 0.03, false)
		b.light(Vector3(sx * 18.0, top - 1.0, -2.0), Color(1.0, 0.9, 0.7), 1.4, 10.0)
		b.box(Vector3(sx * 18.0, top - 0.04, -2.0), Vector3(1.2, 0.06, 0.3), "emit#ffe9b8:2.4", false)
		b.cyl(Vector3(sx * 15.0, top - 0.5, -9.5), Vector3(sx * 15.0, top - 0.5, 5.5), 0.12, "steel", 8, false)
	pts["stairs_w_bottom"] = Vector3(-22.4, B, -5.5)
	pts["stairs_e_bottom"] = Vector3(22.4, B, -5.5)
	# الكراج
	b.zone = "garage"
	b.slab(-14, 6, 14, 22, B + 0.02, "asphalt", 0.03, false)
	for x in [-7.0, 7.0]:
		b.light(Vector3(x, top - 0.8, 14), Color(1.0, 0.85, 0.6), 1.6, 12.0)
		b.box(Vector3(x, top - 0.04, 14), Vector3(0.3, 0.06, 3.0), "emit#ffdd99:2.4", false)
		for z in [10.0, 18.0]:
			b.box(Vector3(x, B + 2.3, z), Vector3(0.6, 4.6, 0.6), "concrete", true, true)
	for i in 5:
		b.box(Vector3(-11.0 + i * 5.5, B + 0.035, 19.0), Vector3(0.12, 0.01, 5.0), "#e8e8e8:0.8", false)
	_car(Vector3(-11.0, B, 18.5), 0.0, "#30343c:0.3:0.5")
	_car(Vector3(8.2, B, 18.5), 0.0, "#7a1a1a:0.3:0.5")
	_car(Vector3(-5.5, B, 9.5), PI / 2, "#d8d8dc:0.3:0.5")
	b.label("مخرج الكراج", Vector3(0, B + 3.9, 21.75), PI, 0.4, Color(0.3, 0.9, 0.4))
	pts["garage"] = Vector3(0, B, 12)
	pts["garage_spawn"] = Vector3(0, B, 20.5)
	# مخزن السلاح
	b.zone = "armory"
	b.slab(14, 6, 24, 22, B + 0.02, "concrete_dark", 0.03, false)
	b.light(Vector3(19, top - 0.9, 13), Color(0.8, 0.9, 1.0), 1.6, 11.0)
	b.box(Vector3(19, top - 0.04, 13), Vector3(0.3, 0.06, 4.0), "emit#e0ecff:2.6", false)
	_shelf(Vector3(23.4, B, 12), -PI / 2, 6.0)
	_shelf(Vector3(19, B, 21.4), PI, 6.0)
	b.box(Vector3(17.0, B + 0.45, 14.0), Vector3(1.2, 0.9, 3.0), "steel_dark")
	b.label("مخزن الحراسة", Vector3(19, B + 3.2, 6.25), 0.0, 0.3, Color(0.9, 0.5, 0.3))
	pts["armory"] = Vector3(19, B, 12)
	pts["armory_table"] = Vector3(17.0, B + 1.0, 14.0)
	# غرفة الميكانيك
	b.zone = "mech"
	b.slab(-24, 6, -14, 22, B + 0.02, "concrete_dark", 0.03, false)
	b.light(Vector3(-19, top - 0.9, 13), Color(1.0, 0.8, 0.5), 1.5, 11.0)
	b.box(Vector3(-19, top - 0.04, 13), Vector3(0.3, 0.06, 3.0), "emit#ffd699:2.4", false)
	for z in [8.5, 19.0]:
		b.cyl(Vector3(-15.5, B, z), Vector3(-15.5, B + 3.0, z), 0.9, "steel_dark", 14)
	b.cyl(Vector3(-23.0, B + 3.6, 6.5), Vector3(-23.0, B + 3.6, 11.5), 0.25, "steel", 10, false)
	b.cyl(Vector3(-16.0, B + 3.9, 7.0), Vector3(-16.0, B + 3.9, 21.5), 0.18, "#8a3a2a:0.5:0.6", 10, false)
	_crate(Vector3(-22.5, B, 19.5), 1.2)
	_crate(Vector3(-21.2, B, 20.5), 0.9)
	b.label("غرفة المضخات", Vector3(-19, B + 3.2, 6.25), 0.0, 0.3, Color(0.9, 0.9, 0.85))
	pts["mech"] = Vector3(-19, B, 12)
	pts["tunnel_mouth"] = Vector3(-22.5, B, 14)


func _gold_pallet(p: Vector3) -> void:
	b.box(p + Vector3(0, 0.08, 0), Vector3(1.6, 0.16, 1.2), "wood")
	for layer in 4:
		var n := 5 - layer
		for i in n:
			for j in 2:
				b.box(p + Vector3((i - (n - 1) / 2.0) * 0.3, 0.23 + layer * 0.13, (j - 0.5) * 0.5), Vector3(0.27, 0.12, 0.44), "gold", false)
	b.collider(p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.2))


func _car(p: Vector3, yaw: float, paint: String, police := false) -> void:
	var bs := Basis(Vector3.UP, yaw)
	b.box(p + Vector3(0, 0.62, 0), Vector3(1.85, 0.6, 4.4), paint, true, false, bs)
	b.box(p + bs * Vector3(0, 1.17, 0.2), Vector3(1.65, 0.55, 2.2), "#10141a:0.1:0.7", true, false, bs)
	b.box(p + bs * Vector3(0, 1.46, 0.2), Vector3(1.6, 0.05, 2.0), paint, false, false, bs)
	for sx in [-1.0, 1.0]:
		for sz in [-1.45, 1.45]:
			b.cyl(p + bs * Vector3(sx * 0.8, 0.34, sz), p + bs * Vector3(sx * 0.96, 0.34, sz), 0.34, "#101012:0.9", 12, false)
		b.box(p + bs * Vector3(sx * 0.7, 0.72, -2.21), Vector3(0.35, 0.14, 0.03), "emit#fff4d0:1.5", false, false, bs)
		b.box(p + bs * Vector3(sx * 0.7, 0.72, 2.21), Vector3(0.35, 0.12, 0.03), "emit#c01818:1.2", false, false, bs)
	if police:
		b.box(p + bs * Vector3(0, 0.62, 0), Vector3(1.87, 0.25, 2.0), "#f0f0f2:0.4", false, false, bs)
		b.box(p + bs * Vector3(-0.35, 1.55, 0.2), Vector3(0.5, 0.14, 0.3), "emit#2050ff:3.0", false, false, bs)
		b.box(p + bs * Vector3(0.35, 1.55, 0.2), Vector3(0.5, 0.14, 0.3), "emit#ff2020:3.0", false, false, bs)


# ---------------------------------------------------------------- نفق الهروب
func _tunnel() -> void:
	b.zone = "tunnel"
	var top := B + 3.0
	# الممر الأول غرباً
	b.slab(-61.5, 12.5, -24, 15.5, B, "concrete_dark", 0.4)
	b.slab(-61.5, 12.1, -24, 15.9, top + 0.4, "concrete_dark", 0.4)
	b.wall_x(15.7, -61.5, -24.2, B, top, "bricks")
	b.wall_x(12.3, -58.0, -24.2, B, top, "bricks")
	# الممر الثاني شمالاً
	b.slab(-61.5, -40, -58, 12.5, B, "concrete_dark", 0.4)
	b.slab(-61.9, -40, -57.6, 12.5, top + 0.4, "concrete_dark", 0.4)
	b.wall_z(-61.7, -40, 15.9, B, top, "bricks")
	b.wall_z(-57.8, -40, 12.1, B, top, "bricks")
	for i in 5:
		var x := -30.0 - i * 7.0
		b.light(Vector3(x, top - 0.4, 14), Color(1.0, 0.6, 0.3), 1.3, 7.0)
		b.box(Vector3(x, top - 0.1, 14), Vector3(0.25, 0.12, 0.25), "emit#ffb060:3.0", false)
		b.box(Vector3(x - 3.5, B + 1.5, 12.55), Vector3(0.25, 3.0, 0.25), "wood_dark", false)
		b.box(Vector3(x - 3.5, B + 1.5, 15.45), Vector3(0.25, 3.0, 0.25), "wood_dark", false)
		b.box(Vector3(x - 3.5, top - 0.12, 14), Vector3(0.25, 0.25, 3.0), "wood_dark", false)
	for i in 7:
		var z := 6.0 - i * 7.0
		b.light(Vector3(-59.75, top - 0.4, z), Color(1.0, 0.6, 0.3), 1.3, 7.0)
		b.box(Vector3(-59.75, top - 0.1, z), Vector3(0.25, 0.12, 0.25), "emit#ffb060:3.0", false)
	_crate(Vector3(-42, B, 13.2), 1.0)
	_crate(Vector3(-50, B, 14.8), 1.0)
	_crate(Vector3(-60.8, B, -8), 1.0)
	_crate(Vector3(-58.8, B, -22), 1.0)
	# القناة المكشوفة والشاحنة
	b.zone = "canal"
	b.slab(-72, -62, -48, -40, B, "concrete", 0.5)
	b.wall_x(-40, -72, -48, B, B + 7.0, "concrete", [[-61.5, -58.0, 3.0]], 0.6)
	b.wall_x(-62, -72, -48, B, B + 7.0, "concrete", [], 0.6)
	b.wall_z(-72, -62, -40, B, B + 7.0, "concrete", [], 0.6)
	b.wall_z(-48, -62, -40, B, B + 7.0, "concrete", [], 0.6)
	b.light(Vector3(-60, B + 5.0, -50), Color(0.7, 0.8, 1.0), 2.2, 18.0)
	_van(Vector3(-64, B, -52), PI / 2)
	_crate(Vector3(-54, B, -46), 1.3)
	_crate(Vector3(-52, B, -56), 1.2)
	_crate(Vector3(-56, B, -57), 1.0)
	b.cyl(Vector3(-69, B, -44), Vector3(-69, B + 1.2, -44), 0.5, "#2f5f8f:0.5:0.5", 12)
	pts["tunnel_mid"] = Vector3(-59.75, B, 10)
	pts["canal"] = Vector3(-59.75, B, -44)
	pts["truck"] = Vector3(-60.5, B, -51.5)


# ---------------------------------------------------------------- الشارع
func _exterior() -> void:
	b.zone = "ext"
	b.slab(-60, 22.4, 60, 31, G - 0.02, "paving", 0.4)
	b.slab(-80, 31, 80, 46, G - 0.15, "asphalt", 0.4)
	b.slab(-80, 46, 80, 52, G - 0.02, "paving", 0.4)
	for i in 3:
		b.box(Vector3(0, -0.12 + i * 0.0, 23.2 + i * 0.5), Vector3(10, 0.2, 0.5), "marble_dark", false)
	for i in 12:
		b.box(Vector3(-66.0 + i * 12.0, G - 0.14, 38.5), Vector3(4.0, 0.01, 0.2), "#e8e8e8:0.8", false)
	# واجهة البنك الخارجية
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 19.0, 5.0, 22.35), Vector3(10.0, 10.0, 0.3), "marble", false)
		for k in 3:
			b.box(Vector3(sx * (16.0 + k * 3.0), 6.5, 22.52), Vector3(1.6, 4.0, 0.06), "#1a2430:0.1:0.6", false)
	b.box(Vector3(0, 10.6, 22.2), Vector3(49, 1.2, 0.8), "marble_dark", false)
	b.label("بنك الاتحاد الوطني", Vector3(0, 10.6, 22.65), 0.0, 0.9, Color(0.86, 0.68, 0.25))
	# مبانٍ مقابلة
	var seeds := [[-62.0, 26.0, 22.0], [-36.0, 34.0, 20.0], [-12.0, 22.0, 24.0], [14.0, 40.0, 22.0], [40.0, 28.0, 24.0], [66.0, 36.0, 22.0]]
	for s in seeds:
		b.box(Vector3(s[0], s[1] / 2.0, 52.0 + s[2] / 2.0), Vector3(22.0, s[1], s[2]), "facade", false)
	b.box(Vector3(-52, 9, 0), Vector3(20, 18, 50), "facade", false)
	b.box(Vector3(52, 12, 0), Vector3(20, 24, 50), "facade", false)
	# سيارات الشرطة والحواجز
	_car(Vector3(-9, G - 0.15, 34.5), 0.5, "#16203a:0.3:0.5", true)
	_car(Vector3(8, G - 0.15, 35.0), -0.4, "#16203a:0.3:0.5", true)
	_car(Vector3(0, G - 0.15, 40.0), PI / 2, "#16203a:0.3:0.5", true)
	for x in [-14.0, -5.0, 4.5, 13.0]:
		b.box(Vector3(x, 0.5, 30.0), Vector3(2.4, 1.0, 0.4), "#d8d8d8:0.7")
		b.box(Vector3(x, 0.8, 29.79), Vector3(2.4, 0.2, 0.02), "#c02020:0.7", false)
	for x in [-30.0, -18.0, 18.0, 30.0]:
		b.cyl(Vector3(x, 0, 30.5), Vector3(x, 6.0, 30.5), 0.1, "steel_dark", 8, false)
		b.box(Vector3(x, 6.0, 31.2), Vector3(0.3, 0.12, 1.6), "emit#ffe2a8:3.0", false)
	for i in 2:
		var l := OmniLight3D.new()
		l.position = Vector3(-9.0 + i * 17.0, 2.4, 34.5)
		l.light_color = Color(0.2, 0.35, 1.0) if i == 0 else Color(1.0, 0.15, 0.15)
		l.omni_range = 26.0
		l.light_energy = 0.0
		add_child(l)
		police_lights.append(l)
	pts["street"] = Vector3(0, 0, 33)


# ---------------------------------------------------------------- البوابات المتحركة
func _gate(name_: String, center: Vector3, size: Vector3, mat: String) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 32
	body.collision_mask = 0
	body.position = center
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = Mats.get_mat(mat)
	mi.mesh = bm
	body.add_child(mi)
	add_child(body)
	gates[name_] = body
	return body


func _gates() -> void:
	# باب الخزنة الدائري
	var vd := _gate("vault", Vector3(0, B + 1.7, -10.0), Vector3(3.4, 3.4, 0.7), "steel_dark")
	var gb := Builder.new(vd)
	gb.cyl(Vector3(0, 0, 0.36), Vector3(0, 0, 0.6), 1.55, "steel", 24, false)
	gb.cyl(Vector3(0, 0, 0.6), Vector3(0, 0, 0.72), 0.5, "steel_dark", 16, false)
	for i in 6:
		var a := TAU * i / 6.0
		gb.box(Vector3(cos(a) * 0.55, sin(a) * 0.55, 0.78), Vector3(0.9, 0.09, 0.09), "#c9a24a:0.3:0.9", false, false, Basis(Vector3.BACK, a))
	for i in 12:
		var a2 := TAU * i / 12.0
		gb.cyl(Vector3(cos(a2) * 1.3, sin(a2) * 1.3, 0.6), Vector3(cos(a2) * 1.3, sin(a2) * 1.3, 0.68), 0.09, "steel_dark", 8, false)
	gb.commit()
	# سدّ فتحة النفق
	var tp := _gate("tunnel", Vector3(-24.0, B + 1.4, 14.0), Vector3(0.5, 2.8, 3.0), "concrete")
	tp.set_meta("hint", true)
	# باب الصالة الرئيسي
	_gate("front", Vector3(0, 1.65, 22.0), Vector3(3.5, 3.3, 0.1), "glass")
	# باب الكراج
	_gate("garage", Vector3(0, B + 1.7, 22.0), Vector3(7.0, 3.4, 0.3), "steel_dark")
	# حاجز يمنع اللاعب من الخروج للشارع
	var blk := StaticBody3D.new()
	blk.collision_layer = 16
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6, 6, 0.5)
	cs.shape = bs
	blk.add_child(cs)
	blk.position = Vector3(0, 3, 22.6)
	add_child(blk)
	# أضواء الإنذار
	for p in [Vector3(0, 8.5, 20), Vector3(0, 4.0, -8), Vector3(0, B + 3.8, 2), Vector3(0, U + 4.0, -8)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.1, 0.05)
		l.omni_range = 16.0
		l.light_energy = 0.0
		add_child(l)
		alarm_lights.append(l)


func open_gate(n: String, instant := false) -> void:
	if not gates.has(n) or not is_instance_valid(gates[n]):
		return
	var g: Node3D = gates[n]
	gates.erase(n)
	g.collision_layer = 0
	if instant:
		g.queue_free()
		return
	var tw := create_tween()
	match n:
		"vault":
			tw.tween_property(g, "position", g.position + Vector3(0, 0, 0.9), 1.2)
			tw.tween_property(g, "position", g.position + Vector3(3.6, 0, 0.9), 2.2).set_trans(Tween.TRANS_SINE)
		"tunnel":
			tw.tween_property(g, "position", g.position + Vector3(0, -3.2, 0), 0.6)
		_:
			tw.tween_property(g, "position", g.position + Vector3(0, 3.6, 0), 1.2)
	Audio.play_at("door", g.global_position, 3.0, 0.7)


func _nav() -> void:
	nav = NavigationRegion3D.new()
	add_child(nav)
	var nm: NavigationMesh
	if ResourceLoader.exists("res://nav/bank_nav.res") and not Game.test_mode:
		nm = load("res://nav/bank_nav.res")
	else:
		nm = bake_nav()
	nav.navigation_mesh = nm


func bake_nav() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.2
	nm.cell_height = 0.2
	nm.region_min_size = 8.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.filter_baking_aabb = AABB(Vector3(-74, -6, -64), Vector3(100, 17, 88))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	return nm


func set_police(on: bool) -> void:
	police_on = on


func set_alarm(on: bool) -> void:
	alarm_on = on
	if not on:
		for l in alarm_lights:
			l.light_energy = 0.0


func _process(delta: float) -> void:
	_t += delta
	if police_on:
		var ph := fmod(_t * 2.2, 1.0)
		police_lights[0].light_energy = 3.0 if ph < 0.5 else 0.0
		police_lights[1].light_energy = 0.0 if ph < 0.5 else 3.0
	if alarm_on:
		var e: float = 1.6 * max(0.0, sin(_t * 5.0))
		for l in alarm_lights:
			l.light_energy = e
