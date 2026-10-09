extends SceneTree
## Measures CreatorRenderer cost (needs a display): every creator template drawn at house scale,
## redrawn every frame for 120 frames, plus one hero-size portrait.
##   godot --path . --script res://tests/visual/render_benchmark.gd

var _usec := 0
var _frames := 0


class Stage extends Node2D:
	var specs: Array = []
	var bench: Object
	var t := 0.0
	var warmup := 20

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var start := Time.get_ticks_usec()
		for i in specs.size():
			CreatorRenderer.draw(self, specs[i], ["idle", "walk", "film", "selfie"][i % 4], t + i, Vector2(80 + i * 140, 300), 1.0, 1.0)
		CreatorRenderer.draw(self, specs[0], "showcase", t, Vector2(1100, 690), 1.0, 3.6)
		warmup -= 1
		if warmup < 0: # skip the frames that bake cached layers
			bench.set("_usec", int(bench.get("_usec")) + Time.get_ticks_usec() - start)
			bench.set("_frames", int(bench.get("_frames")) + 1)


func _initialize() -> void:
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var stage := Stage.new()
	stage.bench = self
	for template_id in config.creator_order:
		stage.specs.append(Appearance.render_spec(CreatorSetup.create(config.creator_templates[template_id], config, state), config))
	root.add_child(stage)
	for i in 130:
		await process_frame
	print("%d sprites + 1 portrait: %.2f ms per frame (avg over %d frames)" % [stage.specs.size(), _usec / 1000.0 / maxi(_frames, 1), _frames])
	quit()
