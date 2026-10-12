extends SceneTree

# Run with --headless --path . --script res://tests/smoke_test.gd.
# Repeat with --main-pack Builds/fixed-web/index.pck to check exported paths.
const MENU := "res://Scenes/actors/MainMenu.tscn"
const GAME := "res://Scenes/levels/MainGame.tscn"
const CHUNKS := [
	"res://Scenes/chunks/initial_chunk.tscn",
	"res://Scenes/chunks/chunk_1.tscn",
	"res://Scenes/chunks/chuck_2.tscn",
	"res://Scenes/chunks/chuck_3.tscn",
	"res://Scenes/chunks/chuck_4.tscn",
	"res://Scenes/chunks/chunk_5.tscn",
]
const TRANSFORMS := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE

var failures := 0
var checked_cells := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> bool:
	if not condition:
		failures += 1
		push_error("SMOKE: " + description)
	return condition

func _frames(count := 3) -> void:
	for _frame in range(count):
		await process_frame

func _ticks(count: int) -> void:
	for _tick in range(count):
		await physics_frame
		await process_frame

func _validate_chunk(path: String) -> void:
	var packed := load(path) as PackedScene
	if not _check(packed != null, "load " + path):
		return
	var chunk := packed.instantiate()
	var collision_cells := _validate_tiles(chunk, path)
	_check(collision_cells > 0, path + " has solid platform tiles")
	chunk.free()

func _validate_tiles(node: Node, path: String) -> int:
	var collision_cells := 0
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		if not _check(layer.tile_set != null, path + " has a TileSet"):
			return 0
		_check(layer.position.is_finite() and layer.scale.is_finite(), path + " has finite tile transforms")
		for source_index in range(layer.tile_set.get_source_count()):
			var source := layer.tile_set.get_source(layer.tile_set.get_source_id(source_index)) as TileSetAtlasSource
			if not _check(source != null and source.texture != null, path + " has an atlas texture"):
				continue
			var texture_bounds := Rect2i(Vector2i.ZERO, Vector2i(source.texture.get_size()))
			for tile_index in range(source.get_tiles_count()):
				var coordinates := source.get_tile_id(tile_index)
				_check(texture_bounds.encloses(source.get_tile_texture_region(coordinates)), "%s atlas tile %s fits texture" % [path, coordinates])
		for cell in layer.get_used_cells():
			checked_cells += 1
			_check(layer.map_to_local(cell).is_finite(), path + " has finite tile positions")
			var source_id := layer.get_cell_source_id(cell)
			if not _check(layer.tile_set.has_source(source_id), "%s cell %s source exists" % [path, cell]):
				continue
			var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if not _check(source != null, path + " cell uses an atlas"):
				continue
			var coordinates := layer.get_cell_atlas_coords(cell)
			if not _check(source.has_tile(coordinates), "%s cell %s atlas tile %s exists" % [path, cell, coordinates]):
				continue
			var alternative := layer.get_cell_alternative_tile(cell) & ~TRANSFORMS
			if not _check(source.has_alternative_tile(coordinates, alternative), "%s cell %s alternative exists" % [path, cell]):
				continue
			var data := source.get_tile_data(coordinates, alternative)
			for physics_layer in range(layer.tile_set.get_physics_layers_count()):
				if data.get_collision_polygons_count(physics_layer) > 0:
					collision_cells += 1
					break
	for child in node.get_children():
		collision_cells += _validate_tiles(child, path)
	return collision_cells

func _press(button: Button, expected_scene: String) -> bool:
	button.pressed.emit()
	await _frames()
	return _check(current_scene != null and current_scene.scene_file_path == expected_scene, "button opens " + expected_scene)

func _run() -> void:
	seed(12345)
	for path in CHUNKS:
		_validate_chunk(path)
	_check(checked_cells > 0, "chunk scenes contain placed tiles")
	if not _check(change_scene_to_file(MENU) == OK, "open main menu"):
		quit(1)
		return
	await _frames()
	if not await _press(current_scene.get_node("VBoxContainer/PlayButton"), GAME):
		quit(1)
		return
	var game := current_scene
	var player := game.get_node("Player") as CharacterBody2D
	var generator := game.get_node("LevelGenerator")
	_check(game.has_node("InitialChunk"), "game contains initial chunk")
	_check(generator.get_child_count() >= generator.get("spawn_ahead_amount"), "game generates starting chunks")
	for _tick in range(180):
		await _ticks(1)
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "player lands on initial chunk floor")
	var start_x := player.position.x
	Input.action_press("right")
	await _ticks(12)
	Input.action_release("right")
	_check(player.position.x > start_x + 1.0, "right input moves player")
	await _ticks(12)
	var start_y := player.position.y
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	_check(player.position.y < start_y and player.velocity.y < 0.0, "jump input lifts player")
	await _ticks(60)
	_check(player.position.is_finite(), "player remains at a finite position")
	var saved_position := player.position
	var count := generator.get_child_count()
	player.position.y = generator.get("current_spawn_y") - generator.get("chunk_height")
	await _frames()
	_check(generator.get_child_count() > count, "climbing generates additional chunks")
	player.position = saved_position
	player.velocity = Vector2.ZERO
	var ui := game.get_node("UIManager")
	Input.action_press("ui_cancel")
	await _frames()
	Input.action_release("ui_cancel")
	_check(paused and ui.get_node("PauseMenu").visible, "pause input opens pause menu")
	ui.get_node("PauseMenu/VBoxContainer/ResumeButton").pressed.emit()
	_check(not paused and not ui.get_node("PauseMenu").visible, "resume button resumes game")
	player.set("current_oxygen", 0.0)
	await _frames()
	_check(paused and ui.get_node("GameOverMenu").visible, "oxygen depletion opens game over")
	if not await _press(ui.get_node("GameOverMenu/VBoxContainer/RestartButton"), GAME):
		quit(1)
		return
	_check(not paused and current_scene.get_node("Player").get("current_oxygen") > 0.0, "restart resets oxygen and pause")
	ui = current_scene.get_node("UIManager")
	ui.call("pause_game")
	if not await _press(ui.get_node("PauseMenu/VBoxContainer/MenuButton"), MENU):
		quit(1)
		return
	_check(not paused, "return to menu clears pause")
	if not await _press(current_scene.get_node("VBoxContainer/PlayButton"), GAME):
		quit(1)
		return
	current_scene.get_node("Player").set("current_oxygen", 0.0)
	await _frames()
	ui = current_scene.get_node("UIManager")
	await _press(ui.get_node("GameOverMenu/VBoxContainer/MenuButton"), MENU)
	_check(not paused, "game-over menu return clears pause")
	# Allow the audio thread to release the final gameplay music playback.
	await create_timer(0.1).timeout
	print("SMOKE: %d chunk scenes, %d placed cells, gameplay/menu checks; %d failures" % [CHUNKS.size(), checked_cells, failures])
	quit(0 if failures == 0 else 1)
