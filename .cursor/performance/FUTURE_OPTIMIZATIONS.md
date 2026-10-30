# Future performance optimizations

None of these are needed for the app to feel responsive today. They are ordered by expected benefit.

## 1. Prism mesh upload (~12.6 MB per update)

Every year change or policy toggle builds a new `SCNGeometry` in `MergedPrismLayer`: 14,591 cells × 36 vertices × (position + normal, 24 bytes) ≈ 12.6 MB, copied into new GPU buffers. The index buffer is already shared.

Options, best first:

- **Upload only heights.** Keep a static base mesh and pass one height per cell (14.6k floats ≈ 58 KB) to a geometry shader modifier, which scales each prism's vertices and fixes up normals on the GPU. Reduces the upload ~200× and makes height animation nearly free (see 3).
- **Reuse GPU buffers.** Back the geometry sources with persistent `MTLBuffer`s (`SCNGeometrySource(buffer:…)`) and write new vertex data into them, instead of allocating new buffers each time. Needs double-buffering so the renderer never reads a buffer being written.
- **Smaller vertex format.** Half-precision positions and packed normals would roughly halve the size.
- **Diff unchanged cells.** Low value: a policy toggle changes ~26% of cells at 2018 but ~78% at 2036 and ~95% at 2099; year changes affect nearly all cells.

## 2. Local data billboards (`Tooltip`)

Each of the 8 billboards is an `SKScene` (~4,000×700 scene points) used as a SceneKit material. SceneKit re-renders all of them into newly allocated GPU textures every frame: ~40–70 ms of CPU per second plus GPU bandwidth, even when nothing changes.

- **Static image texture.** Render the text into a small `UIImage` only when the value or alignment changes. A first attempt was reverted because the value line was cropped at the bottom and alignment switching became unreliable. A retry must reproduce `SKLabelNode` placement exactly (vertical alignment `.bottom` / `.top` relative to the scene center, `contentsTransform` flip) and keep the fade-and-switch behavior of `align(for:)`. Redrawing all 8 images costs ~30–40 ms on the main thread, so do it off the main thread.
- **Screen-space labels.** Position `UILabel`s over the AR view each frame via `projectPoint`. No 3D rendering cost, sharp text, but needs occlusion handling for locations on the far side of the globe.
- `SCNText` is not recommended: hundreds to thousands of triangles per label and CPU re-tessellation on every text change.

## 3. Height animation

The merged renderer changes heights instantly. With per-cell heights in a shader modifier (see 1), animating between the previous and new heights only needs a blend factor per frame.

## 4. Per-frame main-thread work

- `session(_:didUpdate:)` runs on the main thread at the camera frame rate to update tooltip alignment. It is cheap, but throttling it (e.g. to 10 Hz) or skipping it when tooltips are hidden would further reduce main-thread wakeups.
- Keep any new per-frame logic off the main thread, or only dispatch when something changed. A per-frame `DispatchQueue.main.async` from `renderer(_:updateAtTime:)` was the root cause of the long freezes.

## 5. Rendering settings

`sceneView.contentScaleFactor = 1.3` and `preferredFramesPerSecond = 60` reduce rendering cost but are non-standard. Worth re-evaluating on current devices, together with `antialiasingMode = .multisampling4X`.

## 6. Debug-build speed

The vertex rebuild is ~50× slower in Debug (`-Onone`). If Debug sessions need realistic timings, temporarily set `SWIFT_OPTIMIZATION_LEVEL = -O` for Debug, or move `MergedPrismLayer` into a separately optimized module.
