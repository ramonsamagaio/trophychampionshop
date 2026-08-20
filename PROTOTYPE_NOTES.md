# Trophy Championshop — Prototype Notes

## Implemented loop

1. Customer arrives at the tiny trophy-filled shop counter with a commission.
2. Player accepts the ticket and moves to the back workshop.
3. Sculpt a real deformable 3D clay mesh.
4. Drag physical prefabricated trophy parts from the workshop tray and attach them wherever desired on the clay surface.
5. Spray-paint the sculpted mesh and attached pieces with metallic or normal finishes.
6. Repeat for multi-trophy orders.
7. Return to the counter, deliver the order, receive a 1–5 star rating, cash, and reputation.

## Sculpting mesh

The current clay blank is one closed shared-vertex mesh with 3,762 vertices and 7,520 triangles. It is intentionally modest enough for frequent CPU-side deformation while retaining enough local density for recognizable silhouettes, grooves and smaller features.

Each sculpt stroke changes the actual vertex positions, then rebuilds the ArrayMesh and recalculates smooth normals. The prototype exposes four fundamental brushes:

- Clay: adds or subtracts volume along surface normals.
- Smooth: relaxes vertices toward their connected neighbors.
- Grab: pulls a captured patch through the camera plane to change silhouette and proportions.
- Crease: cuts grooves or creates raised ridges while pinching toward the brush center.

Brush radius and strength are adjustable from the right panel.

## Workshop controls

- Left mouse: use the current sculpt brush, drag an attachment, or spray paint depending on the current workshop stage.
- Right mouse drag: orbit the workshop camera around the trophy.
- Middle mouse drag: pan the camera target.
- Mouse wheel: dolly/zoom in and out.
- F: frame the trophy and restore a useful default workshop view.
- Clay/Crease mode button: switch Clay between add/subtract and Crease between groove/ridge.

## Attachment workflow

The attachment stage now displays Base, Plaque, Handle, Star, Wing and Crown as actual 3D preview objects on a workshop tray. Click and drag a preview toward the trophy. While dragging, a translucent copy snaps to the nearest visible sculpt vertex, follows the surface position and aligns itself to the local surface normal.

When released over a valid surface point, that geometry becomes a real child of the trophy and stores the sculpt vertex it is anchored to. If the player returns to sculpting and deforms the clay, attached pieces are repositioned and reoriented from that updated vertex/normal instead of remaining suspended at their old world position.

This pass is a surface-anchored attachment system, not a destructive Boolean topology union. A later remesh/voxel/SDF pass can weld attachments into the same topology if the design requires literal fused geometry.

## Painting

Painting now uses the same projected 3D brush selection as sculpting. The clay stores vertex colors, allowing local spray coverage instead of the old vertical segment coloring. Metallic finishes also change the material character of the sculpted body. Attached pieces are coated when the spray brush passes over their projected screen position.

## Prototype content

Three original order archetypes are included: a rooftop flower-club commission, a bike-courier race commission and a garage-band battle commission. Each requests different quantities, finishes, plaque copy and decorative details.

## Running

Open the repository folder in Godot 4.x and run the project. The prototype still uses procedural Godot geometry and materials, so there are no external art dependencies required for this workshop pass.

A GitHub Actions workflow is included to boot the project headlessly with Godot 4.6.3 on pushes to `prototype/playable-shop-loop`. This catches many parser/startup failures before a local pull, although the visual and interaction feel still needs to be tested in the desktop editor.

## Next production steps

Profile sculpt performance on the target desktop; replace brute-force projected vertex searches with a spatial acceleration structure if needed; add a visible brush cursor; support undo/redo and sculpt history; improve attached-part transform controls after placement; optionally weld attachments through voxel/SDF remeshing; add true spray particles/masking; save finished trophies to a shelf/gallery; improve semantic customer scoring; add economy, upgrades, deadlines, queue management and recurring customers.
