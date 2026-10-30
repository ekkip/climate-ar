# Future performance optimizations

None of these are needed for the app to feel responsive today. They are ordered by expected benefit.

## 1. Prism data memory

The static mesh (14,591 cells × 36 vertices × 44 bytes ≈ 22 MB) and the value texture (≈ 25 MB, `r32Float`) are uploaded once. If memory matters on older devices: half-precision values (`r16Float`, check the value range first), half-precision vertex attributes, or deriving the growth vector in the shader from the position would roughly halve both.

## 2. Local data billboards (`Tooltip`)

Each of the 8 billboards is an `SKScene` (~4,000×700 scene points) used as a SceneKit material. SceneKit re-renders all of them into newly allocated GPU textures every frame: ~40–70 ms of CPU per second plus GPU bandwidth, even when nothing changes.

- **Static image texture.** Render the text into a small `UIImage` only when the value or alignment changes. A first attempt was reverted because the value line was cropped at the bottom and alignment switching became unreliable. A retry must reproduce `SKLabelNode` placement exactly (vertical alignment `.bottom` / `.top` relative to the scene center, `contentsTransform` flip) and keep the fade-and-switch behavior of `align(for:)`. Redrawing all 8 images costs ~30–40 ms on the main thread, so do it off the main thread.
- **Screen-space labels.** Position `UILabel`s over the AR view each frame via `projectPoint`. No 3D rendering cost, sharp text, but needs occlusion handling for locations on the far side of the globe.
- `SCNText` is not recommended: hundreds to thousands of triangles per label and CPU re-tessellation on every text change.

## 3. Per-frame main-thread work

- `session(_:didUpdate:)` runs on the main thread at the camera frame rate to update tooltip alignment. It is cheap, but throttling it (e.g. to 10 Hz) or skipping it when tooltips are hidden would further reduce main-thread wakeups.
- Keep any new per-frame logic off the main thread, or only dispatch when something changed. A per-frame `DispatchQueue.main.async` from `renderer(_:updateAtTime:)` was the root cause of the long freezes.

## 4. Rendering settings

`sceneView.contentScaleFactor = 1.3` and `preferredFramesPerSecond = 60` reduce rendering cost but are non-standard. Worth re-evaluating on current devices, together with `antialiasingMode = .multisampling4X`.

## 5. Debug-build speed

The one-time mesh and texture build while loading is much slower in Debug (`-Onone`); updates no longer run CPU-side loops. If Debug load times matter, temporarily set `SWIFT_OPTIMIZATION_LEVEL = -O` for Debug, or move `MergedPrismLayer` into a separately optimized module.
