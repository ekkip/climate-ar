# Globe performance — measurement protocol

## Which build to use

- **Feel and responsiveness:** Release build, launched from the home screen without Xcode attached (Edit Scheme → Run → Build Configuration: Release, uncheck "Debug executable"; or Product → Profile, which already uses Release).
- **Logs and breakpoints:** Debug build from Xcode. The `[GlobePerf]` logs exist only in Debug. Timings are much slower than Release, and debugger pauses (worse over Wi-Fi) can show up as long hitches.
- Prefer a USB cable over wireless debugging when profiling.

## Console logs (Debug)

Filter the Xcode console for: `[GlobePerf]`, `[GlobeMergedPerf]`, `[GlobeYearPerf]`, `[ClimatePolicyPerf]`.

- `[GlobeMergedPerf] setup` (merged renderer, default): printed once while loading, with the one-time mesh and value-texture build time and sizes. Updates have no per-update cost to log; judge them by smoothness and the `hitches during …` lines.
- `[GlobePerf] hitches during <operation>`: main-thread frame gaps over 50 ms during the 3 seconds after a year change or policy toggle starts (a new operation closes the previous window early). `stallMs` is the total time lost beyond one frame per hitch. Also reports thermal state and Low Power Mode.
- `[GlobeYearPerf]` / `[ClimatePolicyPerf]`: only with `Globe.useMergedPrismRenderer = false` (per-node path).

The SceneKit statistics overlay (`showsStatistics`) stays off: with the fractional `contentScaleFactor` it trips Metal API validation. To see draw calls, use Xcode's GPU frame capture while the globe is visible.

## Instruments

| Template | Use it for | What to look at |
|---|---|---|
| Time Profiler | CPU cost of app code | Hangs track; Call Tree with "Separate by Thread" + "Invert Call Tree" |
| Metal System Trace | GPU load, compositor | App vs `backboardd` GPU activity; long GPU intervals |
| System Trace | Freezes with idle threads | Main-thread states (Blocked/Running), run-loop mode, UIKit `_UIUpdateSequence` activity |
| Allocations / Leaks | Memory | Growth across repeated loads |

Points of Interest signposts (Debug): `GlobeLoadModel`, `MergedPrismBuild` (one-time setup), `GlobeYearRefresh`, `GlobeYearAnimation`, `ClimatePolicyToggle`.

## Protocol

1. **Cold load:** kill the app, launch fresh, wait until the globe is loadable. Note `[GlobePerf] GlobeLoadModel` ms, prism count (~14591), resident MB.
2. **Repeated appearance:** background and foreground 5 times. Expect no second `GlobeLoadModel` and flat memory.
3. **Timeline and policy:** scrub to 2018, let scrolling stop, toggle policy on and off; repeat at 2036 and 2099. Note the `hitches during …` line and whether a freeze was felt.
4. **Local data:** repeat step 3 with "Display local data" on and off.
5. **A/B against the per-node path:** set `Globe.useMergedPrismRenderer = false`, repeat step 3, compare draw calls, hitch lines, and memory.

**Expect:** prisms are one draw call in a GPU frame capture; `apply(main)` stays small; hitch windows show few or no gaps over 50 ms; in Release, scroll and toggle respond immediately.

## Reference values (iPhone, iOS 27.2, October 2026)

- Load: ~2.3–6 s (Debug), 367–530 MB resident after load.
- Rebuild: 150–250 ms Debug, 2–14 ms Release.
- Background CPU after placement (Release): ~0.32 cores, mostly ARKit world tracking.
