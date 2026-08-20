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

var mode: int = SHOP
var current_order: int = 0
var trophy_index: int = 0
var money: int = 35
var reputation: int = 0

var world: Node3D
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
var attached_parts: Array[Dictionary] = []
var added_parts: Array[String] = []

var camera_target: Vector3 = Vector3(0.0, 2.55, 0.0)
var camera_yaw: float = 0.0
var camera_pitch: float = 0.10
var camera_distance: float = 5.4
var camera_orbiting: bool = false
var camera_panning: bool = false

var active_tool: String = "Clay"
var clay_subtract: bool = false
var brush_radius_px: float = 72.0
var brush_strength: float = 0.045
var sculpt_stroking: bool = false
var active_grab_brush: Variant = null

var part_preview_roots: Dictionary = {}
var parts_tray: Node3D
var attachment_dragging: bool = false
var attachment_ghost: Node3D
var attachment_part_name: String = ""
var attachment_surface_index: int = -1

var selected_finish: String = "Gold"
var paint_strokes: int = 0
var painting: bool = false

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
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("201912")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("ffe0b0")
    environment.ambient_light_energy = 0.62
    environment_node.environment = environment
    world.add_child(environment_node)
    var key_light: DirectionalLight3D = DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
    key_light.light_color = Color("ffd7a0")
    key_light.light_energy = 1.0
    key_light.shadow_enabled = true
    world.add_child(key_light)
    var fill_light: OmniLight3D = OmniLight3D.new()
    fill_light.position = Vector3(0.0, 3.8, 3.5)
    fill_light.light_color = Color("ffb56b")
    fill_light.omni_range = 9.0
    fill_light.light_energy = 5.0
    world.add_child(fill_light)
    _make_box(Vector3(10.0, 0.2, 9.0), Vector3(0.0, -0.1, 0.0), Color("5b3927"), "Floor")
    _make_box(Vector3(10.0, 5.0, 0.2), Vector3(0.0, 2.5, -4.4), Color("3a2620"), "BackWall")
    _make_box(Vector3(0.2, 5.0, 9.0), Vector3(-4.9, 2.5, 0.0), Color("3a2620"), "LeftWall")
    _make_box(Vector3(0.2, 5.0, 9.0), Vector3(4.9, 2.5, 0.0), Color("3a2620"), "RightWall")

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
    right_box = VBoxContainer.new()
    right_box.add_theme_constant_override("separation", 8)
    right_panel.add_child(right_box)
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
    attached_parts.clear()
    part_preview_roots.clear()
    parts_tray = null
    attachment_ghost = null
    attachment_dragging = false

func _clear_right() -> void:
    for child in right_box.get_children():
        child.queue_free()

func _show_shop() -> void:
    mode = SHOP
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
    selected_finish = "Gold"
    paint_strokes = 0
    active_tool = "Clay"
    clay_subtract = false
    brush_radius_px = 72.0
    brush_strength = 0.045

func _next_customer() -> void:
    current_order = (current_order + 1) % orders.size()
    _show_shop()

func _show_sculpt() -> void:
    mode = SCULPT
    _build_workshop()
    _clear_right()
    dialogue_panel.visible = false
    hint.visible = true
    hud_subtitle.text = "Back workshop • Real vertex sculpting"
    hint.text = "LMB sculpt • RMB orbit • MMB pan • wheel zoom • F frames the trophy"
    _add_heading("SCULPT TOOLS")
    _add_info("~3.8k vertices / ~7.5k triangles. Every stroke deforms the actual 3D mesh.")
    _add_tool_button("Clay", "Build or remove volume.", "Clay")
    _add_tool_button("Smooth", "Relax and polish the surface.", "Smooth")
    _add_tool_button("Grab", "Pull proportions and silhouette.", "Grab")
    _add_tool_button("Crease", "Cut grooves or raise sharp ridges.", "Crease")
    _add_button("Clay mode: ADD / Crease: GROOVE", _toggle_sub_mode)
    _add_slider("Brush size", 24.0, 145.0, brush_radius_px, _set_brush_radius)
    _add_slider("Strength", 0.01, 0.10, brush_strength, _set_brush_strength)
    _add_button("Reset clay", _reset_sculpt)
    _add_button("Shape looks good → Attach parts", _show_parts)
    _update_progress()

func _build_workshop() -> void:
    _clear_world_visuals()
    workshop_root = Node3D.new()
    workshop_root.name = "DynamicWorkshop"
    world.add_child(workshop_root)
    _make_box(Vector3(7.5, 0.18, 3.6), Vector3(0.0, 0.78, 0.0), Color("4a3025"), "DynamicBench", workshop_root)
    _make_box(Vector3(0.3, 2.1, 3.2), Vector3(-3.4, -0.18, 0.0), Color("35241e"), "DynamicBenchLeg", workshop_root)
    _make_box(Vector3(0.3, 2.1, 3.2), Vector3(3.4, -0.18, 0.0), Color("35241e"), "DynamicBenchLeg", workshop_root)
    for x_value in [-2.8, -2.1, 2.1, 2.8]:
        _mini_trophy(workshop_root, Vector3(float(x_value), 1.15, -1.1), Color("6f6a62"))
    turntable = Node3D.new()
    turntable.name = "Turntable"
    turntable.position = Vector3(0.0, 0.95, 0.0)
    workshop_root.add_child(turntable)
    _mesh_cylinder(turntable, Vector3.ZERO, 1.15, 1.08, 0.26, Color("4f5357"))
    trophy_root = Node3D.new()
    trophy_root.name = "TrophyRoot"
    trophy_root.position = Vector3(0.0, 0.16, 0.0)
    turntable.add_child(trophy_root)
    sculpt_mesh = SculptMeshScript.new()
    sculpt_mesh.name = "SculptClay"
    trophy_root.add_child(sculpt_mesh)
    camera_target = Vector3(0.0, 2.55, 0.0)
    camera_yaw = 0.0
    camera_pitch = 0.10
    camera_distance = 5.4
    workshop_camera = Camera3D.new()
    workshop_camera.name = "DynamicCamera"
    workshop_camera.fov = 45.0
    workshop_root.add_child(workshop_camera)
    workshop_camera.current = true
    _update_workshop_camera()

func _set_active_tool(tool_name: String) -> void:
    active_tool = tool_name
    hud_subtitle.text = "Back workshop • %s tool" % tool_name

func _toggle_sub_mode() -> void:
    clay_subtract = not clay_subtract
    _show_sculpt_controls_only()

func _show_sculpt_controls_only() -> void:
    if mode != SCULPT:
        return
    _clear_right()
    _add_heading("SCULPT TOOLS")
    _add_info("Active: %s" % active_tool)
    _add_tool_button("Clay", "Build or remove volume.", "Clay")
    _add_tool_button("Smooth", "Relax and polish the surface.", "Smooth")
    _add_tool_button("Grab", "Pull proportions and silhouette.", "Grab")
    _add_tool_button("Crease", "Cut grooves or raise sharp ridges.", "Crease")
    var mode_text: String = "SUBTRACT / RIDGE" if clay_subtract else "ADD / GROOVE"
    _add_button("Clay/Crease mode: " + mode_text, _toggle_sub_mode)
    _add_slider("Brush size", 24.0, 145.0, brush_radius_px, _set_brush_radius)
    _add_slider("Strength", 0.01, 0.10, brush_strength, _set_brush_strength)
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
    _clear_right()
    _build_parts_tray()
    hud_subtitle.text = "Back workshop • Drag real parts onto the surface"
    hint.text = "LMB drag a 3D preview onto the trophy • RMB orbit • MMB pan • wheel zoom"
    _add_heading("ATTACH PARTS")
    _add_info("The objects on the tray are real 3D previews. Drag one over the clay; the ghost snaps to the nearest visible surface and inherits its orientation.")
    _add_info("Available: Base, Plaque, Handle, Star, Wing, Crown")
    _add_info("You can place the same kind more than once, anywhere you want.")
    _add_button("Back to sculpt", _show_sculpt_from_existing)
    _add_button("Ready for paint →", _show_paint)
    _update_progress()

func _show_sculpt_from_existing() -> void:
    mode = SCULPT
    _remove_parts_tray()
    _show_sculpt_controls_only()
    hud_subtitle.text = "Back workshop • Real vertex sculpting"
    hint.text = "LMB sculpt • RMB orbit • MMB pan • wheel zoom • F frames the trophy"

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
        var preview: Node3D = TrophyPartsScript.create_part(part_name, holder, Color("d8b36b"), false)
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
        if not is_instance_valid(holder):
            continue
        if workshop_camera.is_position_behind(holder.global_position):
            continue
        var screen_pos: Vector2 = workshop_camera.unproject_position(holder.global_position)
        var distance: float = screen_pos.distance_to(mouse_pos)
        if distance < best_distance:
            best_distance = distance
            best_name = part_name
    return best_name

func _start_attachment_drag(part_name: String, mouse_pos: Vector2) -> void:
    if trophy_root == null or sculpt_mesh == null:
        return
    attachment_dragging = true
    attachment_part_name = part_name
    attachment_surface_index = -1
    attachment_ghost = TrophyPartsScript.create_part(part_name, trophy_root, Color("8bd7ff"), true)
    attachment_ghost.scale = Vector3.ONE * 0.76
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
    _place_attachment_on_surface(attachment_ghost, vertex_index)

func _finish_attachment_drag(commit: bool) -> void:
    if not attachment_dragging:
        return
    if attachment_ghost != null and is_instance_valid(attachment_ghost):
        if commit and attachment_surface_index >= 0:
            attachment_ghost.name = "Attached_" + attachment_part_name
            TrophyPartsScript.set_color(attachment_ghost, Color("b8b0a7"), false, 0.08)
            attached_parts.append({"node":attachment_ghost,"vertex":attachment_surface_index,"name":attachment_part_name})
            added_parts.append(attachment_part_name)
        else:
            attachment_ghost.queue_free()
    attachment_dragging = false
    attachment_ghost = null
    attachment_part_name = ""
    attachment_surface_index = -1

func _place_attachment_on_surface(part_node: Node3D, vertex_index: int) -> void:
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
    part_node.basis = Basis(x_axis, y_axis, z_axis)
    part_node.position = surface_position + surface_normal * 0.045

func _sync_attached_parts() -> void:
    for record in attached_parts:
        var node_value: Variant = record.get("node")
        if not (node_value is Node3D):
            continue
        var part_node: Node3D = node_value
        if not is_instance_valid(part_node):
            continue
        var vertex_index: int = int(record.get("vertex", -1))
        _place_attachment_on_surface(part_node, vertex_index)

func _show_paint() -> void:
    mode = PAINT
    _remove_parts_tray()
    _clear_right()
    hud_subtitle.text = "Back workshop • Spray the finished mesh"
    hint.text = "Choose a finish and LMB spray • RMB orbit • MMB pan • wheel zoom"
    _add_heading("SPRAY BOOTH")
    _add_info("The spray follows the same 3D surface brush. Attached pieces can also be coated.")
    for finish in ["Gold", "Silver", "Bronze", "Red", "Blue", "Green", "Black", "Ivory"]:
        _add_button(String(finish), _select_finish.bind(String(finish)))
    _add_slider("Spray size", 30.0, 160.0, brush_radius_px, _set_brush_radius)
    _add_button("Finish trophy →", _finish_trophy)
    _update_progress()

func _select_finish(finish: String) -> void:
    selected_finish = finish
    hud_subtitle.text = "Back workshop • Spray: %s" % finish

func _paint_at(mouse_pos: Vector2) -> void:
    if sculpt_mesh == null or workshop_camera == null:
        return
    var paint_color: Color = _finish_color(selected_finish)
    var did_paint: bool = sculpt_mesh.paint_brush(workshop_camera, mouse_pos, brush_radius_px, paint_color, 0.58)
    if selected_finish in ["Gold", "Silver", "Bronze"]:
        sculpt_mesh.set_material_character(0.30, 0.62)
    else:
        sculpt_mesh.set_material_character(0.52, 0.08)
    for record in attached_parts:
        var node_value: Variant = record.get("node")
        if not (node_value is Node3D):
            continue
        var part_node: Node3D = node_value
        if not is_instance_valid(part_node):
            continue
        if workshop_camera.is_position_behind(part_node.global_position):
            continue
        var part_screen: Vector2 = workshop_camera.unproject_position(part_node.global_position)
        if part_screen.distance_to(mouse_pos) <= brush_radius_px:
            var metallic_value: float = 0.68 if selected_finish in ["Gold", "Silver", "Bronze"] else 0.10
            TrophyPartsScript.set_color(part_node, paint_color, false, metallic_value)
            did_paint = true
    if did_paint:
        paint_strokes += 1

func _finish_trophy() -> void:
    var order: Dictionary = orders[current_order % orders.size()]
    if paint_strokes < 4:
        hint.text = "Give it a proper coat first. Four spray strokes minimum."
        return
    trophy_index += 1
    if trophy_index < int(order["count"]):
        _new_blank()
        _show_sculpt()
    else:
        _show_delivery()

func _show_delivery() -> void:
    mode = DELIVERY
    _clear_world_visuals()
    _clear_right()
    _build_shop()
    dialogue_panel.visible = true
    hint.visible = true
    var order: Dictionary = orders[current_order % orders.size()]
    var score: int = 2
    if String(order["required"]) in added_parts:
        score += 1
    if selected_finish == String(order["finish"]):
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
    hint.text = "Customers judge requested detail, finish and how completely you coated the piece."
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
            camera_distance = clampf(camera_distance - 0.45, 2.6, 8.5)
            _update_workshop_camera()
            return
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            camera_distance = clampf(camera_distance + 0.45, 2.6, 8.5)
            _update_workshop_camera()
            return
        if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
            camera_orbiting = mouse_button.pressed
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
                        _apply_sculpt_brush(mouse_button.position)
                elif mode == PARTS:
                    var part_name: String = _part_preview_under_mouse(mouse_button.position)
                    if not part_name.is_empty():
                        _start_attachment_drag(part_name, mouse_button.position)
                elif mode == PAINT:
                    painting = true
                    _paint_at(mouse_button.position)
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
        if camera_orbiting:
            camera_yaw -= motion.relative.x * 0.009
            camera_pitch = clampf(camera_pitch - motion.relative.y * 0.007, -0.80, 1.05)
            _update_workshop_camera()
            return
        if camera_panning:
            _pan_camera(motion.relative)
            return
        if mode == SCULPT and sculpt_stroking:
            if active_tool == "Grab" and active_grab_brush != null:
                sculpt_mesh.apply_grab(workshop_camera, active_grab_brush, motion.relative, get_viewport().get_visible_rect().size.y, 0.90)
                _sync_attached_parts()
            else:
                _apply_sculpt_brush(motion.position)
            return
        if mode == PARTS and attachment_dragging:
            _update_attachment_drag(motion.position)
            return
        if mode == PAINT and painting:
            _paint_at(motion.position)

func _apply_sculpt_brush(mouse_pos: Vector2) -> void:
    if sculpt_mesh == null or workshop_camera == null:
        return
    match active_tool:
        "Clay":
            sculpt_mesh.apply_clay(workshop_camera, mouse_pos, brush_radius_px, brush_strength, clay_subtract)
        "Smooth":
            sculpt_mesh.apply_smooth(workshop_camera, mouse_pos, brush_radius_px, clampf(brush_strength * 7.0, 0.05, 0.72))
        "Crease":
            sculpt_mesh.apply_crease(workshop_camera, mouse_pos, brush_radius_px, brush_strength * 0.80, clay_subtract)
        _:
            pass
    _sync_attached_parts()

func _inside_model_view(mouse_pos: Vector2) -> bool:
    return mouse_pos.x >= 0.0 and mouse_pos.x <= VIEWPORT_LEFT_MAX_X and mouse_pos.y >= VIEWPORT_TOP_Y and mouse_pos.y <= VIEWPORT_BOTTOM_Y

func _frame_workshop_camera() -> void:
    camera_target = Vector3(0.0, 2.55, 0.0)
    camera_yaw = 0.0
    camera_pitch = 0.10
    camera_distance = 5.4
    _update_workshop_camera()

func _update_workshop_camera() -> void:
    if workshop_camera == null:
        return
    var cos_pitch: float = cos(camera_pitch)
    var offset: Vector3 = Vector3(sin(camera_yaw) * cos_pitch, sin(camera_pitch), cos(camera_yaw) * cos_pitch) * camera_distance
    workshop_camera.position = camera_target + offset
    workshop_camera.look_at(camera_target, Vector3.UP)

func _pan_camera(delta: Vector2) -> void:
    if workshop_camera == null:
        return
    var basis: Basis = workshop_camera.global_transform.basis
    var scale_factor: float = 0.0028 * camera_distance
    camera_target += -basis.x * delta.x * scale_factor
    camera_target += basis.y * delta.y * scale_factor
    _update_workshop_camera()

func _refresh_stats() -> void:
    money_label.text = "Cash  $%d" % money
    rep_label.text = "Rep  ★ %d" % reputation

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
        "Gold": return Color("d8a632")
        "Silver": return Color("c8d0d5")
        "Bronze": return Color("a9683d")
        "Red": return Color("bb3c35")
        "Blue": return Color("3e73b8")
        "Green": return Color("4c8a5e")
        "Black": return Color("242426")
        "Ivory": return Color("e8dfc9")
        _: return Color.WHITE
