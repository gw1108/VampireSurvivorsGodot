extends GdUnitTestSuite

## Tests RunController's camera/background follow: the camera centers on the
## player each rendered frame and the background shader's camera_pos uniform
## tracks the same position. Refs are injected directly so no Main.tscn load is
## needed. Also verifies the background shader compiles/loads.

const BG_SHADER := "res://game/background.gdshader"


func _controller() -> RunController:
	return auto_free(RunController.new())


func test_camera_follows_player() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._camera = auto_free(Camera2D.new())
	rc.state.player.pos = Vector2(120, -45)
	rc._process(0.016)
	assert_vector(rc._camera.position).is_equal(Vector2(120, -45))


func test_camera_tracks_movement_each_frame() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._camera = auto_free(Camera2D.new())
	rc.state.player.pos = Vector2(10, 10)
	rc._process(0.016)
	rc.state.player.pos = Vector2(200, 80)
	rc._process(0.016)
	assert_vector(rc._camera.position).is_equal(Vector2(200, 80))


func test_no_camera_does_not_crash() -> void:
	var rc := _controller()
	rc.start_run("antonio")  # _camera stays null
	rc._process(0.016)
	assert_object(rc._camera).is_null()


func test_background_shader_loads() -> void:
	var shader := load(BG_SHADER)
	assert_object(shader).is_not_null()


func test_background_uniform_tracks_player() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	var mat := ShaderMaterial.new()
	mat.shader = load(BG_SHADER)
	rc._bg_material = mat
	rc.state.player.pos = Vector2(64, 128)
	rc._process(0.016)
	assert_vector(mat.get_shader_parameter("camera_pos")).is_equal(Vector2(64, 128))
