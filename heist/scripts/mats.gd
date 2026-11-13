class_name Mats
extends RefCounted
## مكتبة الخامات: خامات حقيقية (لون + نتوء + خشونة) وألوان سادة ومضيئة.

static var _c := {}

## اسم الخامة -> [ملف، حجم التكرار بالمتر، معدنية، لون ضرب]
const DEFS := {
	"marble": ["marble", 3.0, 0.0, Color(1, 1, 1)],
	"marble_dark": ["marble2", 3.0, 0.0, Color(0.55, 0.55, 0.6)],
	"woodfloor": ["woodfloor", 2.5, 0.0, Color(1, 1, 1)],
	"wood": ["wood", 1.6, 0.0, Color(0.85, 0.75, 0.7)],
	"wood_dark": ["wood", 1.6, 0.0, Color(0.42, 0.3, 0.26)],
	"concrete": ["concrete", 3.0, 0.0, Color(0.8, 0.8, 0.8)],
	"concrete_dark": ["concrete", 3.0, 0.0, Color(0.45, 0.46, 0.48)],
	"vault": ["vault", 2.0, 0.85, Color(0.8, 0.82, 0.86)],
	"carpet": ["carpet", 2.0, 0.0, Color(0.55, 0.2, 0.2)],
	"carpet_blue": ["carpet", 2.0, 0.0, Color(0.2, 0.28, 0.45)],
	"plaster": ["plaster", 3.0, 0.0, Color(0.93, 0.9, 0.84)],
	"plaster_green": ["plaster", 3.0, 0.0, Color(0.55, 0.63, 0.58)],
	"plaster_grey": ["plaster", 3.0, 0.0, Color(0.6, 0.62, 0.66)],
	"tiles": ["tiles", 2.0, 0.0, Color(0.9, 0.9, 0.9)],
	"asphalt": ["asphalt", 4.0, 0.0, Color(0.7, 0.7, 0.7)],
	"bricks": ["bricks", 2.5, 0.0, Color(0.9, 0.9, 0.9)],
	"gold": ["gold", 1.0, 1.0, Color(1.0, 0.86, 0.5)],
	"steel": ["steel", 1.5, 0.9, Color(0.75, 0.77, 0.8)],
	"steel_dark": ["steel", 1.5, 0.8, Color(0.3, 0.31, 0.34)],
	"terrazzo": ["terrazzo", 2.5, 0.0, Color(0.95, 0.95, 0.95)],
	"paving": ["paving", 3.0, 0.0, Color(0.85, 0.85, 0.85)],
}


static func get_mat(n: String) -> Material:
	if _c.has(n):
		return _c[n]
	var m: StandardMaterial3D
	if DEFS.has(n):
		var d: Array = DEFS[n]
		m = StandardMaterial3D.new()
		m.albedo_texture = load("res://tex/%s_c.jpg" % d[0])
		m.albedo_color = d[3]
		m.vertex_color_use_as_albedo = true
		m.metallic = d[2]
		m.roughness = 1.0
		m.roughness_texture = load("res://tex/%s_r.jpg" % d[0])
		if Game.settings["quality"] > 0:
			m.normal_enabled = true
			m.normal_texture = load("res://tex/%s_n.jpg" % d[0])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	elif n.begins_with("#"):
		# لون سادة: "#rrggbb" أو "#rrggbb:rough:metal"
		var p := n.split(":")
		m = StandardMaterial3D.new()
		m.albedo_color = Color(p[0])
		m.vertex_color_use_as_albedo = true
		m.roughness = float(p[1]) if p.size() > 1 else 0.7
		m.metallic = float(p[2]) if p.size() > 2 else 0.0
	elif n.begins_with("emit"):
		# "emit#rrggbb:energy"
		var p2 := n.substr(4).split(":")
		m = StandardMaterial3D.new()
		m.albedo_color = Color(p2[0])
		m.emission_enabled = true
		m.emission = Color(p2[0])
		m.emission_energy_multiplier = float(p2[1]) if p2.size() > 1 else 2.0
	elif n == "glass":
		m = StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.75, 0.8, 0.22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.3
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif n == "facade":
		m = StandardMaterial3D.new()
		m.albedo_texture = load("res://tex/facade.jpg")
		m.emission_enabled = true
		m.emission_texture = load("res://tex/facade_e.jpg")
		m.emission_energy_multiplier = 1.4
		m.roughness = 0.6
	else:
		m = StandardMaterial3D.new()
		m.albedo_color = Color.MAGENTA
	_c[n] = m
	return m


static func uv_size(n: String) -> float:
	if DEFS.has(n):
		return DEFS[n][1]
	if n == "facade":
		return 12.0
	return 1.0


static func reset() -> void:
	_c.clear()
