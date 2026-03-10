//
//  DBSCANClusterer.swift
//  Clusterables
//
//  Created by Tom Hoag on 3/10/26.
//


/**
 A density-based, non-parametric clustering algorithm using KDTree acceleration.
 
 DBSCAN (Density-Based Spatial Clustering of Applications with Noise)
 groups points with many nearby neighbors and marks points in low-density
 regions as outliers.
 
 This implementation uses KDTree for efficient spatial queries.
 
 - Authors: Ester, Martin; Kriegel, Hans-Peter; Sander, Jörg; Xu, Xiaowei (1996)
            "A density-based algorithm for discovering clusters
            in large spatial databases with noise."
            _Proceedings of the Second International Conference on
            Knowledge Discovery and Data Mining (KDD-96)_.
 */

import KDTree

public struct DBSCANClusterer<Value: Equatable & Hashable & KDTreePoint> {
    private let values: [Value]
    private let kdTree: KDTree<Value>
    
    /// Creates a new DBSCAN clusterer with the specified values.
    /// - Parameter values: The values to be clustered.
    public init(values: [Value]) {
        self.values = values
        self.kdTree = KDTree(values: values)
    }
    
    /// Clusters values using the DBSCAN algorithm with KDTree acceleration.
    /// - Parameters:
    ///   - epsilon: The maximum distance from a specified value
    ///              for which other values are considered to be neighbors.
    ///   - minimumPoints: The minimum number of points
    ///                    required to form a dense region.
    /// - Returns: A tuple containing an array of clustered values
    ///            and an array of outlier values.
    public func cluster(epsilon: Double, minimumPoints: Int) -> (clusters: [[Value]], outliers: [Value]) {
        precondition(minimumPoints >= 0, "minimumPoints must be non-negative")
        
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
