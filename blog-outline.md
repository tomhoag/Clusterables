# Clustering Map Annotations in SwiftUI — Blog Series Outline

A progressive series that starts with a minimal working app and builds toward a production-quality implementation. Each post adds one focused concern, with code diffs readers can follow along with.

All code references the [Clusterables](https://github.com/tomhoag/Clusterables) package and the Example project in that repo.

---

## Post 1 — Clustering Map Annotations in SwiftUI in Under 100 Lines

**Goal:** Get DBSCAN clustering working on a SwiftUI `Map` with the minimum viable code.

**Concepts introduced:**
- The `Clusterable` protocol — conforming a model type (`City`) so the library knows where each point is
- `ClusterManager<City>` as a `@State` property — the single object that owns clustering state
- `MapReader` / `MapProxy` — why you need a proxy to convert between screen pixels and geographic coordinates
- `MapProxy.degrees(fromPixels:)` — converting a pixel spacing value into the DBSCAN epsilon
- `onMapCameraChange` — triggering a re-cluster every time the user pans or zooms
- `clusterManager.update(_:epsilon:)` — the one call that does all the work
- Rendering clusters vs. single points in a `ForEach` over `clusterManager.clusters`

**Code walkthrough:**
- `City.swift` — `Clusterable` conformance, custom `Codable` for nested coordinate JSON
- `SimpleMapView.swift` — the complete view (~90 lines)
  - Loading JSON from the bundle
  - The `Map` + `MapReader` + `ForEach` structure
  - Single-item clusters rendered as red `Circle()` annotations
  - Multi-item clusters rendered with SF Symbol numbered circles
  - `updateClusters(mapProxy:)` — the two-line function that computes epsilon and calls `update`

**Key takeaway:** With Clusterables, you don't manage annotation views, reuse queues, or coordinate transforms yourself. You call `update`, read `.clusters`, and let SwiftUI render them.

**Repo reference:** `SimpleExample` target

---

## Post 2 — Why Your Map Bogs Down (and How to Debounce Updates)

**Goal:** Understand why the simple approach stutters with rapid camera changes and fix it with an actor-based debounce.

**The problem:**
- `onMapCameraChange` fires continuously during a pan gesture (default frequency)
- Each fire starts a new `clusterManager.update` call
- With thousands of points, overlapping updates compete for CPU time
- The library's internal stale-update cancellation prevents wrong results but doesn't prevent wasted work

**Concepts introduced:**
- `onMapCameraChange(frequency:)` — `.continuous` (default) vs. `.onEnd`, and why `.continuous` with debouncing gives the best UX (updates feel responsive but don't pile up)
- The `UpdateCoordinator` actor — a lightweight debounce primitive
  - `Task.sleep` + `Task.isCancelled` for delay-then-execute
  - Cancelling the previous task when a new update arrives
  - Why an `actor` (not a class with locks) is the right Swift concurrency tool here
- Library-side cancellation vs. caller-side throttling — two different layers, both needed

**Code walkthrough:**
- `UpdateCoordinator.swift` — the full actor (~30 lines)
- Refactoring `SimpleMapView` to route camera changes through the coordinator
- Choosing a debounce delay (150ms as a starting point, tuning advice)

**Key takeaway:** The library guarantees you never see stale results. Debouncing guarantees you don't waste CPU computing results you'll throw away.

**Repo reference:** `Example` target — `UpdateCoordinator.swift`

---

## Post 3 — Cluster Only What's on Screen

**Goal:** Reduce clustering work by filtering to the visible map region before calling `update`.

**The problem:**
- With 33K points loaded, DBSCAN processes all of them even if only 500 are visible
- Zoomed into Michigan? No reason to cluster points in California

**Concepts introduced:**
- `onMapCameraChange { context in }` — extracting `context.region` (the visible `MKCoordinateRegion`)
- Filtering a `[Clusterable]` array to a bounding box
- Antimeridian (International Date Line) handling — why `minLon > maxLon` means the region wraps
- Longitude normalization to [-180, 180]
- Trade-off: points near the visible edge may cluster differently than if the full dataset were considered

**Code walkthrough:**
- `MapRegionHelper.swift` — `filterItems(_:in:)` and `normalizeLongitude(_:)`
- Integrating visible-only filtering into the update path
- Adding a toggle so the user can compare clustered-all vs. clustered-visible

**Key takeaway:** Visible-only filtering is the single biggest performance lever for large datasets on SwiftUI maps. It reduces both clustering time and annotation count.

**Repo reference:** `Example` target — `MapRegionHelper.swift`, visible-only toggle in `ControlsSheetView.swift`

---

## Post 4 — Extracting a View Model with @Observable

**Goal:** Move state out of the view and into a testable, shareable view model.

**The problem:**
- As features accumulate, `@State` properties multiply: cluster manager, camera position, items, visible items, settings, data source info, cached proxy...
- The view becomes hard to read and impossible to unit test

**Concepts introduced:**
- `@Observable` (Observation framework) vs. the older `ObservableObject` / `@Published`
- `@Bindable` for two-way bindings to `@Observable` properties in child views
- Grouping related state with nested structs (`ClusteringSettings`, `DataSource`)
- `@MainActor` on the view model — why map state belongs on the main actor
- Passing the view model to child views vs. environment

**Code walkthrough:**
- `ClusterMapViewModel.swift` — the full view model
  - `ClusteringSettings` struct: `enabled`, `spacing`, `onlyVisible`, `showStatistics`
  - `DataSource` struct: `availableFiles`, `selectedFile`, `isLoading`
  - Cached `MapProxy` and `MKCoordinateRegion`
- Refactoring the view to use `@State private var viewModel = ClusterMapViewModel()`
- Using `@Bindable var viewModel` in sheets/child views for two-way binding

**Key takeaway:** `@Observable` with nested value-type structs gives you fine-grained reactivity without the boilerplate of `@Published`. Group related state to keep the view model scannable.

**Repo reference:** `Example` target — `ClusterMapViewModel.swift`, `ClusterContentView.swift`

---

## Post 5 — Loading Large Datasets Without Freezing the UI

**Goal:** Keep the map responsive while decoding 33K-item JSON files.

**The problem:**
- `JSONDecoder().decode` on a 3MB file blocks the main thread for a noticeable hitch
- Switching data sources mid-session makes it worse: old annotations linger while new data loads

**Concepts introduced:**
- `Task.detached` for CPU-bound work that shouldn't inherit the main actor
- Bundle resource loading with subdirectory support
- Caching decoded results to avoid re-parsing the same file
- Showing a loading overlay: dimmed background + `ProgressView`
- Clearing annotations before loading new data (immediate visual feedback)
- `Task.yield()` to let SwiftUI render the cleared state before starting the load

**Code walkthrough:**
- `Extensions.swift` — `Bundle.decode` and `Bundle.decodeCached`
- `handleFileChange(oldFile:newFile:)` in `ClusterContentView` — the clear-yield-load pattern
- `LoadingOverlayView` — the overlay implementation
- Why `isLoading` lives on the view model's `DataSource` struct

**Key takeaway:** Never decode large files on the main thread. Clear stale UI immediately, show a loading state, then swap in new data.

**Repo reference:** `Example` target — `Extensions.swift`, `ClusterContentView.swift` (handleFileChange, LoadingOverlayView)

---

## Post 6 — Adding a Settings Sheet and Map Controls

**Goal:** Give users runtime control over clustering behavior without cluttering the map.

**Concepts introduced:**
- `.sheet` presentation with `.presentationDetents([.medium])` for half-height
- `.presentationBackgroundInteraction(.enabled)` — interacting with the map while the sheet is open
- `.presentationDragIndicator(.visible)` for discoverability
- `NavigationStack` inside a sheet for title and toolbar
- `Form` with `Toggle`, `Slider`, `Picker` — standard SwiftUI controls
- `.onChange(of:)` to trigger side effects (re-cluster on spacing change, reload on file change)
- `@Bindable` for passing the `@Observable` view model into the sheet
- Matched geometry transition (`.matchedTransitionSource` / `.navigationTransition(.zoom)`)

**Code walkthrough:**
- `ControlsSheetView.swift` — the full sheet view
  - Clustering toggle, spacing slider, data source picker, visible-only toggle, show statistics toggle
  - Callback closures for each action
- `.mapStyle()` and `.mapControls { MapScaleView(); MapCompass() }` on the Map
- Why callbacks instead of putting logic in the sheet (separation of concerns, sheet doesn't own the update coordinator)

**Key takeaway:** Half-height sheets with `.presentationBackgroundInteraction(.enabled)` are ideal for map settings — the user can tweak and see results simultaneously.

**Repo reference:** `Example` target — `ControlsSheetView.swift`, `ClusterContentView.swift` (sheet presentation)

---

## Post 7 — Building a Draggable Statistics Overlay

**Goal:** Display live clustering stats in a floating panel the user can drag anywhere on screen.

**Concepts introduced:**
- `DragGesture` with `.onChanged` / `.onEnded` for smooth dragging
- Separating drag offset (transient) from committed offset (persisted)
- Clamping to container bounds so the overlay can't be dragged off screen
- `.onGeometryChange` to measure both container size and overlay size
- Safe area insets — why `containerSize` alone isn't enough
  - The ZStack lays out within safe area, but we want the overlay to reach physical screen edges
  - Measuring `proxy.safeAreaInsets` and adding them to the clamping bounds
- Persisting position across show/hide toggles (session-only, via view model property)
- `.ultraThinMaterial` background for readability over the map

**Code walkthrough:**
- `StatisticsOverlayView.swift` — the full overlay view
  - Computing `visibleCount`, `cityCount`, `clusterCount`, `outlierCount` from the view model
  - `clampedOffset(_:)` — the clamping math with safe area compensation
  - The drag gesture → commit → clamp cycle
- `ClusterContentView.swift` — measuring `safeAreaInsets` and `containerSize`, passing them to the overlay
- `ClusterMapViewModel.swift` — `statisticsOverlayOffset` property for position persistence
- `StatisticsView` — the pure data-display component

**Key takeaway:** Draggable overlays on maps need three things: a two-phase offset (drag + committed), bounds clamping that accounts for safe area insets, and state that outlives the view's visibility.

**Repo reference:** `Example` target — `StatisticsOverlayView.swift`, `ClusterControlViews.swift` (StatisticsView)

---

## Appendix — Topics for Standalone Posts

These don't fit the progressive build-up but could be standalone companion posts:

### The Annotation Bottleneck
- SwiftUI `Annotation` vs. `Marker` — custom views vs. system-rendered pins
- Why 10K `Annotation` views kill frame rate but 10K `Marker`s are manageable
- When to give up on SwiftUI `Map` and drop to `MKMapView` via `UIViewRepresentable`

### DBSCAN Under the Hood
- How DBSCAN works (epsilon neighborhoods, core points, border points, noise)
- Why KD-Tree accelerates the neighbor search
- The `minimumPoints` parameter and outlier detection
- Coordinate distance approximation and its limits at high latitudes

### Bounding Region Computation
- `boundingRegion()` extension on `[CLLocationCoordinate2D]`
- Handling antimeridian-crossing datasets
- Normalized vs. shifted longitude candidates
- Padding and minimum span to avoid zero-sized regions

### Testing a Clustering Library
- The 44-test suite: what it covers and how to run it
- Testing DBSCAN correctness with known geometric arrangements
- Testing KD-Tree neighbor queries
- Testing stale-update cancellation with concurrent calls
