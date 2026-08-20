# Trophy Championshop — Prototype Notes

## Current workshop pass

The core loop remains counter → commission → workshop → sculpt → attach parts → paint/letter → delivery.

### Sculpting mesh

The clay blank is now a closed deformable mesh with 24,386 vertices and 48,768 triangles. Sculpt edits are throttled slightly so the higher density stays usable on desktop.

The four brushes are Clay Add/Subtract, Smooth, Grab and Crease. Brush selection now grows across a connected patch of the visible mesh instead of modifying every projected vertex under the cursor. Clay also uses a shared brush direction blended with local normals. Those two changes are specifically intended to stop the long spikes and folded sheets seen in the August 20 test recording.

### Sculpt viewport and lighting

Workshop walls are hidden while sculpting/attaching/painting so the camera can orbit freely. The camera always orbits a target locked to the trophy's vertical axis. Middle-mouse pan only moves that target up/down; there is no horizontal drift. Mouse wheel zooms and F restores the default frame.

The workshop uses a neutral three-point sculpt-light rig instead of the warm shop lighting. Light angle is exposed as a slider in the workshop panels and can also be rotated around the trophy with Shift + right-mouse drag. Right-mouse drag without Shift orbits the camera.

### Attachments

Base, Plaque, Handle, Star, Wing and Crown remain draggable physical previews. After placement an attached part can be selected and customized with:

- Spin around the surface normal.
- Tilt X and Tilt Y.
- Uniform size.
- Embed depth, including pushing the part farther into the main clay or pulling it outward.

The attachment stays anchored to its sculpt vertex and follows that point and normal if the clay is edited afterward.

### Paint and lettering

The sculpt body now uses a custom PBR shader. Vertex RGB stores paint color and vertex alpha stores metallic amount, so Gold, Silver and Bronze can be genuinely metallic per painted area instead of changing the whole trophy material at once.

Paint mode has two tools:

- Spray: broad coating that also coats attached hardware.
- Pen: small high-resolution freehand surface brush for drawing or handwriting directly on the trophy. Pen size and color are selectable.

Metallic finishes use high metallic response and low roughness. Normal colors remain non-metallic.

## Controls

- LMB: sculpt / drag attachment / spray or draw depending on stage.
- RMB drag: orbit camera around the trophy.
- MMB drag: vertical-only pan.
- Shift + RMB drag: rotate the sculpt light rig.
- Wheel: zoom.
- F: frame/reset workshop camera.

## Performance note

This pass deliberately raises the sculpt to ~24k vertices to test the desired fidelity. The current implementation still performs CPU-side vertex search, normal recalculation and ArrayMesh rebuilds. If this density feels good visually but strokes are too slow, the next engineering pass should keep the same or higher resolution and optimize the edit pipeline with a spatial acceleration structure and partial/local mesh updates rather than dropping visual fidelity.
