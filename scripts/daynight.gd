class_name DayNight
extends Node3D
## دورة الليل والنهار: شمس، سماء، ضباب، وإضاءة المدينة.

const DAY_LENGTH := 600.0   # ثواني لليوم الكامل

var hour := 9.0
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var _acc := 10.0

# [ساعة، أعلى السماء، الأفق، لون الشمس، قوة الشمس، المحيط، قوة المحيط]
const KEYS := [
	[0.0, "070b1c", "111c38", "9fb4ff", 0.4, "4a5a90", 0.8],
	[4.8, "080c1e", "14203c", "9fb4ff", 0.4, "4a5a90", 0.8],
	[6.2, "3a5a98", "f0a070", "ffb070", 0.7, "8a7a80", 0.6],
	[8.0, "2f76d2", "b4d2ee", "fff0d8", 1.15, "a8b8cc", 0.62],
	[16.0, "2f76d2", "b4d2ee", "fff0d8", 1.15, "a8b8cc", 0.62],
	[18.2, "40508c", "ff8a4a", "ff8040", 0.75, "9a7870", 0.6],
	[19.6, "141a38", "50385a", "8090e0", 0.4, "4a4a78", 0.75],
	[21.0, "070b1c", "111c38", "9fb4ff", 0.4, "4a5a90", 0.8],
	[24.0, "070b1c", "111c38", "9fb4ff", 0.4, "4a5a90", 0.8],
]


func _ready() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.3
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	add_child(sun)
	apply_quality()
	_update(true)


func apply_quality() -> void:
	var q: int = Game.settings["quality"]
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 80.0 if q == 1 else 150.0
	env.glow_enabled = q >= 1
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
	vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else Viewport.MSAA_2X


func _process(delta: float) -> void:
	if Game.state == Game.State.PLAYING:
		hour = fmod(hour + delta * 24.0 / DAY_LENGTH, 24.0)
	_acc += delta
	if _acc > 0.5:
		_acc = 0.0
		_update(false)


func _update(_force: bool) -> void:
	var a = KEYS[0]
	var b = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t: float = (hour - a[0]) / max(0.001, b[0] - a[0])
	var top := Color(a[1]).lerp(Color(b[1]), t)
	var hor := Color(a[2]).lerp(Color(b[2]), t)
	var sc := Color(a[3]).lerp(Color(b[3]), t)
	var se: float = lerp(a[4], b[4], t)
	var amb := Color(a[5]).lerp(Color(b[5]), t)
	var ae: float = lerp(a[6], b[6], t)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.4)
	env.ambient_light_color = amb
	env.ambient_light_energy = ae
	env.fog_light_color = hor.lerp(top, 0.3)
	sun.light_color = sc
	sun.light_energy = se
	# زاوية الشمس (نهاراً) أو القمر (ليلاً)
	var day := hour > 5.5 and hour < 19.0
	var ang: float
	if day:
		ang = (hour - 5.5) / 13.5 * PI
	else:
		var h2 := hour - 19.0 if hour >= 19.0 else hour + 5.0
		ang = h2 / 10.5 * PI
	var elev: float = max(0.16, sin(ang))
	sun.rotation = Vector3(-asin(clamp(elev * 0.92, 0.0, 1.0)), 0.6 + cos(ang) * 1.1, 0)
	var n := 0.0
	if hour < 5.0 or hour > 20.5:
		n = 1.0
	elif hour < 7.0:
		n = 1.0 - (hour - 5.0) / 2.0
	elif hour > 17.8:
		n = (hour - 17.8) / 2.7
	Game.night = clamp(n, 0.0, 1.0)
	if Game.city:
		Game.city.set_night(Game.night)
	Car.set_night(Game.night)


func clock_text() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]
