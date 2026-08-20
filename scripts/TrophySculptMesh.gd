class_name TrophySculptMesh
extends MeshInstance3D

const LAT_SEGMENTS: int = 48
const LON_SEGMENTS: int = 80
const CENTER_Y: float = 1.55
const HALF_HEIGHT: float = 1.42
const BASE_RADIUS: float = 0.68

var vertices: PackedVector3Array = PackedVector3Array()
var indices: PackedInt32Array = PackedInt32Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var neighbors: Array = []
var clay_material: StandardMaterial3D
var base_vertices: PackedVector3Array = PackedVector3Array()

func _init() -> void:
    clay_material = StandardMaterial3D.new()
    clay_material.albedo_color = Color.WHITE
    clay_material.roughness = 0.88
    clay_material.metallic = 0.0
    clay_material.vertex_color_use_as_albedo = true
    clay_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    generate_blank()

func generate_blank() -> void:
    vertices = PackedVector3Array()
    indices = PackedInt32Array()
    colors = PackedColorArray()

    # A closed ellipsoid with shared vertices: ~3.8k vertices / ~7.5k triangles.
    vertices.append(Vector3(0.0, CENTER_Y + HALF_HEIGHT, 0.0))
    colors.append(Color("a97952"))

    for ring in range(1, LAT_SEGMENTS):
        var theta: float = PI * float(ring) / float(LAT_SEGMENTS)
        var s: float = sin(theta)
        var y: float = CENTER_Y + cos(theta) * HALF_HEIGHT
        # Slightly fuller lower half gives a friendlier trophy-sized clay blank.
        var profile: float = 0.88 + 0.12 * sin(theta * 0.75)
        var radius: float = BASE_RADIUS * s * profile
        for lon in range(LON_SEGMENTS):
            var phi: float = TAU * float(lon) / float(LON_SEGMENTS)
            vertices.append(Vector3(cos(phi) * radius, y, sin(phi) * radius))
            colors.append(Color("a97952"))

    var bottom_index: int = vertices.size()
    vertices.append(Vector3(0.0, CENTER_Y - HALF_HEIGHT, 0.0))
    colors.append(Color("a97952"))

    # Top cap.
    for lon in range(LON_SEGMENTS):
        var next_lon: int = (lon + 1) % LON_SEGMENTS
        indices.append(0)
        indices.append(1 + next_lon)
        indices.append(1 + lon)

    # Body.
    var interior_rings: int = LAT_SEGMENTS - 1
    for ring in range(interior_rings - 1):
        var ring_a: int = 1 + ring * LON_SEGMENTS
        var ring_b: int = ring_a + LON_SEGMENTS
        for lon in range(LON_SEGMENTS):
            var next_lon: int = (lon + 1) % LON_SEGMENTS
            var a: int = ring_a + lon
            var b: int = ring_a + next_lon
            var c: int = ring_b + lon
            var d: int = ring_b + next_lon
            indices.append(a)
            indices.append(b)
            indices.append(d)
            indices.append(a)
            indices.append(d)
            indices.append(c)

    # Bottom cap.
    var last_ring: int = 1 + (interior_rings - 1) * LON_SEGMENTS
    for lon in range(LON_SEGMENTS):
        var next_lon: int = (lon + 1) % LON_SEGMENTS
        indices.append(bottom_index)
        indices.append(last_ring + lon)
        indices.append(last_ring + next_lon)

    base_vertices = vertices.duplicate()
    _build_neighbors()
    rebuild_mesh()

func reset_blank() -> void:
    vertices = base_vertices.duplicate()
    colors.resize(vertices.size())
    for i in range(colors.size()):
        colors[i] = Color("a97952")
    rebuild_mesh()

func rebuild_mesh() -> void:
    _recalculate_normals()
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var new_mesh: ArrayMesh = ArrayMesh.new()
    new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh = new_mesh
    material_override = clay_material

func _recalculate_normals() -> void:
    normals = PackedVector3Array()
    normals.resize(vertices.size())
    for i in range(normals.size()):
        normals[i] = Vector3.ZERO

    var center: Vector3 = Vector3(0.0, CENTER_Y, 0.0)
    var tri_count: int = int(indices.size() / 3)
    for tri in range(tri_count):
        var ia: int = indices[tri * 3]
        var ib: int = indices[tri * 3 + 1]
        var ic: int = indices[tri * 3 + 2]
        var a: Vector3 = vertices[ia]
        var b: Vector3 = vertices[ib]
        var c: Vector3 = vertices[ic]
        var face: Vector3 = (b - a).cross(c - a)
        var centroid: Vector3 = (a + b + c) / 3.0
        if face.dot(centroid - center) < 0.0:
            face = -face
        normals[ia] += face
        normals[ib] += face
        normals[ic] += face

    for i in range(normals.size()):
        if normals[i].length_squared() < 0.000001:
            normals[i] = (vertices[i] - center).normalized()
        else:
            normals[i] = normals[i].normalized()

func _build_neighbors() -> void:
    var sets: Array = []
    sets.resize(vertices.size())
    for i in range(sets.size()):
        sets[i] = {}

    var tri_count: int = int(indices.size() / 3)
    for tri in range(tri_count):
        var a: int = indices[tri * 3]
        var b: int = indices[tri * 3 + 1]
        var c: int = indices[tri * 3 + 2]
        sets[a][b] = true
        sets[a][c] = true
        sets[b][a] = true
        sets[b][c] = true
        sets[c][a] = true
        sets[c][b] = true

    neighbors = []
    neighbors.resize(vertices.size())
    for i in range(sets.size()):
        neighbors[i] = sets[i].keys()

func get_closest_visible_vertex(camera: Camera3D, screen_pos: Vector2, max_distance_px: float = 80.0) -> int:
    var best_index: int = -1
    var best_distance: float = max_distance_px
    for i in range(vertices.size()):
        var global_pos: Vector3 = to_global(vertices[i])
        if camera.is_position_behind(global_pos):
            continue
        var global_normal: Vector3 = (global_transform.basis * normals[i]).normalized()
        var view_direction: Vector3 = (camera.global_position - global_pos).normalized()
        if global_normal.dot(view_direction) <= 0.02:
            continue
        var projected: Vector2 = camera.unproject_position(global_pos)
        var distance: float = projected.distance_to(screen_pos)
        if distance < best_distance:
            best_distance = distance
            best_index = i
    return best_index

func capture_brush(camera: Camera3D, screen_pos: Vector2, radius_px: float) -> Dictionary:
    var picked_indices: PackedInt32Array = PackedInt32Array()
    var weights: PackedFloat32Array = PackedFloat32Array()
    var center_index: int = get_closest_visible_vertex(camera, screen_pos, radius_px)

    if center_index < 0:
        return {
            "indices": picked_indices,
            "weights": weights,
            "center_index": -1
        }

    for i in range(vertices.size()):
        var global_pos: Vector3 = to_global(vertices[i])
        if camera.is_position_behind(global_pos):
            continue
        var global_normal: Vector3 = (global_transform.basis * normals[i]).normalized()
        var view_direction: Vector3 = (camera.global_position - global_pos).normalized()
        if global_normal.dot(view_direction) <= 0.02:
            continue

        var projected: Vector2 = camera.unproject_position(global_pos)
        var distance: float = projected.distance_to(screen_pos)
        if distance <= radius_px:
            var normalized_distance: float = distance / max(radius_px, 1.0)
            var weight: float = 1.0 - normalized_distance
            weight = weight * weight * (3.0 - 2.0 * weight)
            picked_indices.append(i)
            weights.append(weight)

    return {
        "indices": picked_indices,
        "weights": weights,
        "center_index": center_index
    }

func apply_clay(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float, subtract: bool) -> bool:
    var brush: Dictionary = capture_brush(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    if picked.is_empty():
        return false

    var direction: float = -1.0 if subtract else 1.0
    for n in range(picked.size()):
        var i: int = picked[n]
        vertices[i] += normals[i] * strength * direction * weights[n]

    rebuild_mesh()
    return true

func apply_smooth(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float) -> bool:
    var brush: Dictionary = capture_brush(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    if picked.is_empty():
        return false

    var source: PackedVector3Array = vertices.duplicate()
    for n in range(picked.size()):
        var i: int = picked[n]
        var linked: Array = neighbors[i]
        if linked.is_empty():
            continue
        var average: Vector3 = Vector3.ZERO
        for neighbor_value in linked:
            var neighbor_index: int = int(neighbor_value)
            average += source[neighbor_index]
        average /= float(linked.size())
        var amount: float = clampf(strength * weights[n], 0.0, 0.92)
        vertices[i] = source[i].lerp(average, amount)

    rebuild_mesh()
    return true

func apply_crease(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float, ridge: bool) -> bool:
    var brush: Dictionary = capture_brush(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    var center_index: int = int(brush["center_index"])
    if picked.is_empty() or center_index < 0:
        return false

    var center_point: Vector3 = vertices[center_index]
    var normal_direction: float = 1.0 if ridge else -1.0
    for n in range(picked.size()):
        var i: int = picked[n]
        var w: float = weights[n]
        vertices[i] += normals[i] * strength * normal_direction * w * 1.15

        var toward_center: Vector3 = center_point - vertices[i]
        var tangent: Vector3 = toward_center - normals[i] * toward_center.dot(normals[i])
        vertices[i] += tangent * strength * w * 0.42

    rebuild_mesh()
    return true

func apply_grab(camera: Camera3D, brush: Dictionary, screen_delta: Vector2, viewport_height: float, strength: float) -> bool:
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    var center_index: int = int(brush["center_index"])
    if picked.is_empty() or center_index < 0:
        return false

    var center_global: Vector3 = to_global(vertices[center_index])
    var depth: float = max(camera.global_position.distance_to(center_global), 0.1)
    var world_per_pixel: float = (2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)) / max(viewport_height, 1.0)
    var camera_basis: Basis = camera.global_transform.basis
    var world_delta: Vector3 = camera_basis.x * screen_delta.x * world_per_pixel
    world_delta += -camera_basis.y * screen_delta.y * world_per_pixel
    var local_delta: Vector3 = global_transform.basis.inverse() * world_delta

    for n in range(picked.size()):
        var i: int = picked[n]
        vertices[i] += local_delta * weights[n] * strength

    rebuild_mesh()
    return true

func paint_brush(camera: Camera3D, screen_pos: Vector2, radius_px: float, paint_color: Color, strength: float) -> bool:
    var brush: Dictionary = capture_brush(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    if picked.is_empty():
        return false

    for n in range(picked.size()):
        var i: int = picked[n]
        var amount: float = clampf(strength * weights[n], 0.0, 1.0)
        colors[i] = colors[i].lerp(paint_color, amount)

    rebuild_mesh()
    return true

func set_material_character(roughness: float, metallic: float) -> void:
    clay_material.roughness = roughness
    clay_material.metallic = metallic

func vertex_count() -> int:
    return vertices.size()

func triangle_count() -> int:
    return int(indices.size() / 3)
