# Trophy Championshop — Prototype Notes

## Implemented loop

1. Customer arrives at the tiny trophy-filled shop counter with a commission.
2. Player accepts the ticket and moves to the back workshop.
3. Sculpt the trophy blank on a fixed camera turntable.
4. Add prefabricated classic trophy parts: base, plaque, handles, star, wings, crown.
5. Spray-paint sections with gold, silver, bronze, or normal colors.
6. Repeat for multi-trophy orders.
7. Return to the counter, deliver the order, receive a 1–5 star rating, cash, and reputation.

## Controls

- Left-drag over trophy: add clay while sculpting.
- Right-drag over trophy: remove clay while sculpting.
- Shift + left-drag, or middle-drag: rotate the turntable. The camera itself never orbits.
- Paint phase: choose a finish, then left-drag vertically over the trophy to spray sections.
- Right-side buttons advance through sculpting, parts, paint, and delivery.

## Prototype content

Three original order archetypes are included for the first playable pass: a rooftop flower-club commission, a bike-courier race commission, and a garage-band battle commission. Each requests different quantities, finishes, plaque copy, and decorative details.

## Running

Open the repository folder in Godot 4.x and run the project (`F6/F5`). The prototype uses only procedural Godot primitive meshes, materials, lighting, and UI, so there are no external art dependencies yet.

## Next production steps

Replace placeholder customer geometry with stylized characters and animations; turn the shop/workshop transition into actual player locomotion; replace profile-slice sculpting with a denser deformable mesh or voxel/SDF sculpt layer; add true spray particles and masking; save finished trophy meshes to a shelf/gallery; expand scoring so customers judge proportions and semantic resemblance; add economy, upgrades, deadlines, queue management, and recurring customers.
