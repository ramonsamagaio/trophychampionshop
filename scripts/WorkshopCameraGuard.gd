extends Node

# Keeps the workshop camera above the bench while preserving orbit freedom.
# The minimum pitch is computed from current zoom + target height, so the guard
# becomes stricter when the camera is farther away and looser when zoomed in.
const SAFE_CAMERA_Y: float = 1.24
const MIN_TARGET_Y: float = 1.48
const MAX_TARGET_Y: float = 3.85
const ABSOLUTE_MIN_PITCH: float = -0.58

func _process(_delta: float) -> void:
    var main := get_parent()
    if main == null:
        return

    var mode_value: Variant = main.get("mode")
    if mode_value == null or int(mode_value) not in [2, 3, 4]:
        return

    var target_y: float = clampf(float(main.get("camera_target_y")), MIN_TARGET_Y, MAX_TARGET_Y)
    var distance: float = maxf(float(main.get("camera_distance")), 0.1)
    var pitch: float = float(main.get("camera_pitch"))

    var ratio: float = clampf((SAFE_CAMERA_Y - target_y) / distance, -0.95, 0.95)
    var dynamic_min_pitch: float = maxf(ABSOLUTE_MIN_PITCH, asin(ratio))

    var changed := false
    if not is_equal_approx(target_y, float(main.get("camera_target_y"))):
        main.set("camera_target_y", target_y)
        changed = true
    if pitch < dynamic_min_pitch:
        main.set("camera_pitch", dynamic_min_pitch)
        changed = true

    if changed and main.has_method("_update_workshop_camera"):
        main.call("_update_workshop_camera")
