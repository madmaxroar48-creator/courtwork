extends Node3D

const BALL_RADIUS := 0.12
const COURT_HALF_WIDTH := 4.5
const HOOP_POSITION := Vector3(0.0, 3.05, -5.55)

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var desktop_camera: Camera3D = $XROrigin3D/DesktopCamera

var xr_active := false
var ball: RigidBody3D
var ball_held := false
var held_by_vr := false
var last_hand_position := Vector3.ZERO
var hand_velocity := Vector3.ZERO
var score := 0
var shots_made := 0
var shots_attempted := 0
var score_cooldown := 0.0

var shot_power := 1.0
var shot_assist_enabled := true
var dribble_assist_enabled := true
var menu_open := false
var menu_label: Label3D
var score_label: Label3D
var input_state: Dictionary = {}

var desktop_yaw := 0.0
var desktop_pitch := 0.0


func _ready() -> void:
	_setup_input_map()
	_setup_xr()
	_build_environment()
	_build_court()
	_build_hoop()
	_build_ball()
	_build_scoreboard()
	_build_trainer_panel()
	_build_controller_visuals()
	_refresh_scoreboard()
	_refresh_trainer_panel()


func _setup_xr() -> void:
	var openxr_interface := XRServer.find_interface("OpenXR")
	if openxr_interface != null:
		xr_active = openxr_interface.is_initialized()
		if not xr_active:
			xr_active = openxr_interface.initialize()
	if xr_active:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr_camera.current = true
		print("Courtwork Street VR: OpenXR initialized")
	else:
		desktop_camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("Courtwork Street VR: desktop preview mode")


func _setup_input_map() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("reset_ball_desktop", KEY_R)


func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var already_bound := false
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			already_bound = true
			break
	if not already_bound:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.055, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.70)
	environment.ambient_light_energy = 0.7
	world_env.environment = environment
	add_child(world_env)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sunlight.light_color = Color(1.0, 0.91, 0.78)
	sunlight.light_energy = 1.15
	sunlight.shadow_enabled = false
	add_child(sunlight)


func _build_court() -> void:
	var floor_material := _material(Color(0.13, 0.19, 0.24), 0.88)
	_add_static_box("CourtFloor", Vector3(0, -0.12, -2.0), Vector3(9.0, 0.24, 13.0), floor_material)

	var line_material := _material(Color(0.88, 0.90, 0.88), 0.75)
	_add_visual_box("SidelineLeft", Vector3(-4.25, 0.012, -2.0), Vector3(0.035, 0.018, 12.5), line_material)
	_add_visual_box("SidelineRight", Vector3(4.25, 0.012, -2.0), Vector3(0.035, 0.018, 12.5), line_material)
	_add_visual_box("BaselineFar", Vector3(0, 0.012, -8.2), Vector3(8.5, 0.018, 0.035), line_material)
	_add_visual_box("BaselineNear", Vector3(0, 0.012, 4.2), Vector3(8.5, 0.018, 0.035), line_material)
	_add_visual_box("FreeThrowLine", Vector3(0, 0.014, -1.15), Vector3(4.0, 0.018, 0.035), line_material)
	_add_visual_box("KeyLeft", Vector3(-2.0, 0.014, -3.25), Vector3(0.035, 0.018, 4.2), line_material)
	_add_visual_box("KeyRight", Vector3(2.0, 0.014, -3.25), Vector3(0.035, 0.018, 4.2), line_material)
	_add_visual_box("KeyFront", Vector3(0, 0.014, -1.15), Vector3(4.0, 0.018, 0.035), line_material)
	_add_visual_box("KeyBack", Vector3(0, 0.014, -5.35), Vector3(4.0, 0.018, 0.035), line_material)
	_add_visual_box("CenterLine", Vector3(0, 0.014, 3.0), Vector3(8.5, 0.018, 0.035), line_material)

	var paint_material := _material(Color(0.08, 0.25, 0.34), 0.8)
	_add_visual_box("PaintArea", Vector3(0, 0.002, -3.25), Vector3(3.96, 0.006, 4.15), paint_material)
	_add_visual_box("FreeThrowMark", Vector3(0, 0.016, -1.15), Vector3(1.6, 0.02, 0.025), line_material)

	# A simple practice-court wall and corner accents make the arena feel enclosed.
	var wall_material := _material(Color(0.055, 0.085, 0.12), 0.95)
	_add_visual_box("FarWall", Vector3(0, 3.0, -8.65), Vector3(9.0, 6.0, 0.18), wall_material)
	_add_visual_box("LeftWall", Vector3(-4.6, 2.5, -2.0), Vector3(0.16, 5.0, 13.0), wall_material)
	_add_visual_box("RightWall", Vector3(4.6, 2.5, -2.0), Vector3(0.16, 5.0, 13.0), wall_material)


func _build_hoop() -> void:
	var support_material := _material(Color(0.12, 0.14, 0.17), 0.7)
	var board_material := _material(Color(0.78, 0.87, 0.91), 0.38)
	var rim_material := _material(Color(0.92, 0.25, 0.08), 0.34)
	var net_material := _material(Color(0.88, 0.92, 0.94), 0.92)

	_add_static_box("HoopPost", Vector3(0, 1.55, -6.75), Vector3(0.16, 3.1, 0.16), support_material)
	_add_static_box("HoopSupport", Vector3(0, 3.25, -6.35), Vector3(0.16, 0.16, 0.72), support_material)
	_add_static_box("Backboard", Vector3(0, 3.47, -6.08), Vector3(1.82, 1.08, 0.09), board_material)
	_add_visual_box("BackboardTarget", Vector3(0, 3.18, -6.025), Vector3(0.62, 0.37, 0.018), rim_material)

	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.014
	torus.outer_radius = 0.225
	torus.rings = 12
	torus.ring_segments = 48
	rim.mesh = torus
	rim.material_override = rim_material
	rim.position = HOOP_POSITION
	rim.rotation.x = PI / 2.0
	add_child(rim)

	# Short rounded collision pieces approximate the metal rim while keeping the ball physical.
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var point := HOOP_POSITION + Vector3(cos(angle) * 0.225, 0.0, sin(angle) * 0.225)
		_add_static_sphere("RimCollider_%02d" % index, point, 0.026, rim_material)

	var net_mesh := CylinderMesh.new()
	net_mesh.top_radius = 0.205
	net_mesh.bottom_radius = 0.125
	net_mesh.height = 0.42
	net_mesh.radial_segments = 16
	var net := MeshInstance3D.new()
	net.mesh = net_mesh
	net.material_override = net_material
	net.position = HOOP_POSITION + Vector3(0, -0.24, 0)
	add_child(net)

	var score_zone := Area3D.new()
	score_zone.name = "ScoreZone"
	score_zone.position = HOOP_POSITION + Vector3(0, -0.11, 0)
	var score_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.205
	cylinder.height = 0.12
	score_shape.shape = cylinder
	score_zone.add_child(score_shape)
	add_child(score_zone)
	score_zone.body_entered.connect(_on_score_zone_body_entered)


func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Basketball"
	ball.mass = 0.62
	ball.gravity_scale = 1.0
	ball.linear_damp = 0.08
	ball.angular_damp = 0.16
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	var ball_material := _material(Color(0.86, 0.27, 0.075), 0.72)
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = BALL_RADIUS
	ball_mesh.height = BALL_RADIUS * 2.0
	ball_mesh.radial_segments = 24
	ball_mesh.rings = 16
	var ball_visual := MeshInstance3D.new()
	ball_visual.mesh = ball_mesh
	ball_visual.material_override = ball_material
	ball.add_child(ball_visual)

	var groove_material := _material(Color(0.10, 0.055, 0.035), 0.9)
	for index in range(3):
		var groove := MeshInstance3D.new()
		var groove_mesh := TorusMesh.new()
		groove_mesh.inner_radius = 0.0025
		groove_mesh.outer_radius = BALL_RADIUS * 0.99
		groove_mesh.rings = 6
		groove_mesh.ring_segments = 36
		groove.mesh = groove_mesh
		groove.material_override = groove_material
		groove.scale = Vector3(1.0, 0.42, 1.0)
		groove.rotation = Vector3(0.0, 0.0, float(index) * PI / 3.0)
		ball.add_child(groove)

	var ball_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	ball_shape.shape = sphere_shape
	ball.add_child(ball_shape)

	var ball_physics := PhysicsMaterial.new()
	ball_physics.bounce = 0.78 if dribble_assist_enabled else 0.65
	ball_physics.friction = 0.48
	ball.physics_material_override = ball_physics
	ball.position = Vector3(0.38, 1.05, 1.0)
	ball.freeze = false
	add_child(ball)


func _build_scoreboard() -> void:
	score_label = Label3D.new()
	score_label.name = "Scoreboard"
	score_label.position = Vector3(0, 4.30, -8.52)
	score_label.font_size = 54
	score_label.pixel_size = 0.0035
	score_label.outline_size = 8
	score_label.modulate = Color(0.95, 0.98, 1.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.text = "COURTWORK STREET VR\nPRACTICE"
	add_child(score_label)


func _build_trainer_panel() -> void:
	var panel_root := Node3D.new()
	panel_root.name = "TrainerPanel"
	var active_camera: Camera3D = xr_camera if xr_active else desktop_camera
	active_camera.add_child(panel_root)
	panel_root.position = Vector3(0, -0.25, -1.18)

	var panel_mesh := MeshInstance3D.new()
	var panel_box := BoxMesh.new()
	panel_box.size = Vector3(0.96, 0.62, 0.035)
	panel_mesh.mesh = panel_box
	var panel_material := StandardMaterial3D.new()
	panel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel_material.albedo_color = Color(0.018, 0.035, 0.055, 0.94)
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_mesh.material_override = panel_material
	panel_root.add_child(panel_mesh)

	menu_label = Label3D.new()
	menu_label.position = Vector3(0, 0, 0.022)
	menu_label.font_size = 34
	menu_label.pixel_size = 0.0034
	menu_label.outline_size = 6
	menu_label.modulate = Color(0.92, 0.97, 1.0)
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_label.no_depth_test = true
	panel_root.add_child(menu_label)
	panel_root.visible = false
	menu_label.set_meta("panel_root", panel_root)


func _build_controller_visuals() -> void:
	_add_controller_sphere(left_controller, Color(0.15, 0.72, 0.95))
	_add_controller_sphere(right_controller, Color(0.96, 0.46, 0.13))


func _add_controller_sphere(controller: XRController3D, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	visual.mesh = mesh
	visual.material_override = _material(color, 0.45)
	controller.add_child(visual)


func _physics_process(delta: float) -> void:
	score_cooldown = maxf(0.0, score_cooldown - delta)
	if xr_active:
		_handle_vr_inputs(delta)
	else:
		_handle_desktop_movement(delta)
		if ball_held and not held_by_vr:
			var forward := -desktop_camera.global_basis.z
			ball.global_position = desktop_camera.global_position + forward * 0.48 + Vector3.DOWN * 0.08
	_update_trainer_panel_visibility()


func _handle_vr_inputs(delta: float) -> void:
	if right_controller.get_is_active():
		var grab_down := right_controller.is_button_pressed("grab")
		if grab_down and not bool(input_state.get("grab", false)):
			_try_grab_ball()
		if ball_held and held_by_vr:
			if grab_down:
				var grip_transform := right_controller.global_transform
				ball.global_position = grip_transform.origin + (-grip_transform.basis.z * 0.16) + (-grip_transform.basis.y * 0.04)
				ball.global_basis = grip_transform.basis
				hand_velocity = (right_controller.global_position - last_hand_position) / maxf(delta, 0.001)
			else:
				_release_ball(hand_velocity)
		last_hand_position = right_controller.global_position
		input_state["grab"] = grab_down
	else:
		input_state["grab"] = false

	if right_controller.get_is_active() and _pressed_edge(right_controller, "menu", "menu"):
		menu_open = not menu_open
	if right_controller.get_is_active() and _pressed_edge(right_controller, "power_up", "power_up"):
		shot_power = clampf(shot_power + 0.1, 0.6, 1.6)
	if left_controller.get_is_active() and _pressed_edge(left_controller, "power_down", "power_down"):
		shot_power = clampf(shot_power - 0.1, 0.6, 1.6)
	if left_controller.get_is_active() and _pressed_edge(left_controller, "assist", "assist"):
		shot_assist_enabled = not shot_assist_enabled
	if left_controller.get_is_active() and _pressed_edge(left_controller, "dribble_assist", "dribble_assist"):
		dribble_assist_enabled = not dribble_assist_enabled
		_update_ball_physics_material()
	if left_controller.get_is_active() and _pressed_edge(left_controller, "reset_ball", "reset_ball"):
		_reset_ball()
	_refresh_trainer_panel()


func _pressed_edge(controller: XRController3D, action: String, state_key: String) -> bool:
	var down := controller.is_button_pressed(action)
	var previous := bool(input_state.get(state_key, false))
	input_state[state_key] = down
	return down and not previous


func _try_grab_ball() -> void:
	if ball_held:
		return
	if ball.global_position.distance_to(right_controller.global_position) <= 0.72:
		ball_held = true
		held_by_vr = true
		ball.freeze = true
		ball.sleeping = false
		hand_velocity = Vector3.ZERO
		last_hand_position = right_controller.global_position


func _release_ball(release_velocity: Vector3) -> void:
	if not ball_held:
		return
	ball_held = false
	held_by_vr = false
	ball.freeze = false
	ball.sleeping = false
	var throw_velocity := release_velocity.limit_length(17.0) * shot_power
	if shot_assist_enabled and throw_velocity.length() > 1.25:
		var target_direction := (HOOP_POSITION - ball.global_position).normalized()
		if throw_velocity.normalized().dot(target_direction) > 0.22:
			throw_velocity = throw_velocity.lerp(target_direction * throw_velocity.length(), 0.16)
	ball.linear_velocity = throw_velocity
	ball.angular_velocity = Vector3.ZERO
	shots_attempted += 1
	_refresh_scoreboard()


func _handle_desktop_movement(delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_input.length_squared() > 0.001:
		var right := xr_origin.global_basis.x
		var forward := -xr_origin.global_basis.z
		right.y = 0.0
		forward.y = 0.0
		right = right.normalized()
		forward = forward.normalized()
		xr_origin.global_position += (right * move_input.x + forward * -move_input.y) * 2.8 * delta
	if Input.is_action_just_pressed("reset_ball_desktop"):
		_reset_ball()


func _input(event: InputEvent) -> void:
	if xr_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if ball.global_position.distance_to(desktop_camera.global_position) <= 1.5:
				ball_held = true
				held_by_vr = false
				ball.freeze = true
		else:
			if ball_held and not held_by_vr:
				var forward := -desktop_camera.global_basis.z
				_release_ball((forward * 7.5 + Vector3.UP * 2.6))
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		desktop_yaw -= event.relative.x * 0.0022
		desktop_pitch = clampf(desktop_pitch - event.relative.y * 0.0022, -1.0, 1.0)
		xr_origin.rotation.y = desktop_yaw
		desktop_camera.rotation.x = desktop_pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		menu_open = not menu_open
		_refresh_trainer_panel()


func _update_ball_physics_material() -> void:
	if ball == null or ball.physics_material_override == null:
		return
	ball.physics_material_override.bounce = 0.84 if dribble_assist_enabled else 0.66


func _reset_ball() -> void:
	ball_held = false
	held_by_vr = false
	ball.freeze = true
	ball.global_position = Vector3(0.38, 1.05, 1.0)
	ball.global_rotation = Vector3.ZERO
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.freeze = false
	ball.sleeping = false


func _on_score_zone_body_entered(body: Node3D) -> void:
	if body != ball or score_cooldown > 0.0:
		return
	if ball.linear_velocity.y < -0.15:
		score += 2
		shots_made += 1
		score_cooldown = 1.1
		_refresh_scoreboard()


func _refresh_scoreboard() -> void:
	if score_label == null:
		return
	var percentage := 0.0
	if shots_attempted > 0:
		percentage = 100.0 * float(shots_made) / float(shots_attempted)
	score_label.text = "COURTWORK STREET VR\nSCORE  %d     FG  %d%%" % [score, roundi(percentage)]


func _update_trainer_panel_visibility() -> void:
	var panel_root: Node3D = menu_label.get_meta("panel_root")
	panel_root.visible = menu_open


func _refresh_trainer_panel() -> void:
	if menu_label == null:
		return
	menu_label.text = "COURTWORK  /  TRAINER\n\nSHOT POWER     %.1fx\nSHOT ASSIST    %s\nDRIBBLE ASSIST %s\n\nRIGHT B: MENU\nRIGHT A: POWER UP\nLEFT Y: POWER DOWN\nLEFT X: SHOT ASSIST\nLEFT STICK: DRIBBLE ASSIST\nLEFT GRIP: RESET BALL" % [
		shot_power,
		"ON" if shot_assist_enabled else "OFF",
		"ON" if dribble_assist_enabled else "OFF"
	]
	_update_trainer_panel_visibility()


func _add_static_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	add_child(body)
	return body


func _add_visual_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	add_child(mesh_instance)
	return mesh_instance


func _add_static_sphere(node_name: String, position: Vector3, radius: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
