# Clusterables

Add cluster map annotations to your SwiftUI Map

## The Setup

1. The `CLLocationCoordinate2Ds`	that are to be mapped must be wrapped in a struct that conforms to `Clusterable`

	```
	extension City: Clusterable {
		var coordinate: CLLocationCoordinate2D
	}
	```

2. Make your ContentView (or the view that contains your Map) conform to `ClusterManagerProvider`

	```swift
	struct ContentView: View, ClusterManagerProvider {    
	
	    @State var clusterManager = ClusterManager<City>()
	    
	    <Other ContentView stuff>
    ```
    
	When you add the `ClusterManager` var, be certain to specify the type of `Clusterables` that it will be managing.

3. Wrap your `Map` in a `MapReader`

	```swift
	MapReader { mapProxy in
        Map(position: $cameraPosition, interactionModes: .all) {
   ```

4. To add the clusters, examine `clusterManager.clusters`. If the item count is one, add a non-cluster annotation to the map. If the count is greater than one, add a cluster annotation to the map.

	```
    Map(position: $cameraPosition, interactionModes: .all) {
        ForEach(clusterManager.clusters) { cluster in
            if cluster.size == 1, let city = cluster.items.first {
                Annotation(city.name, coordinate: city.coordinate) {
                    Circle()
                        .foregroundColor(.red)
                        .frame(width: 7)
                }
            } else {
                Annotation("", coordinate: cluster.center) {
                    ClusterAnnotationView(size: cluster.size)
                }
            }
       }
   }
	```

5. Add a call to `clusterManager.update` when the cluster annotations should update.  This usually happens in a Map modifier (.onAppear, .onChange, etc):

	```
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
	
	## Reference Implementation
	Please see `ContentView.swift` in this package for a more complete reference implementation.
	
	## Acknowledgements
	This package was adapted from [https://medium.com/@stevenkish/coalescing-map-annotations-with-swiftui-5d7bdca567e8](https://medium.com/@stevenkish/coalescing-map-annotations-with-swiftui-5d7bdca567e8)