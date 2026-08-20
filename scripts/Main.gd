extends Node3D

const SculptMeshScript = preload("res://scripts/TrophySculptMesh.gd")
const TrophyPartsScript = preload("res://scripts/TrophyParts.gd")

const SHOP: int = 0
const SCULPT: int = 2
const PARTS: int = 3
const PAINT: int = 4
const DELIVERY: int = 5

const VIEWPORT_LEFT_MAX_X: float = 900.0
const VIEWPORT_TOP_Y: float = 95.0
const VIEWPORT_BOTTOM_Y: float = 690.0
const MESH_EDIT_INTERVAL_MS: int = 24

var mode: int = SHOP
var current_order: int = 0
var trophy_index: int = 0
var money: int = 35
var reputation: int = 0

var world: Node3D
var world_environment: Environment
var shop_key_light: DirectionalLight3D
var shop_fill_light: OmniLight3D
var room_walls: Array[Node3D] = []

var ui: CanvasLayer
var hud_subtitle: Label
var hint: Label
var right_panel: PanelContainer
var right_box: VBoxContainer
var dialogue_panel: PanelContainer
var dialogue_name: Label
var dialogue_text: Label
var progress_label: Label
var money_label: Label
var rep_label: Label

var workshop_root: Node3D
var workshop_camera: Camera3D
var turntable: Node3D
var trophy_root: Node3D
var sculpt_mesh
var sculpt_light_rig: Node3D
var sculpt_key_light: DirectionalLight3D
var sculpt_fill_light: DirectionalLight3D
var sculpt_rim_light: DirectionalLight3D
var light_angle_degrees: float = 25.0
var light_rotating: bool = false

var camera_target_y: float = 2.55
var camera_yaw: float = 0.0
var camera_pitch: float = 0.10
var camera_distance: float = 5.4
var camera_orbiting: bool = false
var camera_panning: bool = false

var active_tool: String = "Clay"
var clay_subtract: bool = false
var brush_radius_px: float = 70.0
var brush_strength: float = 0.038
var sculpt_stroking: bool = false
var active_grab_brush: Variant = null
var last_mesh_edit_ms: int = 0

var attached_parts: Array[Dictionary] = []
var added_parts: Array[String] = []
var selected_attachment_index: int = -1
var part_preview_roots: Dictionary = {}
var parts_tray: Node3D
var attachment_dragging: bool = false
var attachment_ghost: Node3D
var attachment_part_name: String = ""
var attachment_surface_index: int = -1

var selected_finish: String = "Gold"
var paint_tool: String = "Spray"
var pen_radius_px: float = 11.0
var paint_strokes: int = 0
var painting: bool = false
var last_paint_ms: int = 0
var paint_finishes_used: Array[String] = []

var orders: Array[Dictionary] = [
    {"customer":"Maya, florist","request":"I run a tiny rooftop flower club. We need two trophies for our annual greenhouse challenge. Make them cheerful and add a star somewhere.","count":2,"finish":"Gold","required":"Star","label":"GREENHOUSE CHAMPION"},
    {"customer":"Dante, bike courier","request":"Our messenger crew is racing across town this weekend. I want one trophy that feels fast. Silver, with a wing if you can manage it.","count":1,"finish":"Silver","required":"Wing","label":"CITY SPRINT"},
    {"customer":"Nina, drummer","request":"My garage-band club finally has a proper battle night. Three trophies, all bronze. Give them chunky handles so they look gloriously over-serious.","count":3,"finish":"Bronze","required":"Handle","label":"LOUDER THAN RENT"}
]

func _ready() -> void:
    _build_environment()
    _build_ui()
    _show_shop()

func _build_environment() -> void:
    world = Node3D.new()
    world.name = "World"
    add_child(world)

    var environment_node: WorldEnvironment = WorldEnvironment.new()
    world_environment = Environment.new()
    world_environment.background_mode = Environment.BG_COLOR
    environment_node.environment = world_environment
    world.add_child(environment_node)

    shop_key_light = DirectionalLight3D.new()
    shop_key_light.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
    shop_key_light.light_color = Color("ffd7a0")
    shop_key_light.light_energy = 1.0
    shop_key_light.shadow_enabled = true
    world.add_child(shop_key_light)

    shop_fill_light = OmniLight3D.new()
    shop_fill_light.position = Vector3(0.0, 3.8, 3.5)
    shop_fill_light.light_color = Color("ffb56b")
    shop_fill_light.omni_range = 9.0
    shop_fill_light.light_energy = 5.0
    world.add_child(shop_fill_light)

    _make_box(Vector3(10.0, 0.2, 9.0), Vector3(0.0, -0.1, 0.0), Color("5b3927"), "Floor")
    room_walls.append(_make_box(Vector3(10.0, 5.0, 0.2), Vector3(0.0, 2.5, -4.4), Color("3a2620"), "BackWall"))
    room_walls.append(_make_box(Vector3(0.2, 5.0, 9.0), Vector3(-4.9, 2.5, 0.0), Color("3a2620"), "LeftWall"))
    room_walls.append(_make_box(Vector3(0.2, 5.0, 9.0), Vector3(4.9, 2.5, 0.0), Color("3a2620"), "RightWall"))
    _set_workshop_visual_mode(false)

func _set_workshop_visual_mode(enabled: bool) -> void:
    for wall in room_walls:
        if is_instance_valid(wall):
            wall.visible = not enabled
    if shop_key_light != null:
        shop_key_light.visible = not enabled
    if shop_fill_light != null:
        shop_fill_light.visible = not enabled
    if world_environment == null:
        return
    if enabled:
        world_environment.background_color = Color("202429")
        world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        world_environment.ambient_light_color = Color("d8e1e8")
        world_environment.ambient_light_energy = 0.68
    else:
        world_environment.background_color = Color("201912")
        world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        world_environment.ambient_light_color = Color("ffe0b0")
        world_environment.ambient_light_energy = 0.62

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)

    var top: PanelContainer = PanelContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_bottom = 86.0
    ui.add_child(top)
    var top_box: HBoxContainer = HBoxContainer.new()
    top_box.add_theme_constant_override("separation", 24)
    top.add_child(top_box)
    var title_box: VBoxContainer = VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_box.add_child(title_box)
    var title: Label = Label.new()
    title.text = "TROPHY CHAMPIONSHOP"
    title.add_theme_font_size_override("font_size", 27)
    title_box.add_child(title)
    hud_subtitle = Label.new()
    hud_subtitle.text = "Tiny shop. Huge victories. Questionable craftsmanship."
    hud_subtitle.modulate = Color("d9bf9c")
    title_box.add_child(hud_subtitle)
    money_label = Label.new()
    rep_label = Label.new()
    top_box.add_child(money_label)
    top_box.add_child(rep_label)

    right_panel = PanelContainer.new()
    right_panel.position = Vector2(930.0, 105.0)
    right_panel.size = Vector2(320.0, 500.0)
    ui.add_child(right_panel)
    var right_scroll: ScrollContainer = ScrollContainer.new()
    right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.add_child(right_scroll)
    right_box = VBoxContainer.new()
    right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_box.add_theme_constant_override("separation", 8)
    right_scroll.add_child(right_box)

    dialogue_panel = PanelContainer.new()
    dialogue_panel.position = Vector2(75.0, 500.0)
    dialogue_panel.size = Vector2(810.0, 175.0)
    ui.add_child(dialogue_panel)
    var dialogue_box: VBoxContainer = VBoxContainer.new()
    dialogue_panel.add_child(dialogue_box)
    dialogue_name = Label.new()
    dialogue_name.add_theme_font_size_override("font_size", 21)
    dialogue_box.add_child(dialogue_name)
    dialogue_text = Label.new()
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue_box.add_child(dialogue_text)

    hint = Label.new()
    hint.position = Vector2(75.0, 458.0)
    hint.size = Vector2(810.0, 35.0)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.modulate = Color("f6d69a")
    ui.add_child(hint)
    progress_label = Label.new()
    progress_label.position = Vector2(930.0, 615.0)
    progress_label.size = Vector2(320.0, 55.0)
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ui.add_child(progress_label)
    _refresh_stats()

func _clear_world_visuals() -> void:
    for child in world.get_children():
        if child.name.begins_with("Dynamic"):
            child.queue_free()
    workshop_root = null
    workshop_camera = null
    turntable = null
    trophy_root = null
    sculpt_mesh = null
    sculpt_light_rig = null
    sculpt_key_light = null
    sculpt_fill_light = null
    sculpt_rim_light = null
    attached_parts.clear()
    part_preview_roots.clear()
    parts_tray = null
    attachment_ghost = null
    attachment_dragging = false
    selected_attachment_index = -1

func _clear_right() -> void:
    for child in right_box.get_children():
        child.queue_free()

func _show_shop() -> void:
    mode = SHOP
    _set_workshop_visual_mode(false)
    _clear_world_visuals()
    _clear_right()
    dialogue_panel.visible = true
    hint.visible = true
    right_panel.visible = true
    _build_shop()
    var order: Dictionary = orders[current_order % orders.size()]
    dialogue_name.text = String(order["customer"])
    dialogue_text.text = String(order["request"])
    hud_subtitle.text = "Front counter • New commission waiting"
    hint.text = "Read the request, then accept the commission."
    _add_heading("ORDER TICKET")
    _add_info("Quantity: %d" % int(order["count"]))
    _add_info("Requested finish: %s" % String(order["finish"]))
    _add_info("Requested detail: %s" % String(order["required"]))
    _add_info("Plaque: %s" % String(order["label"]))
    _add_button("Accept commission", _accept_order)
    _add_button("Next customer", _next_customer)
    progress_label.text = "Counter"
    _refresh_stats()

func _build_shop() -> void:
    var dynamic: Node3D = Node3D.new()
    dynamic.name = "DynamicShop"
    world.add_child(dynamic)
    _camera_at(dynamic, Vector3(0.0, 2.6, 5.6), Vector3(0.0, 1.55, 0.0))
    _make_box(Vector3(7.4, 1.25, 0.85), Vector3(0.0, 0.65, 1.45), Color("6e4128"), "DynamicCounter", dynamic)
    _make_box(Vector3(7.1, 0.14, 1.05), Vector3(0.0, 1.32, 1.45), Color("9c6037"), "DynamicCounterTop", dynamic)
    for side_value in [-1.0, 1.0]:
        var side: float = float(side_value)
        for y_value in [1.0, 2.15, 3.3]:
            var shelf_y: float = float(y_value)
            _make_box(Vector3(2.8, 0.12, 0.62), Vector3(side * 3.15, shelf_y, -3.95), Color("7d4b2f"), "DynamicShelf", dynamic)
            for i in range(4):
                var palette: Array[Color] = [Color("c88b32"), Color("bdc4c9"), Color("a66a3e")]
                var palette_index: int = (i + int(shelf_y)) % 3
                _mini_trophy(dynamic, Vector3(side * 3.15 - 0.95 + float(i) * 0.62, shelf_y + 0.25, -3.55), palette[palette_index])
    _customer(dynamic, Vector3(0.0, 0.0, -0.15))

func _customer(parent: Node3D, pos: Vector3) -> void:
    var root: Node3D = Node3D.new()
    root.name = "DynamicCustomer"
    root.position = pos
    parent.add_child(root)
    _mesh_sphere(root, Vector3(0.0, 2.0, 0.0), 0.42, Color("ddb58c"))
    _mesh_cylinder(root, Vector3(0.0, 1.0, 0.0), 0.62, 0.46, 1.35, Color("42677a"))
    _mesh_box(root, Vector3(0.0, 0.18, 0.0), Vector3(0.95, 0.38, 0.55), Color("3b2c27"))

func _accept_order() -> void:
    trophy_index = 0
    _new_blank()
    _show_sculpt()

func _new_blank() -> void:
    added_parts.clear()
    attached_parts.clear()
    selected_attachment_index = -1
    selected_finish = "Gold"
    paint_tool = "Spray"
    paint_strokes = 0
    paint_finishes_used.clear()
    active_tool = "Clay"
    clay_subtract = false
    brush_radius_px = 70.0
    brush_strength = 0.038
    pen_radius_px = 11.0
    last_mesh_edit_ms = 0
    last_paint_ms = 0

func _next_customer() -> void:
    current_order = (current_order + 1) % orders.size()
    _show_shop()

func _show_sculpt() -> void:
    mode = SCULPT
    _set_workshop_visual_mode(true)
    _build_workshop()
    _show_sculpt_controls_only()
    dialogue_panel.visible = false
    hint.visible = true
    hud_subtitle.text = "Back workshop • High-resolution sculpting"
    hint.text = "LMB sculpt • RMB orbit • MMB vertical pan • wheel zoom • SHIFT+RMB rotates light • F frames"
    _update_progress()

func _build_workshop() -> void:
    _clear_world_visuals()
    workshop_root = Node3D.new()
    workshop_root.name = "DynamicWorkshop"
    world.add_child(workshop_root)

    _make_box(Vector3(7.5, 0.18, 3.6), Vector3(0.0, 0.78, 0.0), Color("3d4348"), "DynamicBench", workshop_root)
    _make_box(Vector3(0.3, 2.1, 3.2), Vector3(-3.4, -0.18, 0.0), Color("2b3034"), "DynamicBenchLeg", workshop_root)
    _make_box(Vector3(0.3, 2.1, 3.2), Vector3(3.4, -0.18, 0.0), Color("2b3034"), "DynamicBenchLeg", workshop_root)

    turntable = Node3D.new()
    turntable.name = "Turntable"
    turntable.position = Vector3(0.0, 0.95, 0.0)
    workshop_root.add_child(turntable)
    _mesh_cylinder(turntable, Vector3.ZERO, 1.15, 1.08, 0.26, Color("596168"))

    trophy_root = Node3D.new()
    trophy_root.name = "TrophyRoot"
    trophy_root.position = Vector3(0.0, 0.16, 0.0)
    turntable.add_child(trophy_root)
    sculpt_mesh = SculptMeshScript.new()
    sculpt_mesh.name = "SculptClay"
    trophy_root.add_child(sculpt_mesh)

    camera_target_y = 2.55
    camera_yaw = 0.0
    camera_pitch = 0.10
    camera_distance = 5.4
    workshop_camera = Camera3D.new()
    workshop_camera.name = "DynamicCamera"
    workshop_camera.fov = 44.0
    workshop_root.add_child(workshop_camera)
    workshop_camera.current = true
    _update_workshop_camera()
    _build_sculpt_lighting()

func _build_sculpt_lighting() -> void:
    sculpt_light_rig = Node3D.new()
    sculpt_light_rig.name = "SculptLightRig"
    workshop_root.add_child(sculpt_light_rig)

    sculpt_key_light = DirectionalLight3D.new()
    sculpt_key_light.light_color = Color("f5f3ed")
    sculpt_key_light.light_energy = 1.35
    sculpt_key_light.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
    sculpt_key_light.shadow_enabled = false
    sculpt_light_rig.add_child(sculpt_key_light)

    sculpt_fill_light = DirectionalLight3D.new()
    sculpt_fill_light.light_color = Color("c8d8e6")
    sculpt_fill_light.light_energy = 0.58
    sculpt_fill_light.rotation_degrees = Vector3(18.0, 142.0, 0.0)
    sculpt_fill_light.shadow_enabled = false
    sculpt_light_rig.add_child(sculpt_fill_light)

    sculpt_rim_light = DirectionalLight3D.new()
    sculpt_rim_light.light_color = Color("ffe0bd")
    sculpt_rim_light.light_energy = 0.78
    sculpt_rim_light.rotation_degrees = Vector3(-12.0, 218.0, 0.0)
    sculpt_rim_light.shadow_enabled = false
    sculpt_light_rig.add_child(sculpt_rim_light)
    _update_sculpt_lighting()

func _update_sculpt_lighting() -> void:
    if sculpt_light_rig != null:
        sculpt_light_rig.rotation_degrees.y = light_angle_degrees

func _set_light_angle(value: float) -> void:
    light_angle_degrees = value
    _update_sculpt_lighting()

func _set_active_tool(tool_name: String) -> void:
    active_tool = tool_name
    hud_subtitle.text = "Back workshop • %s tool" % tool_name
    if mode == SCULPT:
        _show_sculpt_controls_only()

func _toggle_sub_mode() -> void:
    clay_subtract = not clay_subtract
    _show_sculpt_controls_only()

func _show_sculpt_controls_only() -> void:
    if mode != SCULPT:
        return
    _clear_right()
    _add_heading("SCULPT TOOLS")
    if sculpt_mesh != null:
        _add_info("%s vertices • %s triangles" % [_format_count(sculpt_mesh.vertex_count()), _format_count(sculpt_mesh.triangle_count())])
    _add_info("Active: %s" % active_tool)
    _add_tool_button("Clay", "Add/remove coherent volume.", "Clay")
    _add_tool_button("Smooth", "Relax and polish the surface.", "Smooth")
    _add_tool_button("Grab", "Pull proportions and silhouette.", "Grab")
    _add_tool_button("Crease", "Cut grooves or raise ridges.", "Crease")
    var mode_text: String = "SUBTRACT / RIDGE" if clay_subtract else "ADD / GROOVE"
    _add_button("Clay/Crease: " + mode_text, _toggle_sub_mode)
    _add_slider("Brush size", 14.0, 145.0, brush_radius_px, _set_brush_radius)
    _add_slider("Strength", 0.006, 0.075, brush_strength, _set_brush_strength)
    _add_slider("Light angle", 0.0, 360.0, light_angle_degrees, _set_light_angle)
    _add_button("Reset clay", _reset_sculpt)
    _add_button("Shape looks good → Attach parts", _show_parts)

func _set_brush_radius(value: float) -> void:
    brush_radius_px = value

func _set_brush_strength(value: float) -> void:
    brush_strength = value

func _reset_sculpt() -> void:
    if sculpt_mesh != null:
        sculpt_mesh.reset_blank()
        _sync_attached_parts()

func _show_parts() -> void:
    mode = PARTS
    sculpt_stroking = false
    active_grab_brush = null
    _build_parts_tray()
    _refresh_parts_panel()
    hud_subtitle.text = "Back workshop • Place and customize real 3D parts"
    hint.text = "Drag preview → surface • click attached part to edit • RMB orbit • MMB vertical pan • SHIFT+RMB light"
    _update_progress()

func _refresh_parts_panel() -> void:
    if mode != PARTS:
        return
    _clear_right()
    _add_heading("ATTACH PARTS")
    _add_info("Drag Base, Plaque, Handle, Star, Wing or Crown from the 3D tray onto any visible point of the clay.")
    _add_slider("Light angle", 0.0, 360.0, light_angle_degrees, _set_light_angle)
    if selected_attachment_index >= 0 and selected_attachment_index < attached_parts.size():
        var record: Dictionary = attached_parts[selected_attachment_index]
        _add_heading("SELECTED: %s" % String(record.get("name", "Part")))
        _add_info("Rotate, tilt, scale and embed it into the main sculpt.")
        _add_slider("Spin", -180.0, 180.0, float(record.get("spin", 0.0)), _set_attachment_spin)
        _add_slider("Tilt X", -90.0, 90.0, float(record.get("tilt_x", 0.0)), _set_attachment_tilt_x)
        _add_slider("Tilt Y", -90.0, 90.0, float(record.get("tilt_y", 0.0)), _set_attachment_tilt_y)
        _add_slider("Size", 0.25, 2.5, float(record.get("scale", 0.76)), _set_attachment_scale)
        _add_slider("Embed", -0.42, 0.42, float(record.get("embed", 0.045)), _set_attachment_embed)
        _add_button("Delete selected part", _delete_selected_attachment)
    else:
        _add_info("After dropping a part, it stays selected here. You can also click an attached piece to select it again.")
    _add_button("Back to sculpt", _show_sculpt_from_existing)
    _add_button("Ready for paint →", _show_paint)

func _show_sculpt_from_existing() -> void:
    mode = SCULPT
    _remove_parts_tray()
    _show_sculpt_controls_only()
    hud_subtitle.text = "Back workshop • High-resolution sculpting"
    hint.text = "LMB sculpt • RMB orbit • MMB vertical pan • wheel zoom • SHIFT+RMB rotates light • F frames"

func _build_parts_tray() -> void:
    _remove_parts_tray()
    if workshop_root == null:
        return
    parts_tray = Node3D.new()
    parts_tray.name = "PartsTray"
    workshop_root.add_child(parts_tray)
    _mesh_box(parts_tray, Vector3(0.0, 1.08, -1.62), Vector3(6.4, 0.10, 0.95), Color("31363a"), "PartsShelf")
    var names: Array[String] = ["Base", "Plaque", "Handle", "Star", "Wing", "Crown"]
    var x_positions: Array[float] = [-2.65, -1.60, -0.55, 0.55, 1.60, 2.65]
    part_preview_roots.clear()
    for i in range(names.size()):
        var part_name: String = names[i]
        var holder: Node3D = Node3D.new()
        holder.name = "Preview_" + part_name
        holder.position = Vector3(x_positions[i], 1.48, -1.55)
        parts_tray.add_child(holder)
        var preview: Node3D = TrophyPartsScript.create_part(part_name, holder, Color("d6b26d"), false)
        preview.scale = Vector3.ONE * 0.72
        var label: Label3D = Label3D.new()
        label.text = part_name
        label.position = Vector3(0.0, -0.58, 0.0)
        label.font_size = 28
        label.pixel_size = 0.004
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        holder.add_child(label)
        part_preview_roots[part_name] = holder

func _remove_parts_tray() -> void:
    part_preview_roots.clear()
    if parts_tray != null and is_instance_valid(parts_tray):
        parts_tray.queue_free()
    parts_tray = null

func _part_preview_under_mouse(mouse_pos: Vector2) -> String:
    if workshop_camera == null:
        return ""
    var best_name: String = ""
    var best_distance: float = 58.0
    for key in part_preview_roots.keys():
        var part_name: String = String(key)
        var holder_value: Variant = part_preview_roots[part_name]
        if not (holder_value is Node3D):
            continue
        var holder: Node3D = holder_value
        if not is_instance_valid(holder) or workshop_camera.is_position_behind(holder.global_position):
            continue
        var screen_pos: Vector2 = workshop_camera.unproject_position(holder.global_position)
        var distance: float = screen_pos.distance_to(mouse_pos)
        if distance < best_distance:
            best_distance = distance
            best_name = part_name
    return best_name

func _attachment_under_mouse(mouse_pos: Vector2) -> int:
    if workshop_camera == null:
        return -1
    var best_index: int = -1
    var best_distance: float = 52.0
    for i in range(attached_parts.size()):
        var node_value: Variant = attached_parts[i].get("node")
        if not (node_value is Node3D):
            continue
        var part_node: Node3D = node_value
        if not is_instance_valid(part_node) or workshop_camera.is_position_behind(part_node.global_position):
            continue
        var projected: Vector2 = workshop_camera.unproject_position(part_node.global_position)
        var distance: float = projected.distance_to(mouse_pos)
        if distance < best_distance:
            best_distance = distance
            best_index = i
    return best_index

func _start_attachment_drag(part_name: String, mouse_pos: Vector2) -> void:
    if trophy_root == null or sculpt_mesh == null:
        return
    attachment_dragging = true
    attachment_part_name = part_name
    attachment_surface_index = -1
    attachment_ghost = TrophyPartsScript.create_part(part_name, trophy_root, Color("82d5ff"), true)
    _update_attachment_drag(mouse_pos)

func _update_attachment_drag(mouse_pos: Vector2) -> void:
    if not attachment_dragging or attachment_ghost == null or sculpt_mesh == null or workshop_camera == null:
        return
    var vertex_index: int = sculpt_mesh.get_closest_visible_vertex(workshop_camera, mouse_pos, 105.0)
    attachment_surface_index = vertex_index
    if vertex_index < 0:
        attachment_ghost.visible = false
        return
    attachment_ghost.visible = true
    _place_attachment_transform(attachment_ghost, vertex_index, 0.0, 0.0, 0.0, 0.76, 0.045)

func _finish_attachment_drag(commit: bool) -> void:
    if not attachment_dragging:
        return
    if attachment_ghost != null and is_instance_valid(attachment_ghost):
        if commit and attachment_surface_index >= 0:
            attachment_ghost.name = "Attached_" + attachment_part_name
            TrophyPartsScript.set_color(attachment_ghost, Color("b8b0a7"), false, 0.06)
            attached_parts.append({
                "node":attachment_ghost,
                "vertex":attachment_surface_index,
                "name":attachment_part_name,
                "spin":0.0,
                "tilt_x":0.0,
                "tilt_y":0.0,
                "scale":0.76,
                "embed":0.045
            })
            added_parts.append(attachment_part_name)
            selected_attachment_index = attached_parts.size() - 1
        else:
            attachment_ghost.queue_free()
    attachment_dragging = false
    attachment_ghost = null
    attachment_part_name = ""
    attachment_surface_index = -1
    _refresh_parts_panel()

func _place_attachment_transform(part_node: Node3D, vertex_index: int, spin: float, tilt_x: float, tilt_y: float, scale_value: float, embed: float) -> void:
    if sculpt_mesh == null or vertex_index < 0 or vertex_index >= sculpt_mesh.vertices.size():
        return
    var surface_position: Vector3 = sculpt_mesh.vertices[vertex_index]
    var surface_normal: Vector3 = sculpt_mesh.normals[vertex_index].normalized()
    var z_axis: Vector3 = surface_normal
    var reference_up: Vector3 = Vector3.UP
    if absf(z_axis.dot(reference_up)) > 0.92:
        reference_up = Vector3.RIGHT
    var x_axis: Vector3 = reference_up.cross(z_axis).normalized()
    var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
    var surface_basis: Basis = Basis(x_axis, y_axis, z_axis)
    var local_rotation: Basis = Basis(Vector3.FORWARD, deg_to_rad(spin))
    local_rotation = local_rotation * Basis(Vector3.RIGHT, deg_to_rad(tilt_x))
    local_rotation = local_rotation * Basis(Vector3.UP, deg_to_rad(tilt_y))
    part_node.basis = surface_basis * local_rotation
    part_node.scale = Vector3.ONE * scale_value
    part_node.position = surface_position + surface_normal * embed

func _sync_attached_parts() -> void:
    for record in attached_parts:
        var node_value: Variant = record.get("node")
        if not (node_value is Node3D):
            continue
        var part_node: Node3D = node_value
        if not is_instance_valid(part_node):
            continue
        _place_attachment_transform(
            part_node,
            int(record.get("vertex", -1)),
            float(record.get("spin", 0.0)),
            float(record.get("tilt_x", 0.0)),
            float(record.get("tilt_y", 0.0)),
            float(record.get("scale", 0.76)),
            float(record.get("embed", 0.045))
        )

func _update_selected_attachment_value(key: String, value: float) -> void:
    if selected_attachment_index < 0 or selected_attachment_index >= attached_parts.size():
        return
    attached_parts[selected_attachment_index][key] = value
    _sync_attached_parts()

func _set_attachment_spin(value: float) -> void:
    _update_selected_attachment_value("spin", value)

func _set_attachment_tilt_x(value: float) -> void:
    _update_selected_attachment_value("tilt_x", value)

func _set_attachment_tilt_y(value: float) -> void:
    _update_selected_attachment_value("tilt_y", value)

func _set_attachment_scale(value: float) -> void:
    _update_selected_attachment_value("scale", value)

func _set_attachment_embed(value: float) -> void:
    _update_selected_attachment_value("embed", value)

func _delete_selected_attachment() -> void:
    if selected_attachment_index < 0 or selected_attachment_index >= attached_parts.size():
        return
    var record: Dictionary = attached_parts[selected_attachment_index]
    var node_value: Variant = record.get("node")
    if node_value is Node3D and is_instance_valid(node_value):
        node_value.queue_free()
    var part_name: String = String(record.get("name", ""))
    attached_parts.remove_at(selected_attachment_index)
    if not part_name.is_empty():
        added_parts.erase(part_name)
    selected_attachment_index = min(selected_attachment_index, attached_parts.size() - 1)
    _refresh_parts_panel()

func _show_paint() -> void:
    mode = PAINT
    _remove_parts_tray()
    _refresh_paint_panel()
    hud_subtitle.text = "Back workshop • PBR paint + surface pen"
    hint.text = "Spray coats areas • Pen draws/writes freehand • RMB orbit • MMB vertical pan • SHIFT+RMB light"
    _update_progress()

func _refresh_paint_panel() -> void:
    if mode != PAINT:
        return
    _clear_right()
    _add_heading("PAINT & LETTERING")
    _add_info("Gold, Silver and Bronze use real metallic PBR response. Pen mode writes directly onto the high-resolution surface.")
    _add_button("Tool: SPRAY", _set_paint_tool.bind("Spray"))
    _add_button("Tool: PEN", _set_paint_tool.bind("Pen"))
    _add_info("Active tool: %s • Color: %s" % [paint_tool, selected_finish])
    for finish in ["Gold", "Silver", "Bronze", "Red", "Blue", "Green", "Black", "Ivory", "White"]:
        _add_button(String(finish), _select_finish.bind(String(finish)))
    if paint_tool == "Pen":
        _add_slider("Pen size", 3.0, 32.0, pen_radius_px, _set_pen_radius)
    else:
        _add_slider("Spray size", 24.0, 170.0, brush_radius_px, _set_brush_radius)
    _add_slider("Light angle", 0.0, 360.0, light_angle_degrees, _set_light_angle)
    _add_button("Finish trophy →", _finish_trophy)

func _set_paint_tool(tool_name: String) -> void:
    paint_tool = tool_name
    _refresh_paint_panel()

func _set_pen_radius(value: float) -> void:
    pen_radius_px = value

func _select_finish(finish: String) -> void:
    selected_finish = finish
    hud_subtitle.text = "Back workshop • %s: %s" % [paint_tool, finish]
    _refresh_paint_panel()

func _paint_at(mouse_pos: Vector2, force: bool = false) -> void:
    if sculpt_mesh == null or workshop_camera == null:
        return
    var now_ms: int = Time.get_ticks_msec()
    if not force and now_ms - last_paint_ms < MESH_EDIT_INTERVAL_MS:
        return
    last_paint_ms = now_ms

    var paint_color: Color = _finish_color(selected_finish)
    var metallic_value: float = _metallic_for_finish(selected_finish)
    var radius: float = pen_radius_px if paint_tool == "Pen" else brush_radius_px
    var strength: float = 0.96 if paint_tool == "Pen" else 0.58
    var did_paint: bool = sculpt_mesh.paint_brush(workshop_camera, mouse_pos, radius, paint_color, metallic_value, strength)

    if paint_tool == "Spray":
        for record in attached_parts:
            var node_value: Variant = record.get("node")
            if not (node_value is Node3D):
                continue
            var part_node: Node3D = node_value
            if not is_instance_valid(part_node) or workshop_camera.is_position_behind(part_node.global_position):
                continue
            var part_screen: Vector2 = workshop_camera.unproject_position(part_node.global_position)
            if part_screen.distance_to(mouse_pos) <= brush_radius_px:
                TrophyPartsScript.set_color(part_node, paint_color, false, metallic_value)
                did_paint = true
        if did_paint and selected_finish not in paint_finishes_used:
            paint_finishes_used.append(selected_finish)

    if did_paint:
        paint_strokes += 1

func _finish_trophy() -> void:
    var order: Dictionary = orders[current_order % orders.size()]
    if paint_strokes < 4:
        hint.text = "Give it a proper coat or some lettering first. Four paint strokes minimum."
        return
    trophy_index += 1
    if trophy_index < int(order["count"]):
        _new_blank()
        _show_sculpt()
    else:
        _show_delivery()

func _show_delivery() -> void:
    mode = DELIVERY
    _set_workshop_visual_mode(false)
    _clear_world_visuals()
    _clear_right()
    _build_shop()
    dialogue_panel.visible = true
    hint.visible = true
    var order: Dictionary = orders[current_order % orders.size()]
    var score: int = 2
    if String(order["required"]) in added_parts:
        score += 1
    if String(order["finish"]) in paint_finishes_used or selected_finish == String(order["finish"]):
        score += 1
    if paint_strokes >= 10:
        score += 1
    score = clampi(score, 1, 5)
    var stars: String = "★".repeat(score) + "☆".repeat(5 - score)
    var payout: int = 18 * int(order["count"]) + score * 7
    money += payout
    reputation += score
    dialogue_name.text = String(order["customer"])
    dialogue_text.text = "These are mine?! %s\n\nYou earned $%d for the commission." % [stars, payout]
    hud_subtitle.text = "Front counter • Delivery complete"
    hint.text = "Customers judge requested detail, finish and how completely you worked the piece."
    _add_heading("DELIVERY")
    _add_info("Rating: " + stars)
    _add_info("Payout: $%d" % payout)
    _add_button("Serve next customer", _complete_delivery)
    progress_label.text = "Delivered!"
    _refresh_stats()

func _complete_delivery() -> void:
    current_order = (current_order + 1) % orders.size()
    _show_shop()

func _update_progress() -> void:
    var order: Dictionary = orders[current_order % orders.size()]
    progress_label.text = "Trophy %d / %d" % [trophy_index + 1, int(order["count"])]

func _input(event: InputEvent) -> void:
    if mode not in [SCULPT, PARTS, PAINT]:
        return

    if event is InputEventKey:
        var key_event: InputEventKey = event
        if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F:
            _frame_workshop_camera()
        return

    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton = event
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            camera_distance = clampf(camera_distance - 0.40, 2.4, 8.5)
            _update_workshop_camera()
            return
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            camera_distance = clampf(camera_distance + 0.40, 2.4, 8.5)
            _update_workshop_camera()
            return
        if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
            if mouse_button.pressed:
                if mouse_button.shift_pressed:
                    light_rotating = true
                    camera_orbiting = false
                else:
                    camera_orbiting = true
                    light_rotating = false
            else:
                camera_orbiting = false
                light_rotating = false
            return
        if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
            camera_panning = mouse_button.pressed
            return
        if mouse_button.button_index == MOUSE_BUTTON_LEFT:
            if mouse_button.pressed:
                if not _inside_model_view(mouse_button.position):
                    return
                if mode == SCULPT:
                    sculpt_stroking = true
                    if active_tool == "Grab":
                        active_grab_brush = sculpt_mesh.capture_brush(workshop_camera, mouse_button.position, brush_radius_px)
                    else:
                        _apply_sculpt_brush(mouse_button.position, true)
                elif mode == PARTS:
                    var part_name: String = _part_preview_under_mouse(mouse_button.position)
                    if not part_name.is_empty():
                        _start_attachment_drag(part_name, mouse_button.position)
                    else:
                        var attachment_index: int = _attachment_under_mouse(mouse_button.position)
                        if attachment_index >= 0:
                            selected_attachment_index = attachment_index
                            _refresh_parts_panel()
                elif mode == PAINT:
                    painting = true
                    _paint_at(mouse_button.position, true)
            else:
                if mode == SCULPT:
                    sculpt_stroking = false
                    active_grab_brush = null
                elif mode == PARTS and attachment_dragging:
                    _finish_attachment_drag(attachment_surface_index >= 0)
                elif mode == PAINT:
                    painting = false
            return

    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event
        if light_rotating:
            light_angle_degrees = fposmod(light_angle_degrees - motion.relative.x * 0.65, 360.0)
            _update_sculpt_lighting()
            return
        if camera_orbiting:
            camera_yaw -= motion.relative.x * 0.009
            camera_pitch = clampf(camera_pitch - motion.relative.y * 0.007, -0.82, 1.05)
            _update_workshop_camera()
            return
        if camera_panning:
            _pan_camera_vertical(motion.relative.y)
            return
        if mode == SCULPT and sculpt_stroking:
            if active_tool == "Grab" and active_grab_brush != null:
                if _mesh_edit_allowed(false):
                    sculpt_mesh.apply_grab(workshop_camera, active_grab_brush, motion.relative, get_viewport().get_visible_rect().size.y, 0.88)
                    _sync_attached_parts()
            else:
                _apply_sculpt_brush(motion.position, false)
            return
        if mode == PARTS and attachment_dragging:
            _update_attachment_drag(motion.position)
            return
        if mode == PAINT and painting:
            _paint_at(motion.position, false)

func _mesh_edit_allowed(force: bool) -> bool:
    var now_ms: int = Time.get_ticks_msec()
    if not force and now_ms - last_mesh_edit_ms < MESH_EDIT_INTERVAL_MS:
        return false
    last_mesh_edit_ms = now_ms
    return true

func _apply_sculpt_brush(mouse_pos: Vector2, force: bool = false) -> void:
    if sculpt_mesh == null or workshop_camera == null or not _mesh_edit_allowed(force):
        return
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

func _inside_model_view(mouse_pos: Vector2) -> bool:
    return mouse_pos.x >= 0.0 and mouse_pos.x <= VIEWPORT_LEFT_MAX_X and mouse_pos.y >= VIEWPORT_TOP_Y and mouse_pos.y <= VIEWPORT_BOTTOM_Y

func _frame_workshop_camera() -> void:
    camera_target_y = 2.55
    camera_yaw = 0.0
    camera_pitch = 0.10
    camera_distance = 5.4
    _update_workshop_camera()

func _update_workshop_camera() -> void:
    if workshop_camera == null:
        return
    var target: Vector3 = Vector3(0.0, camera_target_y, 0.0)
    var cos_pitch: float = cos(camera_pitch)
    var offset: Vector3 = Vector3(sin(camera_yaw) * cos_pitch, sin(camera_pitch), cos(camera_yaw) * cos_pitch) * camera_distance
    workshop_camera.position = target + offset
    workshop_camera.look_at(target, Vector3.UP)

func _pan_camera_vertical(delta_y: float) -> void:
    camera_target_y = clampf(camera_target_y + delta_y * 0.0028 * camera_distance, 1.15, 3.85)
    _update_workshop_camera()

func _refresh_stats() -> void:
    money_label.text = "Cash  $%d" % money
    rep_label.text = "Rep  ★ %d" % reputation

func _format_count(value: int) -> String:
    if value >= 1000:
        return "%.1fk" % (float(value) / 1000.0)
    return str(value)

func _add_heading(text: String) -> void:
    var label: Label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 20)
    right_box.add_child(label)

func _add_info(text: String) -> void:
    var label: Label = Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_box.add_child(label)

func _add_button(text: String, callback: Callable) -> void:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size.y = 38.0
    button.pressed.connect(callback)
    right_box.add_child(button)

func _add_tool_button(text: String, description: String, tool_name: String) -> void:
    var button: Button = Button.new()
    button.text = "%s  •  %s" % [text, description]
    button.custom_minimum_size.y = 38.0
    button.pressed.connect(_set_active_tool.bind(tool_name))
    right_box.add_child(button)

func _add_slider(label_text: String, minimum: float, maximum: float, value: float, callback: Callable) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    var label: Label = Label.new()
    label.text = label_text
    label.custom_minimum_size.x = 92.0
    row.add_child(label)
    var slider: HSlider = HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = 0.01
    slider.value = value
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.value_changed.connect(callback)
    row.add_child(slider)
    right_box.add_child(row)

func _camera_at(parent: Node3D, pos: Vector3, target: Vector3) -> void:
    var camera: Camera3D = Camera3D.new()
    camera.name = "DynamicCamera"
    camera.position = pos
    parent.add_child(camera)
    camera.look_at(target)
    camera.current = true
    camera.fov = 48.0

func _mat(color: Color, roughness: float = 0.55, metallic: float = 0.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _make_box(size: Vector3, pos: Vector3, color: Color, node_name: String = "DynamicBox", parent: Node3D = null) -> MeshInstance3D:
    var actual_parent: Node3D = world if parent == null else parent
    return _mesh_box(actual_parent, pos, size, color, node_name)

func _mesh_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, node_name: String = "Box") -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = node_name
    var box: BoxMesh = BoxMesh.new()
    box.size = size
    instance.mesh = box
    instance.position = pos
    instance.material_override = _mat(color)
    parent.add_child(instance)
    return instance

func _mesh_sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, node_name: String = "Sphere") -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = node_name
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    instance.mesh = sphere
    instance.position = pos
    instance.material_override = _mat(color)
    parent.add_child(instance)
    return instance

func _mesh_cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color, node_name: String = "Cylinder") -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = node_name
    var cylinder: CylinderMesh = CylinderMesh.new()
    cylinder.bottom_radius = bottom
    cylinder.top_radius = top
    cylinder.height = height
    cylinder.radial_segments = 24
    instance.mesh = cylinder
    instance.position = pos
    instance.material_override = _mat(color, 0.35, 0.45 if color.get_luminance() > 0.45 else 0.1)
    parent.add_child(instance)
    return instance

func _mini_trophy(parent: Node3D, pos: Vector3, color: Color) -> void:
    var root: Node3D = Node3D.new()
    root.name = "DynamicMiniTrophy"
    root.position = pos
    parent.add_child(root)
    _mesh_box(root, Vector3(0.0, 0.05, 0.0), Vector3(0.42, 0.10, 0.34), Color("2d2523"))
    _mesh_cylinder(root, Vector3(0.0, 0.24, 0.0), 0.12, 0.10, 0.34, color)
    _mesh_sphere(root, Vector3(0.0, 0.48, 0.0), 0.15, color)

func _finish_color(finish: String) -> Color:
    match finish:
        "Gold": return Color("d7a52d")
        "Silver": return Color("cbd3da")
        "Bronze": return Color("a86638")
        "Red": return Color("bb3c35")
        "Blue": return Color("3e73b8")
        "Green": return Color("4c8a5e")
        "Black": return Color("1c1d20")
        "Ivory": return Color("e8dfc9")
        "White": return Color("f2f2ef")
        _: return Color.WHITE

func _metallic_for_finish(finish: String) -> float:
    if finish in ["Gold", "Silver", "Bronze"]:
        return 0.94
    return 0.0
