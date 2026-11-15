extends Node
## Renderer truth: Android ships the Mobile renderer, desktop runs Forward+,
## and Quality.p promises only what the active renderer draws.
## tools/run_tests.py runs this scene once per shipped renderer
## ("--rendering-method <m> -- --expect-renderer=<m>"); headless Godot keeps
## the requested method's name, so the phone path is exercised on a desktop.

## The shipped decision. Changing it means re-profiling the target phones
## (README, "Profiling on the target phones") and updating the docs with it.
const SHIPPED := {
	"rendering/renderer/rendering_method": "forward_plus",
	"rendering/renderer/rendering_method.mobile": "mobile",
}
const ENV_FLAGS := {"ssao": "ssao_enabled", "sdfgi": "sdfgi_enabled", "vol_fog": "volumetric_fog_enabled"}

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	var sound_before := Sfx.enabled
	Sfx.enabled = false
	var expected := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--expect-renderer="):
			expected = a.substr(18)
	var renderer := Quality.renderer
	var forward := renderer == "forward_plus"
	check(expected == "" or renderer == expected, "requested renderer %s is the one running (%s)" % [expected, renderer])
	check(renderer == RenderingServer.get_current_rendering_method(), "Quality names the renderer that is running")
	for key in SHIPPED:
		check(str(ProjectSettings.get_setting(key)) == SHIPPED[key], "shipped renderer decision: %s = %s" % [key, SHIPPED[key]])
	var share := 0
	for key in Quality.MESH_OMNI_SHARE:
		share += int(Quality.MESH_OMNI_SHARE[key])
	check(share == Quality.OMNI_LIGHTS_PER_MESH, "lamp and combat shares fill the per-mesh omni limit exactly")
	var immutable := JSON.stringify(Quality.PRESETS)
	var sky := SkyEnv.new()
	add_child(sky)
	for preset in ["low", "medium", "high"]:
		Quality.set_preset(preset)
		var want: Dictionary = Quality.PRESETS[preset]
		for stage in 4:
			Quality.set_pressure_stage(stage)
			var where := "%s %s stage %d" % [renderer, preset, stage]
			budget_checks(want, stage, forward, where)
			for env_id in ["day", "rain"]:
				sky.apply(env_id)
				sky_checks(sky, env_id == "rain", forward, where + " " + env_id)
			# A weather transition rewrites SSR every frame; it must obey too.
			sky.transition_to("day", 1.0)
			sky.advance(0.5)
			check(sky.wet > 0.05 and sky.env.ssr_enabled == bool(Quality.p.ssr), "mid-transition reflections follow the budget: " + where)
			sky.advance(1.0)
	Quality.set_preset("medium")
	var snap := Quality.snapshot()
	check(str(snap.get("renderer", "")) == renderer, "profile budget names the renderer")
	for key in Quality.FORWARD_PLUS_ONLY:
		check(snap.has(key) and bool(snap[key]) == bool(Quality.p[key]), "profile budget reports effective " + key)
	check(int(snap.get("lamp_lights", -1)) == int(Quality.p.lamp_lights), "profile budget reports street lights")
	sky.queue_free()
	var menu := Menu.new()
	add_child(menu)
	var garage: Environment = null
	for child in menu.get_children():
		if child is WorldEnvironment:
			garage = child.environment
	check(garage != null and garage.ssao_enabled == bool(Quality.p.ssao), "garage occlusion follows the budget")
	check(forward or garage == null or not garage.ssao_enabled, "garage requests no Forward+ effect on " + renderer)
	menu.queue_free()
	await get_tree().process_frame
	check(JSON.stringify(Quality.PRESETS) == immutable, "renderer limits never rewrite the preset definitions")
	Quality.set_preset(Settings.quality)
	Sfx.stop_all()
	Sfx.enabled = sound_before
	print("RENDERER TRUTH: renderer=%s; presets, pressure, sky, transitions, garage and profile budget; failures=%d" % [renderer, failures])
	get_tree().quit(1 if failures else 0)

func budget_checks(want: Dictionary, stage: int, forward: bool, where: String) -> void:
	var p := Quality.p
	for key in Quality.FORWARD_PLUS_ONLY:
		check(p.has(key), "budget defines %s: %s" % [key, where])
		check(forward or not bool(p.get(key, false)), "%s is never promised outside Forward+: %s" % [key, where])
	if forward:
		if stage == 0:
			for key in ["ssao", "sdfgi", "ssr", "vol_fog", "lamp_lights"]:
				check(p[key] == want[key], "unpressured Forward+ delivers the preset's %s: %s" % [key, where])
			check(bool(p.sun_penumbra) == (Quality.preset == "high"), "soft sun shadows belong to unpressured high: " + where)
	else:
		check(int(p.lamp_lights) + int(p.fx_light_limit) <= Quality.OMNI_LIGHTS_PER_MESH, "street and combat lights fit one mesh: " + where)
	for wet in [false, true]:
		var env := Environment.new()
		Quality.apply_env(env, wet)
		for key in ENV_FLAGS:
			check(bool(env.get(ENV_FLAGS[key])) == bool(p[key]), "environment %s follows the budget: %s" % [key, where])
		check(env.ssr_enabled == (bool(p.ssr) and wet), "reflections need a wet road and the budget: " + where)

func sky_checks(sky: SkyEnv, dark_and_wet: bool, forward: bool, where: String) -> void:
	var p := Quality.p
	var env := sky.env
	check(env.ssao_enabled == bool(p.ssao) and env.sdfgi_enabled == bool(p.sdfgi), "sky occlusion and GI follow the budget: " + where)
	check(env.ssr_enabled == (bool(p.ssr) and dark_and_wet), "sky reflections follow the budget: " + where)
	check(env.volumetric_fog_enabled == (bool(p.vol_fog) and dark_and_wet), "volumetric fog is a budgeted night effect: " + where)
	check((sky.sun.light_angular_distance > 0.0) == bool(p.sun_penumbra), "sun penumbra follows the budget: " + where)
	if not forward:
		check(not (env.ssao_enabled or env.sdfgi_enabled or env.ssr_enabled or env.volumetric_fog_enabled)
			and sky.sun.light_angular_distance == 0.0, "sky requests no Forward+ effect: " + where)
