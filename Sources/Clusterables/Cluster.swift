/**
 # Clusterables

 A Swift package for clustering map annotations using the DBSCAN algorithm.

 ## Overview
 The Clusterables package provides an efficient solution for clustering map annotations
 in SwiftUI applications using the DBSCAN algorithm.
 */

import DBSCAN
import KDTree
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
    // MARK: - Type Aliases
    
    /// A 2D point in coordinate space (latitude, longitude)
    private typealias Point = SIMD2<Double>
    
    /// A collection of points representing a raw cluster from DBSCAN
    private typealias PointCluster = [Point]
    
    /// A collection of array indices representing items in a cluster
    private typealias IndexCluster = [Int]
    
    /// Maps quantized coordinates to the original item indices
    private typealias CoordinateIndexMap = [PointKey: [Int]]
    
    // MARK: - Public Properties
    
    /// The current set of clusters.
    public private(set) var clusters: [Cluster<CR>]

    // MARK: - Initialization
    
    /// Creates a new cluster manager with an empty set of clusters.
    public init() {
        clusters = []
    }

    // MARK: - Public Methods
    
    /**
     Updates the clusters using the specified items and map view parameters.

     - Parameters:
        - items: The items to cluster.
        - mapProxy: The map proxy used to convert screen coordinates to geographic coordinates.
        - spacing: The desired spacing between clusters in screen points.
        - useKDTree: Whether to use KDTree for spatial indexing (default: true). KDTree provides O(n log n) complexity vs O(n²) without it.
     */
    @MainActor
    public func update(_ items: [CR], mapProxy: MapProxy, spacing: Int, useKDTree: Bool = true) async {
        guard let distance = mapProxy.degrees(fromPixels: spacing) else { return }
        let newClusters = await Self.makeClusters(items, epsilon: distance, useKDTree: useKDTree)
        clusters = newClusters
    }

    // MARK: - Private Types
    
    fileprivate struct PointKey: Hashable, Sendable {
        let latKey: Int64
        let lonKey: Int64
    }
    
    // MARK: - Private Properties
    
    /// The precision used for coordinate hashing (6 decimal places ≈ 0.1 meter accuracy)
    private static var coordinatePrecision: Double { 1_000_000.0 }

    // MARK: - Private Methods
    
    /**
     Converts clusterable items into SIMD points and builds a reverse lookup map.
     
     - Parameter items: The items to convert
     - Returns: A tuple containing the SIMD points array and coordinate-to-index mapping
     */
    private static func preprocessItems(_ items: [CR]) -> (points: [Point], coordIndexMap: CoordinateIndexMap) {
        var points: [Point] = []
        points.reserveCapacity(items.count)
        var coordIndexMap: CoordinateIndexMap = [:]
        coordIndexMap.reserveCapacity(items.count * 2)
        
        for (i, item) in items.enumerated() {
            let lat = item.coordinate.latitude
            let lon = item.coordinate.longitude
            points.append(Point(lat, lon))
            
            let latKey = Int64((lat * coordinatePrecision).rounded())
            let lonKey = Int64((lon * coordinatePrecision).rounded())
            let key = PointKey(latKey: latKey, lonKey: lonKey)
            coordIndexMap[key, default: []].append(i)
        }
        
        return (points, coordIndexMap)
    }
    
    /**
     Remaps SIMD2 points back to original item indices using the coordinate map.
     
     - Parameters:
        - rawClusters: Clusters of SIMD2 points from DBSCAN
        - coordIndexMap: Mapping from quantized coordinates to item indices
     - Returns: Array of index arrays, where each inner array represents a cluster
     */
    private static func remapPointsToIndices(
        _ rawClusters: [PointCluster],
        coordIndexMap: CoordinateIndexMap
    ) -> [IndexCluster] {
        var indexClusters: [IndexCluster] = []
        indexClusters.reserveCapacity(rawClusters.count)
        
        for raw in rawClusters {
            guard !raw.isEmpty else { continue }
            var clusterIndices: IndexCluster = []
            clusterIndices.reserveCapacity(raw.count)
            
            for pt in raw {
                // Note: SIMD2 stores (lat, lon) as (x, y)
                let latKey = Int64((pt.x * coordinatePrecision).rounded())
                let lonKey = Int64((pt.y * coordinatePrecision).rounded())
                let key = PointKey(latKey: latKey, lonKey: lonKey)
                
                if let indices = coordIndexMap[key] {
                    clusterIndices.append(contentsOf: indices)
                }
            }
            
            if !clusterIndices.isEmpty {
                indexClusters.append(clusterIndices)
            }
        }
        
        return indexClusters
    }
    
    /**
     Creates clusters from the specified items using the DBSCAN algorithm.

     - Parameters:
         - items: The items to cluster.
         - epsilon: The maximum distance between two items for them to be considered as part of the same cluster.
         - useKDTree: Whether to use KDTree for spatial indexing (default: true). 
           KDTree provides O(n log n) complexity vs O(n²) without it.
     - Returns: An array of clusters created from the items.
     
     - Complexity:
         - Time: O(n log n) with KDTree, O(n²) without KDTree, where n is the number of items
         - Space: O(n) for storing points, indices, and clusters
     */
    private static func makeClusters(_ items: [CR], epsilon: Double, useKDTree: Bool = true) async -> [Cluster<CR>] {

        guard !items.isEmpty else {
            return []
        }

        // Step 1: Preprocess items into SIMD points and build coordinate mapping
        let (points, coordIndexMap) = preprocessItems(items)

        // Step 2: Run DBSCAN clustering in a detached task
        let rawIndexClusters: [IndexCluster] = await Task.detached { [points, coordIndexMap, useKDTree, epsilon] () -> [IndexCluster] in

            let dbscan = DBSCAN(points)
            
            let rawClusters: [PointCluster]
            if useKDTree {
                (rawClusters, _) = dbscan(epsilon: epsilon, minimumNumberOfPoints: 1)
            } else {
                (rawClusters, _) = dbscan(
                    epsilon: epsilon,
                    minimumNumberOfPoints: 1,
                    distanceFunction: simd.distance
                )
            }
            
            // Step 3: Remap SIMD points back to original indices
            return remapPointsToIndices(rawClusters, coordIndexMap: coordIndexMap)
        }.value

        // Step 4: Convert index clusters to Cluster<CR> objects
        return rawIndexClusters.compactMap { indices -> Cluster<CR>? in
            guard !indices.isEmpty else { return nil }
            let clusterItems = indices.map { items[$0] }
            return Cluster(items: clusterItems)
        }
    }
}
