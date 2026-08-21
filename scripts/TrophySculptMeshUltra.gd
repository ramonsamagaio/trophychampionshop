extends MeshInstance3D

# Welded cube-sphere topology. Unlike the old latitude/longitude sphere, this has
# no singular top/bottom pole and distributes vertices much more evenly.
const CUBE_RESOLUTION: int = 128
const CENTER_Y: float = 1.52
const HALF_HEIGHT: float = 1.36
const BASE_RADIUS: float = 0.76

var vertices: PackedVector3Array = PackedVector3Array()
var indices: PackedInt32Array = PackedInt32Array()
var normals: PackedVector3Array = PackedVector3Array()
# RGB = paint colour, A = metallic amount.
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

uniform bool sculpt_preview = true;
uniform vec3 sculpt_clay_color : source_color = vec3(0.47, 0.445, 0.415);

void fragment() {
    if (sculpt_preview) {
        // Neutral clay is deliberately less saturated than the shop palette.
        // A tiny view-normal modulation helps shallow forms read while the
        // actual three-point light rig still supplies the primary modelling.
        float view_shape = clamp(NORMAL.z * 0.5 + 0.5, 0.0, 1.0);
        ALBEDO = sculpt_clay_color * mix(0.90, 1.05, view_shape);
        METALLIC = 0.0;
        ROUGHNESS = 0.67;
        SPECULAR = 0.32;
        RIM = 0.10;
        RIM_TINT = 0.18;
    } else {
        ALBEDO = COLOR.rgb;
        METALLIC = clamp(COLOR.a, 0.0, 1.0);
        ROUGHNESS = mix(0.74, 0.15, COLOR.a);
        SPECULAR = 0.62;
        RIM = 0.06;
        RIM_TINT = 0.20;
    }
}
"""
    sculpt_material.shader = shader
    generate_blank()

func set_sculpt_preview(enabled: bool) -> void:
    sculpt_material.set_shader_parameter("sculpt_preview", enabled)

func generate_blank() -> void:
    vertices = PackedVector3Array()
    indices = PackedInt32Array()
    colors = PackedColorArray()

    var lookup: Dictionary = {}
    var clay_color: Color = Color("8d8379")
    clay_color.a = 0.0

    for face in range(6):
        var face_grid: PackedInt32Array = PackedInt32Array()
        face_grid.resize((CUBE_RESOLUTION + 1) * (CUBE_RESOLUTION + 1))

        for j in range(CUBE_RESOLUTION + 1):
            for i in range(CUBE_RESOLUTION + 1):
                var cube_key: Vector3i = _cube_coord(face, i, j)
                var vertex_index: int
                if lookup.has(cube_key):
                    vertex_index = int(lookup[cube_key])
                else:
                    var cube_pos: Vector3 = Vector3(cube_key) / float(CUBE_RESOLUTION)
                    var unit: Vector3 = cube_pos.normalized()
                    var sculpt_pos: Vector3 = Vector3(
                        unit.x * BASE_RADIUS,
                        CENTER_Y + unit.y * HALF_HEIGHT,
                        unit.z * BASE_RADIUS
                    )
                    vertex_index = vertices.size()
                    lookup[cube_key] = vertex_index
                    vertices.append(sculpt_pos)
                    colors.append(clay_color)
                face_grid[j * (CUBE_RESOLUTION + 1) + i] = vertex_index

        for j in range(CUBE_RESOLUTION):
            for i in range(CUBE_RESOLUTION):
                var row: int = CUBE_RESOLUTION + 1
                var a: int = face_grid[j * row + i]
                var b: int = face_grid[j * row + i + 1]
                var c: int = face_grid[(j + 1) * row + i]
                var d: int = face_grid[(j + 1) * row + i + 1]
                _append_outward_triangle(a, b, d)
                _append_outward_triangle(a, d, c)

    base_vertices = vertices.duplicate()
    _build_neighbors()
    rebuild_mesh()

func _cube_coord(face: int, i: int, j: int) -> Vector3i:
    var a: int = -CUBE_RESOLUTION + i * 2
    var b: int = -CUBE_RESOLUTION + j * 2
    match face:
        0: return Vector3i(CUBE_RESOLUTION, b, -a)   # +X
        1: return Vector3i(-CUBE_RESOLUTION, b, a)   # -X
        2: return Vector3i(a, CUBE_RESOLUTION, -b)   # +Y
        3: return Vector3i(a, -CUBE_RESOLUTION, b)   # -Y
        4: return Vector3i(a, b, CUBE_RESOLUTION)    # +Z
        _: return Vector3i(-a, b, -CUBE_RESOLUTION)  # -Z

func _append_outward_triangle(a: int, b: int, c: int) -> void:
    var pa: Vector3 = vertices[a]
    var pb: Vector3 = vertices[b]
    var pc: Vector3 = vertices[c]
    var face_normal: Vector3 = (pb - pa).cross(pc - pa)
    var centroid: Vector3 = (pa + pb + pc) / 3.0
    var radial: Vector3 = centroid - Vector3(0.0, CENTER_Y, 0.0)
    if face_normal.dot(radial) < 0.0:
        indices.append(a)
        indices.append(c)
        indices.append(b)
    else:
        indices.append(a)
        indices.append(b)
        indices.append(c)

func reset_blank() -> void:
    vertices = base_vertices.duplicate()
    colors.resize(vertices.size())
    var clay_color: Color = Color("8d8379")
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

    var tri_count: int = int(indices.size() / 3)
    for tri in range(tri_count):
        var ia: int = indices[tri * 3]
        var ib: int = indices[tri * 3 + 1]
        var ic: int = indices[tri * 3 + 2]
        var a: Vector3 = vertices[ia]
        var b: Vector3 = vertices[ib]
        var c: Vector3 = vertices[ic]
        # Keep the original topology winding. The previous centre-based face
        # flipping could create shading discontinuities after concave edits.
        var face: Vector3 = (b - a).cross(c - a)
        normals[ia] += face
        normals[ib] += face
        normals[ic] += face

    var center: Vector3 = Vector3(0.0, CENTER_Y, 0.0)
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

func _outward_normal(index: int) -> Vector3:
    var normal: Vector3 = normals[index]
    var radial: Vector3 = vertices[index] - Vector3(0.0, CENTER_Y, 0.0)
    if normal.dot(radial) < 0.0:
        normal = -normal
    return normal.normalized()

func _is_front_facing(camera: Camera3D, index: int) -> bool:
    var global_pos: Vector3 = to_global(vertices[index])
    if camera.is_position_behind(global_pos):
        return false
    var global_normal: Vector3 = (global_transform.basis * _outward_normal(index)).normalized()
    var view_direction: Vector3 = (camera.global_position - global_pos).normalized()
    return global_normal.dot(view_direction) > 0.012

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
        var score: float = pixel_distance + depth * 0.18
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
    var cursor: int = 0

    while cursor < queue.size():
        var i: int = queue[cursor]
        cursor += 1
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
                if not visited.has(neighbor_index) and vertices[neighbor_index].distance_to(center_point) <= local_radius * 1.08:
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
    var center_normal: Vector3 = _outward_normal(center_index)
    for n in range(picked.size()):
        var i: int = picked[n]
        var direction: Vector3 = center_normal.lerp(_outward_normal(i), 0.30).normalized()
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
        var amount: float = clampf(strength * weights[n], 0.0, 0.82)
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
    var center_normal: Vector3 = _outward_normal(center_index)
    var direction_sign: float = 1.0 if ridge else -1.0
    for n in range(picked.size()):
        var i: int = picked[n]
        var w: float = weights[n]
        var direction: Vector3 = center_normal.lerp(_outward_normal(i), 0.22).normalized()
        vertices[i] += direction * strength * direction_sign * w
        var toward_center: Vector3 = center_point - vertices[i]
        var local_normal: Vector3 = _outward_normal(i)
        var tangent: Vector3 = toward_center - local_normal * toward_center.dot(local_normal)
        vertices[i] += tangent * strength * w * 0.24

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
        vertices[picked[n]] += local_delta * weights[n] * strength

    rebuild_mesh()
    return true

# Potter-wheel mode. The touched point determines only the Y band. The effect is
# repeated around the whole circumference while the platform visually spins.
func _lathe_band(camera: Camera3D, screen_pos: Vector2, radius_px: float) -> Dictionary:
    var center_index: int = get_closest_visible_vertex(camera, screen_pos, minf(radius_px, 44.0))
    if center_index < 0:
        return {"indices":PackedInt32Array(), "weights":PackedFloat32Array(), "center_index":-1}
    var band_radius: float = _local_radius_for_pixels(camera, center_index, radius_px) * 0.68
    var center_y: float = vertices[center_index].y
    var picked: PackedInt32Array = PackedInt32Array()
    var weights: PackedFloat32Array = PackedFloat32Array()
    for i in range(vertices.size()):
        var dy: float = absf(vertices[i].y - center_y)
        if dy <= band_radius:
            var t: float = 1.0 - dy / maxf(band_radius, 0.0001)
            t = t * t * (3.0 - 2.0 * t)
            picked.append(i)
            weights.append(t)
    return {"indices":picked, "weights":weights, "center_index":center_index}

func _radial_xz(index: int) -> Vector3:
    var radial: Vector3 = Vector3(vertices[index].x, 0.0, vertices[index].z)
    if radial.length_squared() < 0.000001:
        return _outward_normal(index)
    return radial.normalized()

func apply_lathe_clay(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float, subtract: bool) -> bool:
    var band: Dictionary = _lathe_band(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = band["indices"]
    var weights: PackedFloat32Array = band["weights"]
    if picked.is_empty():
        return false
    var sign_value: float = -1.0 if subtract else 1.0
    for n in range(picked.size()):
        var i: int = picked[n]
        vertices[i] += _radial_xz(i) * strength * sign_value * weights[n]
    rebuild_mesh()
    return true

func apply_lathe_smooth(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float) -> bool:
    var band: Dictionary = _lathe_band(camera, screen_pos, radius_px)
    var picked: PackedInt32Array = band["indices"]
    var weights: PackedFloat32Array = band["weights"]
    if picked.is_empty():
        return false

    # For a wheel, smoothing primarily evens the radius around each touched band.
    var radius_sum: float = 0.0
    var weight_sum: float = 0.0
    for n in range(picked.size()):
        var i: int = picked[n]
        var r: float = Vector2(vertices[i].x, vertices[i].z).length()
        radius_sum += r * weights[n]
        weight_sum += weights[n]
    var target_radius: float = radius_sum / maxf(weight_sum, 0.0001)

    for n in range(picked.size()):
        var i: int = picked[n]
        var radial: Vector3 = _radial_xz(i)
        var current_radius: float = Vector2(vertices[i].x, vertices[i].z).length()
        var amount: float = clampf(strength * weights[n], 0.0, 0.88)
        var new_radius: float = lerpf(current_radius, target_radius, amount)
        vertices[i].x = radial.x * new_radius
        vertices[i].z = radial.z * new_radius
    rebuild_mesh()
    return true

func apply_lathe_crease(camera: Camera3D, screen_pos: Vector2, radius_px: float, strength: float, ridge: bool) -> bool:
    var band: Dictionary = _lathe_band(camera, screen_pos, maxf(radius_px * 0.58, 5.0))
    var picked: PackedInt32Array = band["indices"]
    var weights: PackedFloat32Array = band["weights"]
    if picked.is_empty():
        return false
    var sign_value: float = 1.0 if ridge else -1.0
    for n in range(picked.size()):
        var i: int = picked[n]
        vertices[i] += _radial_xz(i) * strength * sign_value * weights[n]
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
