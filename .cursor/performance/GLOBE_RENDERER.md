# Globe rendering and the October 2026 freeze investigation

## Summary

The app froze for seconds (sometimes tens of seconds) after timeline scrolls and climate-policy toggles. Several independent problems contributed; the long UI freezes had a single root cause that was only visible in a System Trace.

| Problem | Effect | Fix |
|---|---|---|
| One SceneKit node per prism (~13k visible) | 13k draw calls, multi-second render-lock stalls on updates | `MergedPrismLayer`: one static mesh, heights computed on the GPU |
| Parsing 74 MB of REMIND JSON | ~6M short-lived objects, seconds of load time, 560+ MB | Binary `Data/REMIND_cells.bin` |
| Globe could load twice | Duplicate prisms and memory | Load guards in `Globe` / `ViewController` |
| Plane detection kept running after placement | On LiDAR devices: scene reconstruction + neural segmentation, ~0.5 CPU cores | `stopPlaneDetection()` after placing; Restart re-enables |
| `renderer(_:updateAtTime:)` queued a main-thread block every frame | **Root cause of the long freezes** (see below) | Main-thread work only when focus square, lighting, or debug visualization actually change |

## Root cause of the long freezes

SceneKit's render thread dispatched a block to the main thread on every frame (~60/s), even after the globe was placed. Each block set `scene.lightingEnvironment.intensity` and ran the focus-square update.

A System Trace during a freeze showed:

- The main thread was idle and never blocked; it woke ~60 times per second for under a millisecond.
- UIKit's per-frame update cycle (`_UIUpdateSequence`: touch delivery, layout, animations, CA commits) stopped for 5–17 s.
- SceneKit's own display link for the AR view kept firing (50–75/s), so the camera image and globe kept tracking.
- Input arrived seconds late: a scroll ending at ~10 s was applied at 14 s; a toggle at ~18 s was processed at 26 s.
- A Metal System Trace showed the system compositor (`backboardd`) idle during such a freeze, while the app's GPU load was steady at ~20%.

After limiting the per-frame dispatch (`ViewController.renderer(_:updateAtTime:)`), the freezes disappeared. The exact mechanism inside iOS that starved UIKit's update ticks is not visible in app-targeted traces.

## Merged prism renderer

`Globe.useMergedPrismRenderer` (default `true`) draws all ~14.6k cells as one mesh in `MergedPrismLayer`:

- One draw call for all prisms. Mesh and values are built once while the globe loads; no vertex data is rebuilt afterwards.
- Each vertex stores its prism's position at value 0, its change per unit value (prism shape is linear in the value) in the color channel, and its cell index in the texture coordinate. Normals do not depend on the value.
- An `r32Float` texture holds one row per cell: base series for every year, then the policy series from the first policy year on (≈ 25 MB). A geometry shader modifier reads the two years around the displayed fractional year, interpolates linearly, blends base and policy series, and positions the vertex. Values at or below the threshold collapse the prism just inside the globe.
- The displayed state is two uniforms: `prismYear` (fractional year index) and `prismPolicy` (0 = base, 1 = policy series). Scrubbing the timeline (`Globe.scrubYear`) sets the year on every scroll step. Year changes and policy toggles animate the state linearly (0.5 s; 0.25 s to settle on the rounded year after scrolling) with an `SCNAction` on the render thread, so intermediate years are shown on the way. A new update starts from the state last drawn; a generation counter keeps a replaced animation from overwriting it.
- Only the 8 tooltip locations keep a `Prism` node (mesh hidden). `onStateChanged` positions them from the same interpolation; labels show the rounded year.
- SceneKit requires a texture-coordinate source as soon as a texture is bound to the material ("Vertex attribute texcoord0 is missing" otherwise), which is why the cell index lives there.
- `LiveGlobeUpdates` enables scrubbing on A12 or newer (Metal GPU family Apple 5) unless Low Power Mode is on or the thermal state is serious or critical; otherwise the globe updates after the scroll ends. Launch argument `-LiveGlobeUpdates YES` / `NO` overrides the check.

Set the flag to `false` to compare against the per-node path (a GPU frame capture in Xcode shows the draw-call difference).

Earlier versions rebuilt the vertex data on every update (2–14 ms in Release on device plus a 12.6–19 MB upload). That kept up on an A20 Pro while scrubbing but stuttered on an A17 Pro, which led to the value texture.

## Data file

The app loads `Data/REMIND_cells.bin` (25 MB, float32 values) instead of parsing the two REMIND JSON files (74 MB). The JSON files remain the source data; after changing them, run `python3 Scripts/convert_remind_json.py`.

## Lessons for measuring

- Judge responsiveness in a **Release** build launched from the home screen. Debug builds are 50× slower in the rebuild loop, and an attached debugger (especially over Wi-Fi) adds multi-second pauses that users never see.
- The SceneKit statistics overlay (`showsStatistics`) crashes under Metal API validation because of the fractional `contentScaleFactor`; use a GPU frame capture instead.
- Time Profiler only records running threads. When the app "freezes" but every thread is idle, use **System Trace** (thread states, run-loop activity) and **Metal System Trace** (GPU and compositor activity).
- Instruments traces can be analyzed from the command line: `xcrun xctrace export --input <file>.trace --toc`, then export individual tables (`time-profile`, `runloop-events`, `thread-state`, `metal-gpu-intervals`, `potential-hangs`) with `--xpath`.

See `FUTURE_OPTIMIZATIONS.md` for remaining ideas and `PERF_BASELINE.md` for the measurement protocol.
