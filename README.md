# Clusterables

A SwiftUI-native package for clustering MapKit map points — no UIViewRepresentable required. Keeps your maps fast, clean, and easy to navigate no matter how many points you're displaying. Because clustering is density-based, groups form naturally around real geographic concentrations — not arbitrary grid boundaries.

Powered by **DBSCAN** (Density-Based Spatial Clustering of Applications with Noise) paired with a **KD-Tree** for fast spatial lookups. This combination means clustering is both accurate and efficient — DBSCAN naturally handles clusters of varying shapes and sizes, while the KD-Tree keeps nearest-neighbor searches fast even with thousands of points.

![Demo](example.gif)
---

## Requirements

- iOS 26.0+
- Swift 6.0+
- Xcode 26.0+

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

### Step 2 — Add `ClusterManagerProvider` to your view

Make your `ContentView` (or whichever view contains your map) conform to `ClusterManagerProvider`, and add a `ClusterManager` state variable. Make sure to specify the type of `Clusterable` it will manage:

```swift
struct ContentView: View, ClusterManagerProvider {

    @State var clusterManager = ClusterManager<City>()

    // ...
}
```

### Step 3 — Wrap your `Map` in a `MapReader`

`MapReader` gives you a `mapProxy`, which is required by `ClusterManager` to calculate screen-space distances for clustering:

```swift
MapReader { mapProxy in
    Map(position: $cameraPosition, interactionModes: .all) {
        // ...
    }
}
```

### Step 4 — Render clusters and individual annotations

Iterate over `clusterManager.clusters` to build your map annotations. In the code below, when a cluster contains a single item (`size == 1`), it is rendered using a red circle. When it contains multiple items, it is rendered using a `ClusterAnnotationView` ( found in the Example project)

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
}
```

### Step 5 — Trigger cluster updates

Call `clusterManager.update` whenever the map appears, the camera position changes or whenever you want to update the clusters. Note that `spacing` is used to determine how "tightly" map items should be clustered.  A small spacing value will yeild fewer clusters.

```swift
.onAppear {
    Task { @MainActor in
        cameraPosition = .region(mapRegion)
        await clusterManager.update(items, mapProxy: mapProxy, spacing: spacing)
    }
}
.onMapCameraChange(frequency: .onEnd) { _ in
    Task { @MainActor in
        await clusterManager.update(items, mapProxy: mapProxy, spacing: spacing)
    }
}
```

---

## Demo

Clone this repo and open `Example/Example.xcodeproject` to see a working implementation.

---

## Acknowledgements

This package was adapted from [a Medium post by @stevenkish](https://medium.com/@stevenkish/coalescing-map-annotations-with-swiftui-5d7bdca567e8).
