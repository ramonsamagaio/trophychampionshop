extends Node3D

const SHOP := 0
const SCULPT := 2
const PARTS := 3
const PAINT := 4
const DELIVERY := 5

var mode := SHOP
var current_order := 0
var trophy_index := 0
var money := 35
var reputation := 0
var trophy_root: Node3D
var turntable: Node3D
var body_segments: Array[MeshInstance3D] = []
var segment_radii := [0.42, 0.48, 0.52, 0.54, 0.50, 0.42, 0.30]
var selected_finish := "Gold"
var added_parts: Array[String] = []
var painted_segments: Array[String] = []
var drag_last := Vector2.ZERO
var dragging_turntable := false
var sculpt_add := true

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

var orders := [
    {"customer":"Maya, florist","request":"I run a tiny rooftop flower club. We need two trophies for our annual greenhouse challenge. Make them cheerful and add a star somewhere.","count":2,"finish":"Gold","required":"Star","label":"GREENHOUSE CHAMPION"},
    {"customer":"Dante, bike courier","request":"Our messenger crew is racing across town this weekend. I want one trophy that feels fast. Silver, with wings if you can manage it.","count":1,"finish":"Silver","required":"Wings","label":"CITY SPRINT"},
    {"customer":"Nina, drummer","request":"My garage-band club finally has a proper battle night. Three trophies, all bronze. Give them chunky handles so they look gloriously over-serious.","count":3,"finish":"Bronze","required":"Handles","label":"LOUDER THAN RENT"}
]

func _ready() -> void:
    _build_environment()
    _build_ui()
    _show_shop()

func _build_environment() -> void:
    world = Node3D.new()
    world.name = "World"
    add_child(world)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("201912")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("ffe0b0")
    e.ambient_light_energy = 0.62
    env.environment = e
    world.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-48, -25, 0)
    light.light_color = Color("ffd7a0")
    light.light_energy = 1.0
    light.shadow_enabled = true
    world.add_child(light)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0, 3.8, 3.5)
    fill.light_color = Color("ffb56b")
    fill.omni_range = 9.0
    fill.light_energy = 5.0
    world.add_child(fill)
    _make_box(Vector3(10, 0.2, 9), Vector3(0, -0.1, 0), Color("5b3927"), "Floor")
    _make_box(Vector3(10, 5, 0.2), Vector3(0, 2.5, -4.4), Color("3a2620"), "BackWall")
    _make_box(Vector3(0.2, 5, 9), Vector3(-4.9, 2.5, 0), Color("3a2620"), "LeftWall")
    _make_box(Vector3(0.2, 5, 9), Vector3(4.9, 2.5, 0), Color("3a2620"), "RightWall")

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    var top := PanelContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_bottom = 86
    ui.add_child(top)
    var topbox := HBoxContainer.new()
    topbox.add_theme_constant_override("separation", 24)
    top.add_child(topbox)
    var titlebox := VBoxContainer.new()
    titlebox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topbox.add_child(titlebox)
    var title := Label.new()
    title.text = "TROPHY CHAMPIONSHOP"
    title.add_theme_font_size_override("font_size", 27)
    titlebox.add_child(title)
    hud_subtitle = Label.new()
    hud_subtitle.text = "Tiny shop. Huge victories. Questionable craftsmanship."
    hud_subtitle.modulate = Color("d9bf9c")
    titlebox.add_child(hud_subtitle)
    money_label = Label.new()
    rep_label = Label.new()
    topbox.add_child(money_label)
    topbox.add_child(rep_label)
    right_panel = PanelContainer.new()
    right_panel.position = Vector2(930, 105)
    right_panel.size = Vector2(320, 470)
    ui.add_child(right_panel)
    right_box = VBoxContainer.new()
    right_box.add_theme_constant_override("separation", 10)
    right_panel.add_child(right_box)
    dialogue_panel = PanelContainer.new()
    dialogue_panel.position = Vector2(75, 500)
    dialogue_panel.size = Vector2(810, 175)
    ui.add_child(dialogue_panel)
    var dbox := VBoxContainer.new()
    dialogue_panel.add_child(dbox)
    dialogue_name = Label.new()
    dialogue_name.add_theme_font_size_override("font_size", 21)
    dbox.add_child(dialogue_name)
    dialogue_text = Label.new()
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dbox.add_child(dialogue_text)
    hint = Label.new()
    hint.position = Vector2(75, 458)
    hint.size = Vector2(810, 35)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.modulate = Color("f6d69a")
    ui.add_child(hint)
    progress_label = Label.new()
    progress_label.position = Vector2(930, 590)
    progress_label.size = Vector2(320, 55)
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ui.add_child(progress_label)
    _refresh_stats()

func _clear_world_visuals() -> void:
    for c in world.get_children():
        if c.name.begins_with("Dynamic"):
            c.queue_free()
    trophy_root = null
    turntable = null
    body_segments.clear()

func _clear_right() -> void:
    for c in right_box.get_children():
        c.queue_free()

func _show_shop() -> void:
    mode = SHOP
    _clear_world_visuals()
    _clear_right()
    dialogue_panel.visible = true
    hint.visible = true
    right_panel.visible = true
    _build_shop()
    var order: Dictionary = orders[current_order % orders.size()]
    dialogue_name.text = order.customer
    dialogue_text.text = order.request
    hud_subtitle.text = "Front counter • New commission waiting"
    hint.text = "Read the request, then accept the commission."
    _add_heading("ORDER TICKET")
    _add_info("Quantity: %d" % order.count)
    _add_info("Requested finish: %s" % order.finish)
    _add_info("Requested detail: %s" % order.required)
    _add_info("Plaque: %s" % order.label)
    _add_button("Accept commission", _accept_order)
    _add_button("Next customer", _next_customer)
    progress_label.text = "Counter"
    _refresh_stats()

func _build_shop() -> void:
    var dynamic := Node3D.new()
    dynamic.name = "DynamicShop"
    world.add_child(dynamic)
    _camera_at(dynamic, Vector3(0, 2.6, 5.6), Vector3(0, 1.55, 0))
    _make_box(Vector3(7.4, 1.25, 0.85), Vector3(0, 0.65, 1.45), Color("6e4128"), "DynamicCounter", dynamic)
    _make_box(Vector3(7.1, 0.14, 1.05), Vector3(0, 1.32, 1.45), Color("9c6037"), "DynamicCounterTop", dynamic)
    for side in [-1.0, 1.0]:
        for y in [1.0, 2.15, 3.3]:
            _make_box(Vector3(2.8, 0.12, 0.62), Vector3(side * 3.15, y, -3.95), Color("7d4b2f"), "DynamicShelf", dynamic)
            for i in range(4):
                _mini_trophy(dynamic, Vector3(side * 3.15 - 0.95 + i * 0.62, y + 0.25, -3.55), [Color("c88b32"), Color("bdc4c9"), Color("a66a3e")][(i + int(y)) % 3])
    _customer(dynamic, Vector3(0, 0, -0.15))

func _customer(parent: Node3D, pos: Vector3) -> void:
    var root := Node3D.new()
    root.name = "DynamicCustomer"
    root.position = pos
    parent.add_child(root)
    _mesh_sphere(root, Vector3(0, 2.0, 0), 0.42, Color("ddb58c"))
    _mesh_cylinder(root, Vector3(0, 1.0, 0), 0.62, 0.46, 1.35, Color("42677a"))
    _mesh_box(root, Vector3(0, 0.18, 0), Vector3(0.95, 0.38, 0.55), Color("3b2c27"))

func _accept_order() -> void:
    trophy_index = 0
    _new_blank()
    _show_sculpt()

func _new_blank() -> void:
    added_parts.clear()
    painted_segments.clear()
    segment_radii = [0.42, 0.48, 0.52, 0.54, 0.50, 0.42, 0.30]
    selected_finish = "Gold"

func _next_customer() -> void:
    current_order = (current_order + 1) % orders.size()
    _show_shop()

func _show_sculpt() -> void:
    mode = SCULPT
    _build_workshop()
    _clear_right()
    dialogue_panel.visible = false
    hud_subtitle.text = "Back workshop • Shape the clay blank"
    hint.text = "LEFT DRAG adds clay • RIGHT DRAG removes • SHIFT + LEFT DRAG rotates only the turntable"
    _add_heading("SCULPTING")
    _add_info("Shape the silhouette. The camera stays fixed; only the turntable rotates.")
    _add_button("Add clay tool", _set_sculpt_add.bind(true))
    _add_button("Carve tool", _set_sculpt_add.bind(false))
    _add_button("Reset blank", _reset_shape)
    _add_button("Shape looks good →", _show_parts)
    _update_progress()

func _set_sculpt_add(value: bool) -> void:
    sculpt_add = value

func _build_workshop() -> void:
    _clear_world_visuals()
    var dynamic := Node3D.new()
    dynamic.name = "DynamicWorkshop"
    world.add_child(dynamic)
    _camera_at(dynamic, Vector3(0, 2.55, 5.2), Vector3(0, 1.45, 0))
    _make_box(Vector3(7.5, 0.18, 3.6), Vector3(0, 0.78, 0), Color("4a3025"), "DynamicBench", dynamic)
    _make_box(Vector3(0.3, 2.1, 3.2), Vector3(-3.4, -0.18, 0), Color("35241e"), "DynamicBenchLeg", dynamic)
    _make_box(Vector3(0.3, 2.1, 3.2), Vector3(3.4, -0.18, 0), Color("35241e"), "DynamicBenchLeg", dynamic)
    for x in [-2.8, -2.1, 2.1, 2.8]:
        _mini_trophy(dynamic, Vector3(x, 1.15, -1.1), Color("6f6a62"))
    turntable = Node3D.new()
    turntable.name = "DynamicTurntable"
    turntable.position = Vector3(0, 0.95, 0)
    dynamic.add_child(turntable)
    _mesh_cylinder(turntable, Vector3.ZERO, 1.15, 1.08, 0.26, Color("4f5357"))
    trophy_root = Node3D.new()
    trophy_root.name = "TrophyRoot"
    trophy_root.position = Vector3(0, 0.18, 0)
    turntable.add_child(trophy_root)
    _rebuild_trophy_body()

func _rebuild_trophy_body() -> void:
    for s in body_segments:
        if is_instance_valid(s):
            s.queue_free()
    body_segments.clear()
    if trophy_root == null:
        return
    for i in range(segment_radii.size()):
        var mesh := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        var r: float = segment_radii[i]
        cyl.top_radius = r * 0.93
        cyl.bottom_radius = r
        cyl.height = 0.34
        cyl.radial_segments = 24
        mesh.mesh = cyl
        mesh.position.y = 0.17 + i * 0.33
        mesh.material_override = _mat(Color("9b6f4a"), 0.82, 0.0)
        trophy_root.add_child(mesh)
        body_segments.append(mesh)
    var top := MeshInstance3D.new()
    top.name = "ClayTop"
    var sphere := SphereMesh.new()
    sphere.radius = 0.34
    sphere.height = 0.68
    top.mesh = sphere
    top.position.y = 2.45
    top.material_override = _mat(Color("9b6f4a"), 0.82, 0.0)
    trophy_root.add_child(top)
    _rebuild_parts()

func _reset_shape() -> void:
    segment_radii = [0.42, 0.48, 0.52, 0.54, 0.50, 0.42, 0.30]
    _rebuild_trophy_body()

func _show_parts() -> void:
    mode = PARTS
    _clear_right()
    hud_subtitle.text = "Back workshop • Add prefabricated trophy parts"
    hint.text = "Click parts to snap them onto your handmade body. Add as many as you like."
    _add_heading("TROPHY PARTS")
    for part in ["Base", "Plaque", "Handles", "Star", "Wings", "Crown"]:
        _add_button("+ " + part, _toggle_part.bind(part))
    _add_button("Ready for paint →", _show_paint)
    _update_progress()

func _toggle_part(part: String) -> void:
    if part in added_parts:
        added_parts.erase(part)
    else:
        added_parts.append(part)
    _rebuild_trophy_body()

func _rebuild_parts() -> void:
    if trophy_root == null:
        return
    for c in trophy_root.get_children():
        if c.name.begins_with("Part_"):
            c.queue_free()
    if "Base" in added_parts:
        _mesh_box(trophy_root, Vector3(0, -0.02, 0), Vector3(1.35, 0.24, 1.05), Color("2f2624"), "Part_Base")
    if "Plaque" in added_parts:
        _mesh_box(trophy_root, Vector3(0, 0.10, 0.56), Vector3(0.86, 0.34, 0.08), Color("c59a49"), "Part_Plaque")
    if "Handles" in added_parts:
        for side in [-1.0, 1.0]:
            var tor := MeshInstance3D.new()
            tor.name = "Part_Handle"
            var tm := TorusMesh.new()
            tm.inner_radius = 0.23
            tm.outer_radius = 0.34
            tm.rings = 16
            tm.ring_segments = 12
            tor.mesh = tm
            tor.position = Vector3(side * 0.62, 1.65, 0)
            tor.rotation_degrees = Vector3(90, 0, 0)
            tor.scale = Vector3(0.85, 1.2, 1.0)
            tor.material_override = _mat(_finish_color(selected_finish), 0.25, 0.7)
            trophy_root.add_child(tor)
    if "Star" in added_parts:
        _mesh_sphere(trophy_root, Vector3(0, 2.9, 0), 0.30, _finish_color(selected_finish), "Part_Star")
        for a in range(0, 360, 72):
            var spike := _mesh_box(trophy_root, Vector3(0, 2.9, 0), Vector3(0.12, 0.58, 0.12), _finish_color(selected_finish), "Part_StarSpike")
            spike.rotation_degrees.z = a
    if "Wings" in added_parts:
        for side in [-1.0, 1.0]:
            var wing := _mesh_box(trophy_root, Vector3(side * 0.62, 1.85, 0), Vector3(0.75, 0.18, 0.35), _finish_color(selected_finish), "Part_Wing")
            wing.rotation_degrees.z = side * 24
    if "Crown" in added_parts:
        for x in [-0.28, 0.0, 0.28]:
            var spike := _mesh_cylinder(trophy_root, Vector3(x, 2.82, 0), 0.09, 0.0, 0.55, _finish_color(selected_finish), "Part_Crown")
            spike.rotation_degrees.z = -x * 35.0

func _show_paint() -> void:
    mode = PAINT
    _clear_right()
    hud_subtitle.text = "Back workshop • Spray finish"
    hint.text = "Choose a finish, then LEFT DRAG vertically over the trophy to spray individual sections."
    _add_heading("SPRAY BOOTH")
    for finish in ["Gold", "Silver", "Bronze", "Red", "Blue", "Green", "Black", "Ivory"]:
        _add_button(finish, _select_finish.bind(finish))
    _add_button("Finish trophy →", _finish_trophy)
    _update_progress()

func _select_finish(finish: String) -> void:
    selected_finish = finish
    _rebuild_trophy_body()

func _finish_trophy() -> void:
    var order: Dictionary = orders[current_order % orders.size()]
    if painted_segments.size() < 3:
        hint.text = "Give it at least a little paint first. The clay-brown special is not trending."
        return
    trophy_index += 1
    if trophy_index < int(order.count):
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
    var score := 2
    if order.required in added_parts:
        score += 1
    if selected_finish == order.finish:
        score += 1
    if painted_segments.size() >= 5:
        score += 1
    score = clamp(score, 1, 5)
    var stars := "★".repeat(score) + "☆".repeat(5 - score)
    var payout := 18 * int(order.count) + score * 7
    money += payout
    reputation += score
    dialogue_name.text = order.customer
    dialogue_text.text = "These are mine?! %s\n\nYou earned $%d for the commission." % [stars, payout]
    hud_subtitle.text = "Front counter • Delivery complete"
    hint.text = "Customers judge requested detail, finish and how completely you painted the piece."
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
    progress_label.text = "Trophy %d / %d" % [trophy_index + 1, order.count]

func _input(event: InputEvent) -> void:
    if mode not in [SCULPT, PARTS, PAINT]:
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed):
            dragging_turntable = event.pressed
            drag_last = event.position
        elif mode == SCULPT and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
            if event.pressed and event.position.x < 900:
                sculpt_add = event.button_index == MOUSE_BUTTON_LEFT
                _sculpt_at(event.position)
        elif mode == PAINT and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.position.x < 900:
            _paint_at(event.position)
    elif event is InputEventMouseMotion:
        if dragging_turntable and turntable:
            var dx: float = event.position.x - drag_last.x
            turntable.rotation_degrees.y += dx * 0.55
            drag_last = event.position
        elif mode == SCULPT and (event.button_mask & MOUSE_BUTTON_MASK_LEFT or event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
            _sculpt_at(event.position)
        elif mode == PAINT and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
            _paint_at(event.position)

func _sculpt_at(pos: Vector2) -> void:
    if pos.x > 900 or pos.y < 105 or pos.y > 590:
        return
    var t := clamp((590.0 - pos.y) / 485.0, 0.0, 1.0)
    var idx := clamp(int(t * segment_radii.size()), 0, segment_radii.size() - 1)
    var delta := 0.018 if sculpt_add else -0.018
    segment_radii[idx] = clamp(segment_radii[idx] + delta, 0.16, 0.90)
    _rebuild_trophy_body()

func _paint_at(pos: Vector2) -> void:
    if pos.x > 900 or pos.y < 105 or pos.y > 590 or body_segments.is_empty():
        return
    var t := clamp((590.0 - pos.y) / 485.0, 0.0, 1.0)
    var idx := clamp(int(t * body_segments.size()), 0, body_segments.size() - 1)
    painted_segments = painted_segments.filter(func(v): return not str(v).begins_with("%d:" % idx))
    painted_segments.append("%d:%s" % [idx, selected_finish])
    body_segments[idx].material_override = _mat(_finish_color(selected_finish), 0.22 if selected_finish in ["Gold", "Silver", "Bronze"] else 0.48, 0.75 if selected_finish in ["Gold", "Silver", "Bronze"] else 0.15)

func _refresh_stats() -> void:
    money_label.text = "Cash  $%d" % money
    rep_label.text = "Rep  ★ %d" % reputation

func _add_heading(text: String) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 20)
    right_box.add_child(l)

func _add_info(text: String) -> void:
    var l := Label.new()
    l.text = text
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_box.add_child(l)

func _add_button(text: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = 42
    b.pressed.connect(callback)
    right_box.add_child(b)

func _camera_at(parent: Node3D, pos: Vector3, target: Vector3) -> void:
    var cam := Camera3D.new()
    cam.name = "DynamicCamera"
    cam.position = pos
    parent.add_child(cam)
    cam.look_at(target)
    cam.current = true
    cam.fov = 48

func _mat(color: Color, rough := 0.55, metallic := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metallic
    return m

func _make_box(size: Vector3, pos: Vector3, color: Color, name := "DynamicBox", parent: Node3D = null) -> MeshInstance3D:
    if parent == null:
        parent = world
    return _mesh_box(parent, pos, size, color, name)

func _mesh_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, name := "Box") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = _mat(color)
    parent.add_child(mi)
    return mi

func _mesh_sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, name := "Sphere") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name
    var sm := SphereMesh.new()
    sm.radius = radius
    sm.height = radius * 2.0
    mi.mesh = sm
    mi.position = pos
    mi.material_override = _mat(color)
    parent.add_child(mi)
    return mi

func _mesh_cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color, name := "Cylinder") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name
    var cm := CylinderMesh.new()
    cm.bottom_radius = bottom
    cm.top_radius = top
    cm.height = height
    cm.radial_segments = 24
    mi.mesh = cm
    mi.position = pos
    mi.material_override = _mat(color, 0.35, 0.45 if color.get_luminance() > 0.45 else 0.1)
    parent.add_child(mi)
    return mi

func _mini_trophy(parent: Node3D, pos: Vector3, color: Color) -> void:
    var r := Node3D.new()
    r.name = "DynamicMiniTrophy"
    r.position = pos
    parent.add_child(r)
    _mesh_box(r, Vector3(0, 0.05, 0), Vector3(0.42, 0.10, 0.34), Color("2d2523"))
    _mesh_cylinder(r, Vector3(0, 0.24, 0), 0.12, 0.10, 0.34, color)
    _mesh_sphere(r, Vector3(0, 0.48, 0), 0.15, color)

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
