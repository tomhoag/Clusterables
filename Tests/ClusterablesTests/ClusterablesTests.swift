//
//  ClusterablesTests.swift
//  Clusterables
//
//  Created by Tom Hoag on 3/11/26.
//

import Testing
import MapKit
import SwiftUI
import simd
@testable import Clusterables

// MARK: - Test Models

/// A simple test implementation of Clusterable
struct TestPin: Clusterable, Hashable {
    let coordinate: CLLocationCoordinate2D
    let name: String
    
    static func == (lhs: TestPin, rhs: TestPin) -> Bool {
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

/// Another test model to verify generic type handling
struct TestLocation: Clusterable {
    let coordinate: CLLocationCoordinate2D
    let id: UUID
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self.id = UUID()
    }
    
    static func == (lhs: TestLocation, rhs: TestLocation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Cluster Tests

@Suite("Cluster Tests")
struct ClusterTests {
    
    @Test("Cluster initializes with items")
    func initialization() {
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), name: "Pin 1"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195), name: "Pin 2")
        ]
        
        let cluster = Cluster(items: pins)
        
        #expect(cluster.items.count == 2, "Cluster should contain 2 items")
        #expect(cluster.size == 2, "Size should equal items count")
        #expect(cluster.items == pins, "Items should match input")
    }
    
    @Test("Cluster calculates center correctly")
    func centerCalculation() {
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "Origin"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 10.0, longitude: 10.0), name: "Corner")
        ]
        
        let cluster = Cluster(items: pins)
        
        // Center should be average: (5.0, 5.0)
        #expect(cluster.center.latitude == 5.0, "Center latitude should be 5.0")
        #expect(cluster.center.longitude == 5.0, "Center longitude should be 5.0")
    }
    
    @Test("Cluster center calculation with three points")
    func centerCalculationThreePoints() {
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 3.0, longitude: 0.0), name: "B"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 3.0), name: "C")
        ]
        
        let cluster = Cluster(items: pins)
        
        // Center should be (1.0, 1.0)
        #expect(cluster.center.latitude == 1.0, "Center latitude should be 1.0")
        #expect(cluster.center.longitude == 1.0, "Center longitude should be 1.0")
    }
    
    @Test("Cluster with single item has correct center")
    func singleItemCenter() {
        let pin = TestPin(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), name: "Solo")
        let cluster = Cluster(items: [pin])
        
        #expect(cluster.size == 1, "Single-item cluster should have size 1")
        #expect(cluster.center.latitude == 37.7749, "Center should match item latitude")
        #expect(cluster.center.longitude == -122.4194, "Center should match item longitude")
    }
    
    @Test("Cluster has unique ID")
    func uniqueID() {
        let pins = [TestPin(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), name: "Pin")]
        
        let cluster1 = Cluster(items: pins)
        let cluster2 = Cluster(items: pins)
        
        #expect(cluster1.id != cluster2.id, "Each cluster should have unique ID")
    }
    
    @Test("Cluster equality is identity-based")
    func equality() {
        let pins1 = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 1.0), name: "B")
        ]
        
        let pins2 = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "C"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 1.0), name: "D")
        ]
        
        let cluster1 = Cluster(items: pins1)
        let cluster2 = Cluster(items: pins2)
        
        // Different instances are never equal, even with same center and size
        #expect(cluster1 != cluster2, "Distinct clusters should not be equal")
        #expect(cluster1 == cluster1, "A cluster should equal itself")
    }
    
    @Test("Cluster hashability")
    func hashability() {
        let pins = [TestPin(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), name: "Pin")]
        let cluster = Cluster(items: pins)
        
        var set = Set<Cluster<TestPin>>()
        set.insert(cluster)
        
        #expect(set.count == 1, "Cluster should be hashable and insertable into Set")
        #expect(set.contains(cluster), "Set should contain the inserted cluster")
    }
    
    @Test("Cluster is Sendable")
    func sendability() async {
        let pins = [TestPin(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), name: "Pin")]
        let cluster = Cluster(items: pins)
        
        // This compiles and runs, proving Sendable conformance
        await Task {
            let size = cluster.size
            #expect(size == 1)
        }.value
    }
}

// MARK: - ClusterManager Tests

@Suite("ClusterManager Tests")
struct ClusterManagerTests {
    
    @Test("ClusterManager initializes with empty clusters")
    func initialization() {
        let manager = ClusterManager<TestPin>()
        
        #expect(manager.clusters.isEmpty, "New manager should have no clusters")
    }
    
    @Test("ClusterManager update clusters items by epsilon")
    func updateClusters() async {
        let manager = ClusterManager<TestPin>()
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001), name: "B"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 10.0, longitude: 10.0), name: "C")
        ]
        
        await manager.update(pins, epsilon: 0.01)
        
        #expect(manager.clusters.count == 2, "Should find two clusters")
    }
    
    @Test("ClusterManager update with empty items produces empty results")
    func updateEmpty() async {
        let manager = ClusterManager<TestPin>()
        
        await manager.update([], epsilon: 1.0)
        
        #expect(manager.clusters.isEmpty, "Empty items should produce no clusters")
        #expect(manager.outliers.isEmpty, "Empty items should produce no outliers")
    }
    
    @Test("Default minimumPoints produces no outliers")
    func defaultMinimumPointsNoOutliers() async {
        let manager = ClusterManager<TestPin>()
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: 50.0), name: "B")
        ]
        
        await manager.update(pins, epsilon: 1.0)
        
        #expect(manager.clusters.count == 2, "Each point should form its own cluster")
        #expect(manager.outliers.isEmpty, "No outliers with minimumPoints=1")
    }
    
    @Test("Higher minimumPoints produces outliers")
    func minimumPointsProducesOutliers() async {
        let manager = ClusterManager<TestPin>()
        let pins = [
            // Dense group
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001), name: "B"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.002, longitude: 0.002), name: "C"),
            // Isolated point
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: 50.0), name: "D")
        ]
        
        await manager.update(pins, epsilon: 0.01, minimumPoints: 3)
        
        #expect(manager.clusters.count == 1, "Dense group should form one cluster")
        #expect(manager.clusters[0].size == 3, "Cluster should contain the three nearby points")
        #expect(manager.outliers.count == 1, "Isolated point should be an outlier")
        #expect(manager.outliers[0].coordinate.latitude == 50.0, "Outlier should be the distant point")
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("Cluster center calculation matches manual calculation")
    func clusterCenterAccuracy() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7850, longitude: -122.4294),
            CLLocationCoordinate2D(latitude: 37.7950, longitude: -122.4394)
        ]
        
        let pins = coords.map { TestPin(coordinate: $0, name: "Pin") }
        let cluster = Cluster(items: pins)
        
        // Manual calculation
        let avgLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let avgLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        
        let epsilon = 0.000001 // Floating-point comparison tolerance
        #expect(abs(cluster.center.latitude - avgLat) < epsilon, "Latitude should match manual calculation")
        #expect(abs(cluster.center.longitude - avgLon) < epsilon, "Longitude should match manual calculation")
    }
    
}

// These tests verify that the internal generation counter used to discard stale
// update results does not interfere with normal ClusterManager behavior. The actual
// staleness-discard path (where a newer update causes an in-flight update to bail out)
// cannot be reliably exercised in a unit test because DBSCAN completes too quickly on
// small datasets to create a timing window. The generation counter logic is verified
// structurally by code review.

@Suite("Generation Counter Regression Tests")
@MainActor
struct GenerationCounterTests {
    
    /// Verifies that a single update still produces correct results after adding
    /// the generation counter to the update path. Guards against the counter
    /// machinery accidentally short-circuiting a valid, non-stale update.
    @Test("Single update produces correct results with generation counter in place")
    func singleUpdate() async {
        let manager = ClusterManager<TestPin>()
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001), name: "B"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 10.0, longitude: 10.0), name: "C")
        ]
        
        await manager.update(pins, epsilon: 0.01)
        
        #expect(manager.clusters.count == 2, "Should produce two clusters")
        #expect(manager.outliers.isEmpty, "No outliers with default minimumPoints")
    }
    
    /// Verifies that two sequential (non-overlapping) updates each produce
    /// correct results. The generation counter increments on each call; this
    /// confirms that a higher generation value doesn't prevent a subsequent
    /// update from completing and applying its results.
    @Test("Sequential updates each apply their results correctly")
    func sequentialUpdates() async {
        let manager = ClusterManager<TestPin>()
        
        // First update: two clusters
        let pins1 = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "A"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 10.0, longitude: 10.0), name: "B")
        ]
        await manager.update(pins1, epsilon: 0.01)
        #expect(manager.clusters.count == 2, "First update should produce two clusters")
        
        // Second update: three clusters — confirms generation counter advances correctly
        let pins2 = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), name: "X"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 10.0, longitude: 10.0), name: "Y"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 20.0, longitude: 20.0), name: "Z")
        ]
        await manager.update(pins2, epsilon: 0.01)
        #expect(manager.clusters.count == 3, "Second update should produce three clusters")
    }
}

// MARK: - Edge Cases

@Suite("Edge Case Tests")
struct EdgeCaseTests {
    
    @Test("Cluster with negative coordinates")
    func negativeCoordinates() {
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093), name: "Sydney"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: -33.8689, longitude: 151.2094), name: "Near Sydney")
        ]
        
        let cluster = Cluster(items: pins)
        
        #expect(cluster.center.latitude < 0, "Should handle negative latitudes")
        #expect(cluster.center.longitude > 0, "Should handle positive longitudes")
        #expect(cluster.size == 2, "Should cluster negative coordinate items")
    }
    
    @Test("Cluster at zero coordinates")
    func zeroCoordinates() {
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), name: "Null Island"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 0.0001, longitude: 0.0001), name: "Near Null Island")
        ]
        
        let cluster = Cluster(items: pins)
        
        #expect(cluster.center.latitude >= 0, "Should handle zero coordinates")
        #expect(cluster.center.longitude >= 0, "Should handle zero coordinates")
    }
    
    @Test("Cluster at extreme coordinates")
    func extremeCoordinates() {
        let pins = [
            TestPin(coordinate: CLLocationCoordinate2D(latitude: 89.9, longitude: 179.9), name: "Near North Pole"),
            TestPin(coordinate: CLLocationCoordinate2D(latitude: -89.9, longitude: -179.9), name: "Near South Pole")
        ]
        
        let cluster = Cluster(items: pins)
        
        // Center should be close to (0, 0) - averaging extremes
        #expect(abs(cluster.center.latitude) < 1.0, "Extreme latitudes should average sensibly")
    }
    
    @Test("Cluster with identical coordinates")
    func identicalCoordinates() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pins = [
            TestPin(coordinate: coord, name: "Pin 1"),
            TestPin(coordinate: coord, name: "Pin 2"),
            TestPin(coordinate: coord, name: "Pin 3")
        ]
        
        let cluster = Cluster(items: pins)
        
        #expect(cluster.center.latitude == coord.latitude, "Center should match identical coordinates")
        #expect(cluster.center.longitude == coord.longitude, "Center should match identical coordinates")
        #expect(cluster.size == 3, "Should cluster all identical coordinate items")
    }
}



