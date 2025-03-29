/**
 # Clusterables
 
 A Swift package for clustering map annotations using the DBSCAN algorithm.
 
 ## Overview
 The Clusterables package provides an efficient solution for clustering map annotations 
 in SwiftUI applications using the DBSCAN algorithm.
 */

import SwiftUI
import MapKit
import DBSCAN
import simd

/**
 # Clusterable
 
 A protocol that defines an item that can be clustered on a map.
 
 ## Example
 ```swift
 struct MapPin: Clusterable {
     let coordinate: CLLocationCoordinate2D
     let title: String
 }
 ```
 */
public protocol Clusterable: Equatable  {
    /// The geographic coordinate of the clusterable item.
    var coordinate: CLLocationCoordinate2D { get }
}

/**
 # ClusterManagerProvider
 
 A protocol that defines a view that provides a cluster manager.
 
 ## Example
 ```swift
 struct MapView: View, ClusterManagerProvider {
     @StateObject private var clusterManager = ClusterManager<MapPin>()
     
     var body: some View {
         Map { 
             // Your map implementation
         }
     }
 }
 ```
 */
public protocol ClusterManagerProvider: View {
    /// The type of items that can be clustered.
    associatedtype ClusterableType: Clusterable
    
    /// The cluster manager instance responsible for managing clusters.
    var clusterManager: ClusterManager<ClusterableType> { get }
}

/**
 # Cluster
 
 A structure representing a cluster of items on a map.
 
 ## Overview
 A cluster contains one or more items of the same type and calculates
 its center point based on the average coordinates of its items.
 
 ## Example
 ```swift
 let cluster = Cluster(items: [pin1, pin2, pin3])
 print(cluster.size) // 3
 print(cluster.center) // The average coordinate of all pins
 ```
 */
public struct Cluster<CR: Clusterable> : Identifiable {
    /// Unique identifier for the cluster.
    public let id: UUID = UUID()
    
    /// The items contained within this cluster.
    public let items: [CR]
    
    /// The geographic center point of the cluster.
    public let center: CLLocationCoordinate2D
    
    /// The number of items in the cluster.
    public var size: Int { items.count }

    /**
     Creates a new cluster with the specified items.
     
     The cluster's center point is automatically calculated as the average
     of all item coordinates.
     
     - Parameter items: An array of clusterable items to include in the cluster.
     */
    public init(items: [CR]) {
        self.items = items

        let count = Double(items.count)
        self.center = items.lazy.reduce(CLLocationCoordinate2D(latitude: 0, longitude: 0)) { result, item in
            CLLocationCoordinate2D(
                latitude: result.latitude + item.coordinate.latitude / count,
                longitude: result.longitude + item.coordinate.longitude / count
            )
        }
    }
}

extension Cluster: Hashable {
    public static func == (lhs: Cluster, rhs: Cluster) -> Bool {
        lhs.center == rhs.center && lhs.size == rhs.size
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(center)
        hasher.combine(size)
    }
}

/**
 # ClusterManager
 
 A class that manages the clustering of items on a map.
 
 ## Overview
 The cluster manager uses the DBSCAN algorithm to group items into clusters
 based on their proximity to each other.
 
 ## Usage
 ```swift
 let manager = ClusterManager<MapPin>()
 await manager.update(pins, mapProxy: proxy, spacing: 50)
 ```
 */
@Observable
public class ClusterManager<CR: Clusterable> {
    /// The current set of clusters.
    public private(set) var clusters: [Cluster<CR>]

    /**
     Creates a new cluster manager with an empty set of clusters.
     */
    public init() { clusters = [] }

    /**
     Updates the clusters using the specified items and epsilon value.
     
     - Parameters:
         - items: The items to cluster.
         - epsilon: The maximum distance between two items for them to be considered as part of the same cluster.
     */
    public func update(_ items: [CR], epsilon: Double) async {
        self.clusters = await makeClusters(items, epsilon: epsilon)
    }

    /**
     Updates the clusters using the specified items and map view parameters.
     
     - Parameters:
         - items: The items to cluster.
         - mapProxy: The map proxy used to convert screen coordinates to geographic coordinates.
         - spacing: The desired spacing between clusters in screen points.
     */
    public func update(_ items: [CR], mapProxy: MapProxy, spacing: Int) async {
        guard let distance = mapProxy.degrees(fromPixels: spacing) else { return }
        self.clusters = await makeClusters(items, epsilon: distance)
    }

    /**
     Creates clusters from the specified items using the DBSCAN algorithm.
     
     - Parameters:
         - items: The items to cluster.
         - epsilon: The maximum distance between two items for them to be considered as part of the same cluster.
     - Returns: An array of clusters.
     */
    private func makeClusters(_ items: [CR], epsilon: Double) async -> [Cluster<CR>] {
        guard !items.isEmpty else { return [] }

        return await Task { () -> [Cluster] in
            // Convert locations to SIMD3 format
            let input = items.map { place in
                SIMD3<Double>(
                    x: place.coordinate.latitude,
                    y: place.coordinate.longitude,
                    z: 0.0
                )
            }

            // Run DBSCAN clustering
            let dbscan = DBSCAN(input)
            let (clusters, _) = dbscan(
                epsilon: epsilon,
                minimumNumberOfPoints: 1,
                distanceFunction: simd.distance
            )

            // Convert DBSCAN clusters to PlaceClusters
            return clusters.compactMap { cluster -> Cluster? in
                guard !cluster.isEmpty else { return nil }
                
                // Get original items for each cluster by matching coordinates
                let clusterItems = cluster.compactMap { point in
                    items.first { item in
                        item.coordinate.latitude == point.x &&
                        item.coordinate.longitude == point.y
                    }
                }
                
                guard !clusterItems.isEmpty else { return nil }
                return Cluster(items: clusterItems)
            }
        }.value
    }
}
