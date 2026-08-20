class_name TrophyParts
extends RefCounted

static func create_part(part_name: String, parent: Node3D, color: Color, preview: bool = false) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "Part_" + part_name
    parent.add_child(root)

    match part_name:
        "Base":
            _box(root, Vector3(0.0, 0.0, 0.16), Vector3(1.05, 0.28, 0.58), color, preview)
            _box(root, Vector3(0.0, 0.18, 0.10), Vector3(0.78, 0.12, 0.46), color, preview)
        "Plaque":
            _box(root, Vector3(0.0, 0.0, 0.08), Vector3(0.92, 0.48, 0.10), color, preview)
            _box(root, Vector3(0.0, 0.0, 0.02), Vector3(1.02, 0.56, 0.05), color.darkened(0.18), preview)
        "Handle":
            var torus: MeshInstance3D = MeshInstance3D.new()
            var torus_mesh: TorusMesh = TorusMesh.new()
            torus_mesh.inner_radius = 0.23
            torus_mesh.outer_radius = 0.36
            torus_mesh.rings = 24
            torus_mesh.ring_segments = 18
            torus.mesh = torus_mesh
            torus.rotation_degrees.x = 90.0
            torus.position.z = 0.08
            torus.material_override = _material(color, preview, 0.0)
            root.add_child(torus)
        "Star":
            _sphere(root, Vector3(0.0, 0.0, 0.10), 0.22, color, preview)
            for angle in range(0, 360, 72):
                var spike: MeshInstance3D = _box(root, Vector3(0.0, 0.0, 0.10), Vector3(0.13, 0.58, 0.13), color, preview)
                spike.rotation_degrees.z = float(angle)
        "Wing":
            for i in range(4):
                var feather: MeshInstance3D = _box(
                    root,
                    Vector3(0.16 + float(i) * 0.16, -float(i) * 0.105, 0.08),
                    Vector3(0.54 - float(i) * 0.07, 0.14, 0.10),
                    color,
                    preview
                )
                feather.rotation_degrees.z = -15.0 - float(i) * 7.0
        "Crown":
            _box(root, Vector3(0.0, -0.16, 0.09), Vector3(0.78, 0.20, 0.12), color, preview)
            for x in [-0.30, -0.15, 0.0, 0.15, 0.30]:
                var spike: MeshInstance3D = _cylinder(root, Vector3(float(x), 0.12, 0.10), 0.075, 0.0, 0.46, color, preview)
                spike.rotation_degrees.x = 90.0
        _:
            _sphere(root, Vector3.ZERO, 0.24, color, preview)

    return root

static func set_color(root: Node3D, color: Color, preview: bool = false, metallic: float = 0.0) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh_child: MeshInstance3D = child
            mesh_child.material_override = _material(color, preview, metallic)
        elif child is Node3D:
            set_color(child, color, preview, metallic)

static func _material(color: Color, preview: bool, metallic: float = 0.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = lerpf(0.48, 0.17, clampf(metallic, 0.0, 1.0))
    material.metallic_specular = 0.62
    if preview:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.albedo_color.a = 0.52
        material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    return material

static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, preview: bool) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = size
    instance.mesh = box
    instance.position = pos
    instance.material_override = _material(color, preview)
    parent.add_child(instance)
    return instance

static func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, preview: bool) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    sphere.radial_segments = 24
    sphere.rings = 16
    instance.mesh = sphere
    instance.position = pos
    instance.material_override = _material(color, preview)
    parent.add_child(instance)
    return instance

static func _cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color, preview: bool) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    var cylinder: CylinderMesh = CylinderMesh.new()
    cylinder.bottom_radius = bottom
    cylinder.top_radius = top
    cylinder.height = height
    cylinder.radial_segments = 24
    instance.mesh = cylinder
    instance.position = pos
    instance.material_override = _material(color, preview)
    parent.add_child(instance)
    return instance
