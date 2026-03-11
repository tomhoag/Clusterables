//
//  DBSCANClusterer.swift
//  Clusterables
//
//  Created by Tom Hoag on 3/10/26.
//

import KDTree

/// Errors thrown by ``DBSCANClusterer/cluster(epsilon:minimumPoints:)``.
public enum ClusterError: Error, Equatable {
    /// The `epsilon` value is not positive and finite.
    case invalidEpsilon(Double)
    /// The `minimumPoints` value is negative.
    case invalidMinimumPoints(Int)
}

/// A density-based clustering algorithm using KD-tree acceleration for efficient spatial queries.
///
/// DBSCAN (Density-Based Spatial Clustering of Applications with Noise) is a non-parametric
/// clustering algorithm that groups points with many nearby neighbors while marking points
/// in low-density regions as outliers.
///
/// Unlike k-means clustering, DBSCAN:
/// - Does not require specifying the number of clusters in advance
/// - Can find arbitrarily-shaped clusters
/// - Explicitly identifies noise points (outliers)
/// - Is deterministic (produces the same results given the same parameters)
///
/// This implementation uses a KD-tree for efficient spatial indexing, achieving O(n log n)
/// average-case performance instead of the naive O(n²) implementation.
///
/// ## Algorithm Overview
///
/// DBSCAN works by examining the neighborhood density around each point:
///
/// 1. **Core points**: Points with at least `minimumPoints` neighbors within `epsilon` distance
/// 2. **Border points**: Points within `epsilon` of a core point but with fewer neighbors
/// 3. **Noise points**: All other points (returned as outliers)
///
/// Clusters are formed by connecting core points that are within `epsilon` distance of each other,
/// along with their border points.
///
/// ## Example
///
/// ```swift
/// import simd
///
/// // Create sample 2D points
/// let points: [SIMD2<Double>] = [
///     SIMD2(1.0, 1.0),
///     SIMD2(1.5, 1.5),
///     SIMD2(2.0, 2.0),  // Dense cluster
///     SIMD2(10.0, 10.0),
///     SIMD2(10.5, 10.5), // Another cluster
///     SIMD2(50.0, 50.0)  // Outlier
/// ]
///
/// let clusterer = DBSCANClusterer(values: points)
/// let (clusters, outliers) = try clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
///
/// print("Found \(clusters.count) clusters")
/// print("Found \(outliers.count) outliers")
/// ```
///
/// ## Choosing Parameters
///
/// ### Epsilon (ε)
/// - **Definition**: Maximum distance between two points to be considered neighbors
/// - **Effect**: Smaller values create tighter, more numerous clusters; larger values merge clusters
/// - **Guidance**: Start with average nearest-neighbor distance in your dataset
///
/// ### Minimum Points
/// - **Definition**: Minimum number of neighbors (including the point itself) to form a core point
/// - **Effect**: Higher values require denser regions to form clusters
/// - **Guidance**: For 2D data, typical values are 3-5; for higher dimensions, use 2×dimensions
///
/// ## Performance Characteristics
///
/// - **Time Complexity**: O(n log n) average case with KD-tree, O(n²) worst case for very dense data
/// - **Space Complexity**: O(n) for the KD-tree structure
/// - **Best For**: Datasets with varying cluster densities and arbitrary shapes
/// - **Not Ideal For**: High-dimensional data (>10 dimensions) due to curse of dimensionality
///
/// ## References
///
/// Ester, Martin; Kriegel, Hans-Peter; Sander, Jörg; Xu, Xiaowei (1996).
/// "A density-based algorithm for discovering clusters in large spatial databases with noise."
/// _Proceedings of the Second International Conference on Knowledge Discovery and Data Mining (KDD-96)_.
/// AAAI Press. pp. 226–231.
///
/// ## Topics
///
/// ### Creating a Clusterer
/// - ``init(values:)``
///
/// ### Performing Clustering
/// - ``cluster(epsilon:minimumPoints:)``
public struct DBSCANClusterer<Value: Equatable & Hashable & KDTreePoint> {
    /// The values to be clustered.
    private let values: [Value]
    
    /// KD-tree spatial index for efficient neighbor queries.
    private let kdTree: KDTree<Value>
    
    /// Creates a new DBSCAN clusterer with the specified values.
    ///
    /// The initializer builds a KD-tree spatial index for efficient neighbor searching
    /// during the clustering process. This preprocessing step takes O(n log n) time
    /// but significantly speeds up subsequent clustering operations.
    ///
    /// - Parameter values: The points to be clustered. Must conform to `KDTreePoint`
    ///   for spatial indexing. Can be empty (clustering will return empty results).
    ///
    /// - Complexity: O(n log n) where n is the number of values, for building the KD-tree.
    ///
    /// ## Example
    /// ```swift
    /// let points = [
    ///     SIMD2(1.0, 2.0),
    ///     SIMD2(1.5, 2.5),
    ///     SIMD2(5.0, 5.0)
    /// ]
    /// let clusterer = DBSCANClusterer(values: points)
    /// ```
    public init(values: [Value]) {
        self.values = values
        self.kdTree = KDTree(values: values)
    }
    
    /// Clusters values using the DBSCAN algorithm with KD-tree acceleration.
    ///
    /// This method identifies dense regions in the dataset by finding points that have
    /// at least `minimumPoints` neighbors within `epsilon` distance. Points that don't
    /// meet this density criterion are classified as outliers (noise).
    ///
    /// The algorithm works in three phases:
    /// 1. **Core Point Identification**: Find all points with ≥ `minimumPoints` neighbors
    /// 2. **Cluster Expansion**: Connect core points that are within `epsilon` of each other
    /// 3. **Border Assignment**: Assign non-core points to clusters if they're within `epsilon` of a core point
    ///
    /// - Parameters:
    ///   - epsilon: The maximum distance from a specified value for which other values
    ///     are considered neighbors. Must be positive and finite.
    ///     - **Smaller values**: More, tighter clusters
    ///     - **Larger values**: Fewer, looser clusters
    ///     - **Typical range**: 0.1 to 10.0 depending on your coordinate system
    ///   - minimumPoints: The minimum number of points required to form a dense region
    ///     (including the point itself). Must be non-negative.
    ///     - **Lower values**: More clusters, more sensitive to noise
    ///     - **Higher values**: Fewer, denser clusters, more outliers
    ///     - **Typical values**: 3-5 for 2D data, `2 × dimensions` for higher dimensions
    ///
    /// - Returns: A tuple containing:
    ///   - `clusters`: An array of value arrays, where each inner array represents
    ///     a discovered cluster. Clusters are returned in discovery order. Empty if no
    ///     dense regions meet the criteria.
    ///   - `outliers`: Points that don't belong to any cluster, representing noise or
    ///     sparse regions. These points have fewer than `minimumPoints` neighbors within
    ///     `epsilon` distance. Empty if all points are clustered.
    ///
    /// - Complexity: O(n log n) average case with KD-tree acceleration, where n is the
    ///   number of values. Worst case is O(n²) for very dense datasets where most points
    ///   are neighbors of each other.
    ///
    /// - Throws: ``ClusterError/invalidEpsilon(_:)`` if `epsilon` is not positive and finite (not NaN, not infinite).
    /// - Throws: ``ClusterError/invalidMinimumPoints(_:)`` if `minimumPoints` is negative.
    ///
    /// ## Example: Geographic Clustering
    /// ```swift
    /// let locations: [SIMD2<Double>] = [
    ///     // Downtown cluster
    ///     SIMD2(37.7749, -122.4194),
    ///     SIMD2(37.7750, -122.4195),
    ///     SIMD2(37.7751, -122.4196),
    ///
    ///     // Airport cluster  
    ///     SIMD2(37.6213, -122.3790),
    ///     SIMD2(37.6214, -122.3791),
    ///
    ///     // Outlier
    ///     SIMD2(38.0000, -121.0000)
    /// ]
    ///
    /// let clusterer = DBSCANClusterer(values: locations)
    /// let (clusters, outliers) = try clusterer.cluster(epsilon: 0.01, minimumPoints: 2)
    ///
    /// print("Downtown cluster size: \(clusters[0].count)")  // 3
    /// print("Airport cluster size: \(clusters[1].count)")   // 2
    /// print("Outliers: \(outliers.count)")                  // 1
    /// ```
    ///
    /// ## Example: Handling Edge Cases
    /// ```swift
    /// let clusterer = DBSCANClusterer(values: points)
    ///
    /// // Empty dataset
    /// let (c1, o1) = try clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
    /// // c1 = [], o1 = []
    ///
    /// // All points are outliers (epsilon too small)
    /// let (c2, o2) = try clusterer.cluster(epsilon: 0.0001, minimumPoints: 5)
    /// // c2 = [], o2 = all points
    ///
    /// // All points in one cluster (epsilon too large)
    /// let (c3, o3) = try clusterer.cluster(epsilon: 1000.0, minimumPoints: 1)
    /// // c3 = [all points], o3 = []
    /// ```
    ///
    /// - Note: The algorithm is deterministic - running it multiple times with the same
    ///   parameters will always produce the same clusters (though cluster ordering may vary).
    ///
    /// - Important: For geographic coordinates (latitude/longitude), remember that epsilon
    ///   is measured in degrees. At the equator, 1 degree ≈ 111 km, but this varies by latitude.
    ///
    /// - Important: Points must be unique.
    public func cluster(epsilon: Double, minimumPoints: Int) throws(ClusterError) -> (clusters: [[Value]], outliers: [Value]) {
        guard epsilon > 0 && epsilon.isFinite else { throw .invalidEpsilon(epsilon) }
        guard minimumPoints >= 0 else { throw .invalidMinimumPoints(minimumPoints) }
        
        guard !values.isEmpty else { return ([], []) }
        
        var labels = [Int?](repeating: nil, count: values.count)
        let valueToIndex = Dictionary(uniqueKeysWithValues: values.enumerated().map { ($1, $0) })
        var currentLabel = 0
        
        for i in values.indices {
            guard labels[i] == nil else { continue }
            
            let neighbors = kdTree.allPoints(within: epsilon, of: values[i])
                .compactMap { valueToIndex[$0] }
            
            guard neighbors.count >= minimumPoints else { continue }
            
            labels[i] = currentLabel
            expandCluster(from: neighbors, label: currentLabel,
                         labels: &labels, valueToIndex: valueToIndex,
                         epsilon: epsilon, minimumPoints: minimumPoints)
            currentLabel += 1
        }
        
        return buildResults(from: labels)
    }
    
    /// Expands a cluster by recursively adding reachable density-connected points.
    ///
    /// This method performs a breadth-first expansion from an initial set of neighbors,
    /// discovering all points that are density-reachable from the starting core point.
    ///
    /// A point is density-reachable if there exists a chain of core points connecting
    /// it to the starting point, where each consecutive pair is within `epsilon` distance.
    ///
    /// - Parameters:
    ///   - initialNeighbors: Indices of the initial neighbors to expand from.
    ///   - label: The cluster label to assign to discovered points.
    ///   - labels: In-out parameter tracking cluster assignments for all points.
    ///   - valueToIndex: Mapping from values to their array indices for fast lookup.
    ///   - epsilon: The neighborhood distance threshold.
    ///   - minimumPoints: The minimum neighbors required for a point to be a core point.
    ///
    /// - Complexity: O(k log n) where k is the cluster size and n is the total number of points.
    private func expandCluster(from initialNeighbors: [Int], label: Int,
                               labels: inout [Int?], valueToIndex: [Value: Int],
                               epsilon: Double, minimumPoints: Int) {
        var queue = initialNeighbors
        var head = 0
        
        while head < queue.count {
            let neighborIndex = queue[head]
            head += 1
            
            guard labels[neighborIndex] == nil else { continue }
            labels[neighborIndex] = label
            
            let newNeighbors = kdTree.allPoints(within: epsilon, of: values[neighborIndex])
                .compactMap { valueToIndex[$0] }
            
            if newNeighbors.count >= minimumPoints {
                queue.append(contentsOf: newNeighbors)
            }
        }
    }
    
    /// Converts cluster labels into the final result format.
    ///
    /// Takes the array of cluster labels (with `nil` for outliers) and organizes
    /// values into separate cluster arrays and an outliers array.
    ///
    /// - Parameter labels: Array of cluster labels for each point (nil = outlier).
    /// - Returns: A tuple of clustered values and outlier values.
    ///
    /// - Complexity: O(n + c) where n is the number of points and c is the number of clusters.
    private func buildResults(from labels: [Int?]) -> (clusters: [[Value]], outliers: [Value]) {
        var clustersDict = [Int: [Value]]()
        var outliers = [Value]()
        
        for (index, value) in values.enumerated() {
            if let label = labels[index] {
                clustersDict[label, default: []].append(value)
            } else {
                outliers.append(value)
            }
        }
        
        let clusters = clustersDict.keys.sorted().map { clustersDict[$0]! }
        return (clusters, outliers)
    }
}
