/**
 # Clusterables

 A Swift package for clustering map annotations using the DBSCAN algorithm.

 ## Overview
 The Clusterables package provides an efficient solution for clustering map annotations
 in SwiftUI applications using the DBSCAN algorithm.
 */

import DBSCAN
import MapKit
import SwiftUI
import simd

/**
 # Clusterable

 A protocol that defines an item that can be clustered on a map.

 ## Example
 ```swift
 struct city: Clusterable {
     let coordinate: CLLocationCoordinate2D
     let title: String
 }
 ```
 */
public protocol Clusterable: Equatable, Sendable {
    /// The geographic coordinate of the clusterable item.
    var coordinate: CLLocationCoordinate2D { get }
}

/**
 # ClusterManagerProvider
 A protocol that defines a view that provides a cluster manager.
 ## Example
 ```swift
 struct MapView: View, ClusterManagerProvider {
     @State private var clusterManager = ClusterManager<MapPin>()

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
public struct Cluster<CR: Clusterable>: Identifiable, Sendable {
    /// Unique identifier for the cluster.
    public var id: UUID = .init()

    /// The items contained within this cluster.
    public let items: [CR]

    /// The geographic center point of the cluster.
    public let center: CLLocationCoordinate2D

    /// The number of items in the cluster.
    public var size: Int { items.count }

    /**
     Creates a new cluster with the specified items

     The cluster's center point is automatically calculated as the average
     of all item coordinates.

     - Parameter items: An array of clusterable items to include in the cluster.
     */
    public init(items: [CR]) {
        self.items = items

        let count = Double(items.count)
        center = items.lazy
            .reduce(CLLocationCoordinate2D(latitude: 0, longitude: 0)) { result, item in
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

    /// Creates a new cluster manager with an empty set of clusters.
    public init() { clusters = [] }

    /**
     Updates the clusters using the specified items and map view parameters.

     - Parameters:
     - items: The items to cluster.
     - mapProxy: The map proxy used to convert screen coordinates to geographic coordinates.
     - spacing: The desired spacing between clusters in screen points.
     */
    @MainActor
    public func update(_ items: [CR], mapProxy: MapProxy, spacing: Int) async {
        guard let distance = mapProxy.degrees(fromPixels: spacing) else { return }
        clusters = await makeClusters(items, epsilon: distance)
    }

    fileprivate struct PointKey: Hashable {
        let latKey: Int64
        let lonKey: Int64
    }
    /**
     Creates clusters from the specified items using the DBSCAN algorithm.

     - Parameters:
         - items: The items to cluster.
         - epsilon: The maximum distance between two items for them to be considered as part of the same cluster.
     - Returns: An array of clusters.
     */
    @MainActor
    private func makeClusters(_ items: [CR], epsilon: Double) async -> [Cluster<CR>] {

        let overallStart = DispatchTime.now()

        guard !items.isEmpty else {
            let overallElapsed = Double(DispatchTime.now().uptimeNanoseconds - overallStart.uptimeNanoseconds) / 1e9
            print("empty input, skipping clustering, took \(overallElapsed)s")
            return []
        }

        let precision: Double = 1_000_000.0
        var points: [SIMD2<Double>] = []
        points.reserveCapacity(items.count)
        var coordIndexMap: [PointKey: [Int]] = [:]
        coordIndexMap.reserveCapacity(items.count * 2)

        for (i, item) in items.enumerated() {
            let lat = item.coordinate.latitude
            let lon = item.coordinate.longitude
            points.append(SIMD2<Double>(lat, lon))

            let latKey = Int64((lat * precision).rounded())
            let lonKey = Int64((lon * precision).rounded())
            let key = PointKey(latKey: latKey, lonKey: lonKey)
            coordIndexMap[key, default: []].append(i)
        }

        // Pass only `points` and the precomputed `coordIndexMap` into the detached task.
        // Avoid any fallback searches; rely on the stable point key mapping.
        let (rawIndexClusters, dbscanElapsed): ([[Int]], TimeInterval) = await Task.detached { () -> ([[Int]], TimeInterval) in

            let start = DispatchTime.now()
            let dbscan = DBSCAN(points)
            let (rawClusters, _) = dbscan(
                epsilon: epsilon,
                minimumNumberOfPoints: 1,
                distanceFunction: simd.distance
            )

            var indexClusters: [[Int]] = []
            indexClusters.reserveCapacity(rawClusters.count)

            for raw in rawClusters {
                guard !raw.isEmpty else { continue }
                var clusterIndices: [Int] = []
                clusterIndices.reserveCapacity(raw.count)

                for pt in raw {
                    let lonKey = Int64((pt.y * precision).rounded())
                    let latKey = Int64((pt.x * precision).rounded())
                    let key = PointKey(latKey: latKey, lonKey: lonKey)
                    if let indices = coordIndexMap[key] {
                        clusterIndices.append(contentsOf: indices)
                    } // NO fallback firstIndex call
                }

                if !clusterIndices.isEmpty {
                    indexClusters.append(clusterIndices)
                }
            }
            let end = DispatchTime.now()
            let dbscanElapsed = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1e9
            return (indexClusters, dbscanElapsed)
        }.value

        // convert index clusters to Cluster<CR>
        let clusters = rawIndexClusters.compactMap { indices -> Cluster<CR>? in
            guard !indices.isEmpty else { return nil }
            let clusterItems = indices.map { items[$0] }
            return Cluster(items: clusterItems)
        }

        let overallEnd = DispatchTime.now()
        let overallElapsed = Double(overallEnd.uptimeNanoseconds - overallStart.uptimeNanoseconds) / 1e9

        print("makeClustersOptimized \(items.count) took \(overallElapsed)s (dbscan: \(dbscanElapsed)s)")
        return clusters
    }
}
