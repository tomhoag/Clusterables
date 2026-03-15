# Clusterables

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftomhoag%2FClusterables%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/tomhoag/Clusterables)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftomhoag%2FClusterables%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/tomhoag/Clusterables)

A SwiftUI-native package for clustering MapKit map points — no UIViewRepresentable required. Keeps your maps fast, clean, and easy to navigate no matter how many points you're displaying. Because clustering is density-based, groups form naturally around real geographic concentrations — not arbitrary grid boundaries (I'm looking at you quad-tree).

Powered by **DBSCAN** (Density-Based Spatial Clustering of Applications with Noise) paired with a **KD-Tree** for fast spatial lookups. This combination means clustering is both accurate and efficient — DBSCAN naturally handles clusters of varying shapes and sizes, while the KD-Tree keeps nearest-neighbor searches fast even with thousands of points.

![Demo](example.gif)
---

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

---

## Installation

### Swift Package Manager

In Xcode, go to **File → Add Package Dependencies** and enter the repository URL:

```
https://github.com/tomhoag/Clusterables
```

---

## Getting Started

Follow these steps to add clustering to your SwiftUI map. The general flow is: wrap your data in a `Clusterable` type, add a `ClusterManager` to your view, then drive your map annotations from the manager's output.

### Step 1 — Conform your model to `Clusterable`

Any point type that you want to cluster on the map must conform to the `Clusterable` protocol by exposing a `CLLocationCoordinate2D`:

```swift
struct City: Clusterable {
    var name: String
    var coordinate: CLLocationCoordinate2D
}
```

### Step 2 — Add a `ClusterManager` to your view

Add a `ClusterManager` as a `@State` property, specifying the `Clusterable` type it will manage:

```swift
struct ContentView: View {

    @State var clusterManager = ClusterManager<City>()

    // ...
}
```

### Step 3 — Wrap your `Map` in a `MapReader`

`MapReader` gives you a `mapProxy`, which you can use to convert screen-space pixel spacing to geographic degrees for clustering:

```swift
MapReader { mapProxy in
    Map(position: $cameraPosition, interactionModes: .all) {
        // ...
    }
}
```

### Step 4 — Render clusters, outliers, and individual annotations

Iterate over `clusterManager.clusters` to build your map annotations. When a cluster contains a single item (`size == 1`), it is rendered using a red circle. When it contains multiple items, it is rendered using a `ClusterAnnotationView` (found in the Example project).

If you use a `minimumPoints` value greater than 1 (see Step 5), points that don't meet the density threshold are placed in `clusterManager.outliers` instead of forming single-item clusters. Render them separately:

```swift
Map(position: $cameraPosition, interactionModes: .all) {
    ForEach(clusterManager.clusters) { cluster in
        if cluster.size == 1, let city = cluster.items.first {
            // Single point — show a regular annotation
            Annotation(city.name, coordinate: city.coordinate) {
                Circle()
                    .foregroundColor(.red)
                    .frame(width: 7)
            }
        } else {
            // Multiple points — show a cluster annotation
            Annotation("", coordinate: cluster.center) {
                ClusterAnnotationView(size: cluster.size)
            }
        }
    }

    // Outliers — points that didn't meet the minimumPoints threshold
    ForEach(clusterManager.outliers, id: \.self) { city in
        Annotation(city.name, coordinate: city.coordinate) {
            Circle()
                .foregroundColor(.gray)
                .frame(width: 7)
        }
    }
}
```

### Step 5 — Trigger cluster updates

Call `clusterManager.update` whenever the map appears, the camera position changes, or whenever you want to update the clusters.

**Parameters:**
- **`epsilon`** — The clustering distance in degrees. Items closer than this are grouped together. Use `MapProxy.degrees(fromPixels:)` to convert screen-space pixel spacing to degrees at the current zoom level.
- **`minimumPoints`** *(optional, default: `1`)* — The minimum number of neighbors required for a point to be a core point. With the default of `1`, every point belongs to a cluster. Increase this to require denser groupings — isolated points that don't meet the threshold are placed in `clusterManager.outliers`.

```swift
.onAppear {
    Task {
        cameraPosition = .region(mapRegion)
        if let epsilon = mapProxy.degrees(fromPixels: spacing) {
            await clusterManager.update(items, epsilon: epsilon)
        }
    }
}
.onMapCameraChange(frequency: .onEnd) { _ in
    Task {
        if let epsilon = mapProxy.degrees(fromPixels: spacing) {
            await clusterManager.update(items, epsilon: epsilon, minimumPoints: 3)
        }
    }
}
```

The `update` method can be called from any context. Clustering runs on a background thread, and results are published on the main actor.

### Stale update cancellation

When `update` is called while a previous update is still running, the earlier update is automatically discarded — its results are never returned. This happens at multiple levels: before DBSCAN starts, during the main clustering loop, during cluster expansion, and before results are written to the UI. Only the most recent call's results are ever returned.

This is **not debouncing**. The library does not delay or throttle calls to `update`. Every call starts immediately. The library's responsibility is ensuring that only the latest results are returned to the caller — it does not decide *when* or *how often* `update` should be called. That is left to the caller.

If your UI triggers updates rapidly (for example, during continuous map panning), you should debounce or throttle on your side before calling `update`. The Example project demonstrates this with an `UpdateCoordinator` actor that cancels and restarts a delayed task on each camera change. The library's internal cancellation is a safety net that prevents stale results from briefly flashing on screen, not a substitute for call-site throttling.

---

## Example Apps

Clone this repo and open `Example/Example.xcodeproj`. The project contains two targets:

### SimpleExample

A minimal app that demonstrates Clusterables in under 100 lines of code. It loads 1,813 US cities from bundled JSON, displays them on a map, and clusters them in real time as you pan and zoom. This is the best place to start if you want to understand the basics:

- `ClusterManager` as a `@State` property
- `MapProxy.degrees(fromPixels:)` to compute epsilon
- `clusterManager.update(_:epsilon:)` on every camera change
- `clusterManager.clusters` driving `ForEach` annotations

No view model, no debouncing, no settings UI — just the core clustering workflow.

### Example

A full-featured app that builds on the same foundation with production-oriented extras:

- **Debounced updates** via an `UpdateCoordinator` actor that cancels and restarts a delayed task on each camera change
- **Visible-only filtering** to cluster only the points currently on screen
- **Multiple data sets** (938 / 1,813 / 33K US cities) switchable at runtime
- **Adjustable cluster spacing** via a slider
- **Draggable statistics overlay** showing cluster count, point count, and timing
- **Settings sheet** for toggling clustering, choosing data sources, and controlling the overlay
- **Loading indicator** during data loading and cluster computation

---

## Known Limitations

### Coordinate Distance Approximation

Clusterables uses Euclidean distance on raw latitude/longitude values when computing point proximity. This treats one degree of longitude as the same length as one degree of latitude, which is only true at the equator. At higher latitudes, a degree of longitude shrinks by `cos(latitude)` — for example, at 60°N it's half the actual ground distance.

For typical map clustering (city or regional scale, interactive zoom levels), this has no meaningful effect on cluster quality. At continental or global scales, east-west distances are overestimated at high latitudes, which can cause clusters to split along the longitude axis when they shouldn't.

### International Date Line

Points on opposite sides of the international date line (e.g., 179°E and 179°W) are geographically 2° apart but appear 358° apart in Euclidean space. The clusterer will not group these points together, even with a large epsilon.

This also affects the antimeridian more generally — any cluster that would span the ±180° longitude boundary will be split into two.

### Further Reading

Both limitations stem from treating latitude/longitude as a flat Cartesian plane. See [this KDTree discussion](https://github.com/Bersaelor/KDTree/issues/29) for approaches including latitude-adjusted distance formulas and projected coordinate systems.

---

## Acknowledgements

This package was adapted from [a Medium post by @stevenkish](https://medium.com/@stevenkish/coalescing-map-annotations-with-swiftui-5d7bdca567e8).
