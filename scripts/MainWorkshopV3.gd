extends "res://scripts/Main.gd"

const UltraSculptMeshScript = preload("res://scripts/TrophySculptMeshUltra.gd")

var turntable_visual_root: Node3D
var wheel_spinning: bool = false
var wheel_speed_degrees: float = 92.0

func _process(delta: float) -> void:
    if wheel_spinning and mode == SCULPT and turntable_visual_root != null and is_instance_valid(turntable_visual_root):
        turntable_visual_root.rotation_degrees.y = fposmod(
            turntable_visual_root.rotation_degrees.y + wheel_speed_degrees * delta,
            360.0
        )

func _set_workshop_visual_mode(enabled: bool) -> void:
    super._set_workshop_visual_mode(enabled)
    if enabled and world_environment != null:
        # Less ambient wash, more directional modelling from the three-point rig.
        world_environment.background_color = Color("25292d")
        world_environment.ambient_light_color = Color("cad2d8")
        world_environment.ambient_light_energy = 0.44

func _build_workshop() -> void:
    # Reuse the proven workshop/camera/light construction, then swap only the
    # sculpt core and add an independent visual turntable layer.
    super._build_workshop()

    if sculpt_mesh != null and is_instance_valid(sculpt_mesh):
        sculpt_mesh.queue_free()

    sculpt_mesh = UltraSculptMeshScript.new()
    sculpt_mesh.name = "SculptClayUltra"
    trophy_root.add_child(sculpt_mesh)
    sculpt_mesh.set_sculpt_preview(true)

    turntable_visual_root = Node3D.new()
    turntable_visual_root.name = "SpinningTurntableVisual"
    turntable.add_child(turntable_visual_root)

    # Thin rotating top skin, slightly above the static turntable body.
    _mesh_cylinder(
        turntable_visual_root,
        Vector3(0.0, 0.145, 0.0),
        1.08,
        1.08,
        0.055,
        Color("69737a"),
        "WheelTop"
    )

    # High-contrast radial markers make the spin readable even at low speed.
    for marker_index in range(12):
        var angle: float = TAU * float(marker_index) / 12.0
        var marker: MeshInstance3D = _mesh_box(
            turntable_visual_root,
            Vector3(cos(angle) * 0.84, 0.185, sin(angle) * 0.84),
            Vector3(0.24, 0.025, 0.065),
            Color("c1c9ce") if marker_index % 2 == 0 else Color("40484e"),
            "WheelMarker"
        )
        marker.rotation_degrees.y = -rad_to_deg(angle)

    _update_workshop_camera()

func _show_sculpt_controls_only() -> void:
    if mode != SCULPT:
        return
    _clear_right()
    _add_heading("SCULPT TOOLS")
    if sculpt_mesh != null:
        _add_info("%s vertices • %s triangles" % [_format_count(sculpt_mesh.vertex_count()), _format_count(sculpt_mesh.triangle_count())])

    _add_info("Clay Add and Clay Remove are now separate tools, so ADD always pushes volume outward.")
    _add_button("Clay ADD  + mass", _select_clay_mode.bind(false))
    _add_button("Clay REMOVE  - mass", _select_clay_mode.bind(true))
    _add_tool_button("Smooth", "Relax and polish the surface.", "Smooth")
    _add_tool_button("Grab", "Pull proportions and silhouette.", "Grab")
    _add_button("Crease GROOVE", _select_crease_mode.bind(false))
    _add_button("Crease RIDGE", _select_crease_mode.bind(true))

    var wheel_text: String = "ON • 360° radial strokes" if wheel_spinning else "OFF • local free sculpt"
    _add_button("Potter wheel: " + wheel_text, _toggle_potter_wheel)
    if wheel_spinning:
        _add_slider("Wheel speed", 25.0, 180.0, wheel_speed_degrees, _set_wheel_speed)
        _add_info("Wheel mode repeats Clay, Smooth and Crease around the full circumference at the height you touch. Grab remains local.")

    _add_slider("Brush size", 10.0, 145.0, brush_radius_px, _set_brush_radius)
    _add_slider("Strength", 0.004, 0.075, brush_strength, _set_brush_strength)
    _add_slider("Light angle", 0.0, 360.0, light_angle_degrees, _set_light_angle)
    _add_button("Reset clay", _reset_sculpt)
    _add_button("Shape looks good → Attach parts", _show_parts)

func _select_clay_mode(remove_mass: bool) -> void:
    active_tool = "Clay"
    clay_subtract = remove_mass
    hud_subtitle.text = "Back workshop • Clay REMOVE" if remove_mass else "Back workshop • Clay ADD"
    _show_sculpt_controls_only()

func _select_crease_mode(ridge: bool) -> void:
    active_tool = "Crease"
    clay_subtract = ridge
    hud_subtitle.text = "Back workshop • Crease RIDGE" if ridge else "Back workshop • Crease GROOVE"
    _show_sculpt_controls_only()

func _toggle_potter_wheel() -> void:
    wheel_spinning = not wheel_spinning
    if not wheel_spinning and turntable_visual_root != null:
        turntable_visual_root.rotation_degrees.y = 0.0
    _show_sculpt_controls_only()

func _set_wheel_speed(value: float) -> void:
    wheel_speed_degrees = value

func _apply_sculpt_brush(mouse_pos: Vector2, force: bool = false) -> void:
    if sculpt_mesh == null or workshop_camera == null or not _mesh_edit_allowed(force):
        return

    if wheel_spinning and active_tool != "Grab":
        match active_tool:
            "Clay":
                sculpt_mesh.apply_lathe_clay(workshop_camera, mouse_pos, brush_radius_px, brush_strength, clay_subtract)
            "Smooth":
                sculpt_mesh.apply_lathe_smooth(workshop_camera, mouse_pos, brush_radius_px, clampf(brush_strength * 7.0, 0.04, 0.72))
            "Crease":
                sculpt_mesh.apply_lathe_crease(workshop_camera, mouse_pos, brush_radius_px, brush_strength * 0.72, clay_subtract)
            _:
                pass
    else:
        match active_tool:
            "Clay":
                sculpt_mesh.apply_clay(workshop_camera, mouse_pos, brush_radius_px, brush_strength, clay_subtract)
            "Smooth":
                sculpt_mesh.apply_smooth(workshop_camera, mouse_pos, brush_radius_px, clampf(brush_strength * 7.0, 0.04, 0.62))
            "Crease":
                sculpt_mesh.apply_crease(workshop_camera, mouse_pos, brush_radius_px, brush_strength * 0.72, clay_subtract)
            _:
                pass
    _sync_attached_parts()

func _show_sculpt_from_existing() -> void:
    if sculpt_mesh != null and sculpt_mesh.has_method("set_sculpt_preview"):
        sculpt_mesh.set_sculpt_preview(true)
    super._show_sculpt_from_existing()

func _show_paint() -> void:
    if sculpt_mesh != null and sculpt_mesh.has_method("set_sculpt_preview"):
        sculpt_mesh.set_sculpt_preview(false)
    super._show_paint()

func _update_workshop_camera() -> void:
    if workshop_camera == null:
        return

    # The camera still orbits the trophy, but its Y position is never allowed to
    # drop into or below the bench. This guard adapts to zoom and vertical pan.
    var safe_camera_y: float = 1.22
    var ratio: float = (safe_camera_y - camera_target_y) / maxf(camera_distance, 0.1)
    ratio = clampf(ratio, -0.94, 0.94)
    var dynamic_min_pitch: float = asin(ratio) + 0.025
    dynamic_min_pitch = maxf(dynamic_min_pitch, -0.34)
    camera_pitch = clampf(camera_pitch, dynamic_min_pitch, 0.96)

    var target: Vector3 = Vector3(0.0, camera_target_y, 0.0)
    var cos_pitch: float = cos(camera_pitch)
    var offset: Vector3 = Vector3(
        sin(camera_yaw) * cos_pitch,
        sin(camera_pitch),
        cos(camera_yaw) * cos_pitch
    ) * camera_distance
    workshop_camera.position = target + offset
    workshop_camera.look_at(target, Vector3.UP)

func _pan_camera_vertical(delta_y: float) -> void:
    camera_target_y = clampf(camera_target_y + delta_y * 0.0028 * camera_distance, 1.62, 3.82)
    _update_workshop_camera()
