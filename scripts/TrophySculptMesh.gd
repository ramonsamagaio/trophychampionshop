class_name TrophySculptMesh
extends MeshInstance3D

# Extra-high-resolution sculpt blank: 61,122 vertices / 122,240 triangles.
# The higher density is aimed at cleaner small details, creases and lettering.
const LAT_SEGMENTS: int = 192
const LON_SEGMENTS: int = 320
const CENTER_Y: float = 1.52
const HALF_HEIGHT: float = 1.36
const BASE_RADIUS: float = 0.76

var vertices: PackedVector3Array = PackedVector3Array()
var indices: PackedInt32Array = PackedInt32Array()
var normals: PackedVector3Array = PackedVector3Array()
# RGB = albedo, A = metallic amount. A custom shader turns this into real PBR metal.
var colors: PackedColorArray = PackedColorArray()
var neighbors: Array = []
var base_vertices: PackedVector3Array = PackedVector3Array()
var sculpt_material: ShaderMaterial

func _init() -> void:
    sculpt_material = ShaderMaterial.new()
    var shader: Shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled;

void fragment() {
    ALBEDO = COLOR.rgb;
    METALLIC = clamp(COLOR.a, 0.0, 1.0);
    ROUGHNESS = mix(0.76, 0.16, COLOR.a);
    SPECULAR = 0.62;
    RIM = 0.10;
    RIM_TINT = 0.35;
    // Tiny floor of bounced light keeps sculpt detail readable without flattening it.
    EMISSION = COLOR.rgb * 0.022;
}
"""
    sculpt_material.shader = shader
    generate_blank()

func generate_blank() -> void:
    vertices = PackedVector3Array()
    indices = PackedInt32Array()
    colors = PackedColorArray()

    var clay_color: Color = Color("a97952")
    clay_color.a = 0.0
    vertices.append(Vector3(0.0, CENTER_Y + HALF_HEIGHT, 0.0))
    colors.append(clay_color)

    for ring in range(1, LAT_SEGMENTS):
        var theta: float = PI * float(ring) / float(LAT_SEGMENTS)
        var s: float = sin(theta)
        var y: float = CENTER_Y + cos(theta) * HALF_HEIGHT
        var profile: float = 0.92 + 0.08 * sin(theta * 0.78)
        var radius: float = BASE_RADIUS * s * profile
        for lon in range(LON_SEGMENTS):
            var phi: float = TAU * float(lon) / float(LON_SEGMENTS)
            vertices.append(Vector3(cos(phi) * radius, y, sin(phi) * radius))
            colors.append(clay_color)

    var bottom_index: int = vertices.size()
    vertices.append(Vector3(0.0, CENTER_Y - HALF_HEIGHT, 0.0))
    colors.append(clay_color)

    for lon in range(LON_SEGMENTS):
        var next_lon: int = (lon + 1) % LON_SEGMENTS
        indices.append(0)
        indices.append(1 + next_lon)
        indices.append(1 + lon)

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
    var clay_color: Color = Color("a97952")
    clay_color.a = 0.0
    for i in range(colors.size()):
        colors[i] = clay_color
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
    material_override = sculpt_material

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

func _is_front_facing(camera: Camera3D, index: int) -> bool:
    var global_pos: Vector3 = to_global(vertices[index])
    if camera.is_position_behind(global_pos):
        return false
    var global_normal: Vector3 = (global_transform.basis * normals[index]).normalized()
    var view_direction: Vector3 = (camera.global_position - global_pos).normalized()
    return global_normal.dot(view_direction) > 0.015

func get_closest_visible_vertex(camera: Camera3D, screen_pos: Vector2, max_distance_px: float = 80.0) -> int:
    var best_index: int = -1
    var best_score: float = INF
    for i in range(vertices.size()):
        if not _is_front_facing(camera, i):
            continue
        var global_pos: Vector3 = to_global(vertices[i])
        var projected: Vector2 = camera.unproject_position(global_pos)
        var pixel_distance: float = projected.distance_to(screen_pos)
        if pixel_distance > max_distance_px:
            continue
        var depth: float = camera.global_position.distance_to(global_pos)
        # Pixel accuracy dominates; depth breaks ties toward the visible front layer.
        var score: float = pixel_distance + depth * 0.22
        if score < best_score:
            best_score = score
            best_index = i
    return best_index

func _local_radius_for_pixels(camera: Camera3D, center_index: int, radius_px: float) -> float:
    var center_global: Vector3 = to_global(vertices[center_index])
    var depth: float = maxf(camera.global_position.distance_to(center_global), 0.1)
    var viewport_height: float = maxf(camera.get_viewport().get_visible_rect().size.y, 1.0)
    var world_per_pixel: float = (2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)) / viewport_height
    var scale_average: float = (global_transform.basis.x.length() + global_transform.basis.y.length() + global_transform.basis.z.length()) / 3.0
    return radius_px * world_per_pixel / maxf(scale_average, 0.001)

func capture_brush(camera: Camera3D, screen_pos: Vector2, radius_px: float) -> Dictionary:
    var picked_indices: PackedInt32Array = PackedInt32Array()
    var weights: PackedFloat32Array = PackedFloat32Array()
    var center_index: int = get_closest_visible_vertex(camera, screen_pos, minf(radius_px, 42.0))
    if center_index < 0:
        return {"indices":picked_indices, "weights":weights, "center_index":-1}

    var local_radius: float = _local_radius_for_pixels(camera, center_index, radius_px)
    var center_point: Vector3 = vertices[center_index]
    var queue: Array[int] = [center_index]
    var visited: Dictionary = {center_index:true}
    var queue_cursor: int = 0

    while queue_cursor < queue.size():
        var i: int = queue[queue_cursor]
        queue_cursor += 1
        var distance: float = vertices[i].distance_to(center_point)
        if distance <= local_radius:
            var normalized_distance: float = distance / maxf(local_radius, 0.0001)
            var weight: float = 1.0 - normalized_distance
            weight = weight * weight * (3.0 - 2.0 * weight)
            if _is_front_facing(camera, i):
                picked_indices.append(i)
                weights.append(weight)
            var linked: Array = neighbors[i]
            for neighbor_value in linked:
                var neighbor_index: int = int(neighbor_value)
                if not visited.has(neighbor_index):
                    # Do not flood across the far side of thin geometry.
                    if vertices[neighbor_index].distance_to(center_point) <= local_radius * 1.08:
                        visited[neighbor_index] = true
                        queue.append(neighbor_index)

    return {"indices":picked_indices, "weights":weights, "center_index":center_index}

func apply_clay(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float, subtract: bool) -> bool:
    var brush: Dictionary = capture_brush(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    var center_index: int = int(brush["center_index"])
    if picked.is_empty() or center_index < 0:
        return false

    var sign_value: float = -1.0 if subtract else 1.0
    var center_normal: Vector3 = normals[center_index]
    for n in range(picked.size()):
        var i: int = picked[n]
        # Shared brush direction keeps a clay stroke cohesive instead of growing spikes.
        var direction: Vector3 = center_normal.lerp(normals[i], 0.34).normalized()
        vertices[i] += direction * strength * sign_value * weights[n]

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
            average += source[int(neighbor_value)]
        average /= float(linked.size())
        var amount: float = clampf(strength * weights[n], 0.0, 0.84)
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
    var center_normal: Vector3 = normals[center_index]
    var normal_direction: float = 1.0 if ridge else -1.0
    for n in range(picked.size()):
        var i: int = picked[n]
        var w: float = weights[n]
        var direction: Vector3 = center_normal.lerp(normals[i], 0.25).normalized()
        vertices[i] += direction * strength * normal_direction * w
        var toward_center: Vector3 = center_point - vertices[i]
        var tangent: Vector3 = toward_center - normals[i] * toward_center.dot(normals[i])
        vertices[i] += tangent * strength * w * 0.28

    rebuild_mesh()
    return true

func apply_grab(camera: Camera3D, brush: Dictionary, screen_delta: Vector2, viewport_height: float, strength: float) -> bool:
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    var center_index: int = int(brush["center_index"])
    if picked.is_empty() or center_index < 0:
        return false

    var center_global: Vector3 = to_global(vertices[center_index])
    var depth: float = maxf(camera.global_position.distance_to(center_global), 0.1)
    var world_per_pixel: float = (2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)) / maxf(viewport_height, 1.0)
    var camera_basis: Basis = camera.global_transform.basis
    var world_delta: Vector3 = camera_basis.x * screen_delta.x * world_per_pixel
    world_delta += -camera_basis.y * screen_delta.y * world_per_pixel
    var local_delta: Vector3 = global_transform.basis.inverse() * world_delta

    for n in range(picked.size()):
        var i: int = picked[n]
        vertices[i] += local_delta * weights[n] * strength

    rebuild_mesh()
    return true

func paint_brush(camera: Camera3D, screen_pos: Vector2, radius_px: float, paint_color: Color, metallic: float, strength: float) -> bool:
    var brush: Dictionary = capture_brush(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = brush["indices"]
    var weights: PackedFloat32Array = brush["weights"]
    if picked.is_empty():
        return false

    var target: Color = paint_color
    target.a = clampf(metallic, 0.0, 1.0)
    for n in range(picked.size()):
        var i: int = picked[n]
        var amount: float = clampf(strength * weights[n], 0.0, 1.0)
        colors[i] = colors[i].lerp(target, amount)

    rebuild_mesh()
    return true

func vertex_count() -> int:
    return vertices.size()

func triangle_count() -> int:
    return int(indices.size() / 3)
