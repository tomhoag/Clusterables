//
//  DBSCANClustererTests.swift
//  Clusterables
//
//  Created by Tom Hoag on 3/11/26.
//

import Testing
import simd
@testable import Clusterables

/// Test suite for the DBSCAN clustering algorithm implementation.
@Suite("DBSCAN Clustering Tests")
struct DBSCANClustererTests {
    
    // MARK: - Basic Clustering Tests
    
    @Test("Empty dataset returns empty results")
    func emptyDataset() {
        let points: [SIMD2<Double>] = []
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters.isEmpty, "Empty dataset should produce no clusters")
        #expect(outliers.isEmpty, "Empty dataset should have no outliers")
    }
    
    @Test("Single point becomes outlier")
    func singlePoint() {
        let points = [SIMD2<Double>(1.0, 1.0)]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters.isEmpty, "Single point cannot form a cluster with minPoints=2")
        #expect(outliers.count == 1, "Single point should be an outlier")
        #expect(outliers[0] == points[0], "Outlier should be the single point")
    }
    
    @Test("Two nearby points form a cluster")
    func twoNearbyPoints() {
        let points = [
            SIMD2<Double>(1.0, 1.0),
            SIMD2<Double>(1.5, 1.5)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        // Distance between points is ~0.707, so epsilon=1.0 should capture them
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters.count == 1, "Two nearby points should form one cluster")
        #expect(clusters[0].count == 2, "Cluster should contain both points")
        #expect(outliers.isEmpty, "No points should be outliers")
    }
    
    @Test("Two distant points are both outliers")
    func twoDistantPoints() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(100.0, 100.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters.isEmpty, "Distant points should not cluster")
        #expect(outliers.count == 2, "Both points should be outliers")
    }
    
    // MARK: - Multiple Cluster Tests
    
    @Test("Identifies two separate clusters")
    func twoSeparateClusters() {
        let points = [
            // Cluster 1: around (0, 0)
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.5, 0.5),
            SIMD2<Double>(1.0, 0.0),
            
            // Cluster 2: around (10, 10)
            SIMD2<Double>(10.0, 10.0),
            SIMD2<Double>(10.5, 10.5),
            SIMD2<Double>(11.0, 10.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters.count == 2, "Should find two distinct clusters")
        #expect(outliers.isEmpty, "All points should be clustered")
        
        // Each cluster should have 3 points
        let clusterSizes = clusters.map { $0.count }.sorted()
        #expect(clusterSizes == [3, 3], "Both clusters should have 3 points")
    }
    
    @Test("Three clusters with different densities")
    func threeClustersVariableDensity() {
        let points = [
            // Dense cluster 1
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.1, 0.1),
            SIMD2<Double>(0.2, 0.2),
            SIMD2<Double>(0.3, 0.3),
            
            // Medium cluster 2
            SIMD2<Double>(5.0, 5.0),
            SIMD2<Double>(5.5, 5.5),
            SIMD2<Double>(6.0, 6.0),
            
            // Sparse cluster 3
            SIMD2<Double>(20.0, 20.0),
            SIMD2<Double>(21.0, 21.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.5, minimumPoints: 2)
        
        #expect(clusters.count == 3, "Should find three clusters")
        #expect(outliers.isEmpty, "All points should be clustered with these parameters")
    }
    
    // MARK: - Outlier Detection Tests
    
    @Test("Detects outliers between clusters")
    func outliersDetection() {
        let points = [
            // Cluster 1
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.5, 0.5),
            SIMD2<Double>(1.0, 0.0),
            
            // Outlier
            SIMD2<Double>(5.0, 5.0),
            
            // Cluster 2
            SIMD2<Double>(10.0, 10.0),
            SIMD2<Double>(10.5, 10.5),
            SIMD2<Double>(11.0, 10.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters.count == 2, "Should find two clusters")
        #expect(outliers.count == 1, "Should have one outlier")
        #expect(outliers[0] == SIMD2<Double>(5.0, 5.0), "Outlier should be the isolated point")
    }
    
    @Test("All points become outliers with small epsilon")
    func allOutliersSmallEpsilon() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(1.0, 1.0),
            SIMD2<Double>(2.0, 2.0),
            SIMD2<Double>(3.0, 3.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        // With very small epsilon, no points are neighbors
        let (clusters, outliers) = clusterer.cluster(epsilon: 0.001, minimumPoints: 2)
        
        #expect(clusters.isEmpty, "No clusters should form with tiny epsilon")
        #expect(outliers.count == 4, "All points should be outliers")
    }
    
    // MARK: - Parameter Sensitivity Tests
    
    @Test("Larger epsilon merges clusters")
    func epsilonMergesClusters() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.5, 0.5),
            SIMD2<Double>(5.0, 5.0),
            SIMD2<Double>(5.5, 5.5)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        // Small epsilon: two clusters
        let (smallClusters, _) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        #expect(smallClusters.count == 2, "Small epsilon should create two clusters")
        
        // Large epsilon: one cluster
        let (largeClusters, _) = clusterer.cluster(epsilon: 10.0, minimumPoints: 2)
        #expect(largeClusters.count == 1, "Large epsilon should merge into one cluster")
        #expect(largeClusters[0].count == 4, "Single cluster should contain all points")
    }
    
    @Test("Higher minimumPoints creates stricter clusters")
    func minimumPointsStrictness() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.5, 0.5),
            SIMD2<Double>(1.0, 0.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        // Low minPoints: forms cluster
        let (lowMinClusters, lowMinOutliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        #expect(lowMinClusters.count == 1, "Should form cluster with minPoints=2")
        #expect(lowMinOutliers.isEmpty, "No outliers with minPoints=2")
        
        // High minPoints: all become outliers
        let (highMinClusters, highMinOutliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 4)
        #expect(highMinClusters.isEmpty, "Cannot form cluster with minPoints=4 and only 3 points")
        #expect(highMinOutliers.count == 3, "All points should be outliers")
    }
    
    @Test("minimumPoints of 1 clusters all connected points")
    func minimumPointsOne() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.5, 0.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 1)
        
        #expect(clusters.count == 1, "Even single points form clusters with minPoints=1")
        #expect(clusters[0].count == 2, "Both points should cluster together")
        #expect(outliers.isEmpty, "No outliers with minPoints=1")
    }
    
    // MARK: - Shape Detection Tests
    
    @Test("Detects linear cluster")
    func linearCluster() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(1.0, 0.0),
            SIMD2<Double>(2.0, 0.0),
            SIMD2<Double>(3.0, 0.0),
            SIMD2<Double>(4.0, 0.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.5, minimumPoints: 2)
        
        #expect(clusters.count == 1, "Linear points should form one cluster")
        #expect(clusters[0].count == 5, "All points should be in the cluster")
        #expect(outliers.isEmpty, "No outliers")
    }
    
    @Test("Detects circular cluster")
    func circularCluster() {
        // Create points in a circle
        var points: [SIMD2<Double>] = []
        let radius = 5.0
        let numPoints = 8
        
        for i in 0..<numPoints {
            let angle = 2.0 * .pi * Double(i) / Double(numPoints)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            points.append(SIMD2(x, y))
        }
        
        let clusterer = DBSCANClusterer(values: points)
        
        // Distance between adjacent points on circle ≈ 2 * radius * sin(π/numPoints) ≈ 3.83
        let (clusters, outliers) = clusterer.cluster(epsilon: 4.0, minimumPoints: 2)
        
        #expect(clusters.count == 1, "Circular points should form one cluster")
        #expect(clusters[0].count == 8, "All points should be clustered")
        #expect(outliers.isEmpty, "No outliers in circle")
    }
    
    // MARK: - Edge Case Tests
    
//    @Test("Identical points cluster together")
//    func identicalPoints() {
//        let points = [
//            SIMD2<Double>(5.0, 5.0),
//            SIMD2<Double>(5.0, 5.0),
//            SIMD2<Double>(5.0, 5.0)
//        ]
//        let clusterer = DBSCANClusterer(values: points)
//        
//        let (clusters, outliers) = clusterer.cluster(epsilon: 0.1, minimumPoints: 2)
//        
//        #expect(clusters.count == 1, "Identical points should cluster")
//        #expect(clusters[0].count == 3, "All identical points in one cluster")
//        #expect(outliers.isEmpty, "No outliers")
//    }
    
    @Test("Very large epsilon creates single cluster")
    func veryLargeEpsilon() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(100.0, 100.0),
            SIMD2<Double>(200.0, 200.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1000.0, minimumPoints: 2)
        
        #expect(clusters.count == 1, "Very large epsilon should capture all points")
        #expect(clusters[0].count == 3, "All points in single cluster")
        #expect(outliers.isEmpty, "No outliers")
    }
    
    // MARK: - Determinism Tests
    
    @Test("Algorithm is deterministic")
    func determinism() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(0.5, 0.5),
            SIMD2<Double>(1.0, 0.0),
            SIMD2<Double>(10.0, 10.0),
            SIMD2<Double>(10.5, 10.5),
            SIMD2<Double>(11.0, 10.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters1, outliers1) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        let (clusters2, outliers2) = clusterer.cluster(epsilon: 1.0, minimumPoints: 2)
        
        #expect(clusters1.count == clusters2.count, "Cluster count should be deterministic")
        #expect(outliers1.count == outliers2.count, "Outlier count should be deterministic")
        
        // Verify same points in clusters (order may vary)
        let allClustered1 = Set(clusters1.flatMap { $0 })
        let allClustered2 = Set(clusters2.flatMap { $0 })
        #expect(allClustered1 == allClustered2, "Same points should be clustered")
    }
    
    // MARK: - Real-World Scenario Tests
    
    @Test("Geographic coordinates clustering (San Francisco)")
    func geographicClustering() {
        // Real SF locations (lat, lon)
        let points = [
            // Downtown cluster
            SIMD2<Double>(37.7749, -122.4194),
            SIMD2<Double>(37.7750, -122.4195),
            SIMD2<Double>(37.7751, -122.4196),
            
            // Airport cluster (SFO)
            SIMD2<Double>(37.6213, -122.3790),
            SIMD2<Double>(37.6214, -122.3791),
            
            // Outlier (Berkeley)
            SIMD2<Double>(37.8715, -122.2730)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        // 0.01 degrees ≈ 1.1 km at this latitude
        let (clusters, outliers) = clusterer.cluster(epsilon: 0.01, minimumPoints: 2)
        
        #expect(clusters.count == 2, "Should find downtown and airport clusters")
        #expect(outliers.count == 1, "Berkeley point should be an outlier")
        
        // Verify cluster sizes
        let sortedSizes = clusters.map { $0.count }.sorted()
        #expect(sortedSizes == [2, 3], "Clusters should have 2 and 3 points")
    }
    
    @Test("High-density urban area clustering")
    func highDensityClustering() {
        // Simulate many points in small area
        var points: [SIMD2<Double>] = []
        for x in 0..<5 {
            for y in 0..<5 {
                points.append(SIMD2(Double(x) * 0.1, Double(y) * 0.1))
            }
        }
        
        let clusterer = DBSCANClusterer(values: points)
        let (clusters, outliers) = clusterer.cluster(epsilon: 0.15, minimumPoints: 3)
        
        #expect(!clusters.isEmpty, "High density area should form clusters")
        #expect(outliers.count <= 4, "Corner points might be outliers, but most should cluster")
        
        let totalClustered = clusters.flatMap { $0 }.count
        #expect(totalClustered >= 20, "Most of the 25 points should be clustered")
    }
    
    // MARK: - Precondition Tests
    
//    @Test("Negative epsilon triggers precondition", .bug("https://github.com/example/issue/123"))
//    func negativeEpsilon() {
//        let points = [SIMD2<Double>(0.0, 0.0)]
//        let clusterer = DBSCANClusterer(values: points)
//        
//        #expect(
//            performing: {
//                _ = clusterer.cluster(epsilon: -1.0, minimumPoints: 2)
//            },
//            throws: { error in
//                // In Swift Testing, preconditions cause test crashes
//                // This test documents expected behavior
//                true
//            }
//        )
//    }
    
    @Test("Very small epsilon is valid but produces all outliers")
    func verySmallEpsilon() {
        let points = [
            SIMD2<Double>(0.0, 0.0),
            SIMD2<Double>(1.0, 1.0)
        ]
        let clusterer = DBSCANClusterer(values: points)
        
        // Zero epsilon means points must be exactly at same location
        let (clusters, outliers) = clusterer.cluster(epsilon: 0.000001, minimumPoints: 2)
        
        #expect(clusters.isEmpty, "Zero epsilon should produce no clusters")
        #expect(outliers.count == 2, "All non-identical points become outliers")
    }
    
    @Test("minimumPoints of 0 is valid")
    func zeroMinimumPoints() {
        let points = [SIMD2<Double>(0.0, 0.0)]
        let clusterer = DBSCANClusterer(values: points)
        
        let (clusters, outliers) = clusterer.cluster(epsilon: 1.0, minimumPoints: 0)
        
        // With minPoints=0, even single points can be core points
        #expect(clusters.count == 1, "Single point forms cluster with minPoints=0")
        #expect(outliers.isEmpty, "No outliers")
    }
    
    // MARK: - Performance Characteristics Tests
    
    @Test("Handles moderate dataset efficiently")
    func moderateDatasetPerformance() {
        // Create 1000 random-ish points
        var points: [SIMD2<Double>] = []
        for i in 0..<1000 {
            let x = Double(i % 100) + Double(i % 7) * 0.1
            let y = Double(i / 100) + Double(i % 11) * 0.1
            points.append(SIMD2(x, y))
        }
        
        let clusterer = DBSCANClusterer(values: points)
        
        // This should complete quickly with KD-tree (O(n log n))
        let (clusters, _) = clusterer.cluster(epsilon: 2.0, minimumPoints: 3)
        
        #expect(!clusters.isEmpty, "Should find some clusters")
        #expect(clusters.count < 1000, "Should cluster points, not create 1000 clusters")
        
        // Verify all points are accounted for
        let totalPoints = clusters.flatMap { $0 }.count
        #expect(totalPoints <= 1000, "Cannot have more clustered points than input")
    }
}
