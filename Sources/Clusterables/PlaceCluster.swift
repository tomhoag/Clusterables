import SwiftUI
import MapKit
import DBSCAN
import simd

public protocol ClusterRepresentable: Equatable  {
    var coordinate: CLLocationCoordinate2D { get }
}

public protocol ClusterProvider: View {
    associatedtype ClusterRepresentableType: ClusterRepresentable
    var clusterManager: ClusterManager<ClusterRepresentableType> { get }
    var items: [ClusterRepresentableType] { get }
}

public struct PlaceCluster<CR: ClusterRepresentable> : Identifiable {
    public let id: UUID = UUID()
    public let items: [CR]
    public let center: CLLocationCoordinate2D
    public var size: Int { items.count }

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

extension PlaceCluster: Hashable {
    public static func == (lhs: PlaceCluster, rhs: PlaceCluster) -> Bool {
        lhs.center == rhs.center && lhs.size == rhs.size
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(center)
        hasher.combine(size)
    }
}

@Observable
public class ClusterManager<CR: ClusterRepresentable> {
    public private(set) var clusters: [PlaceCluster<CR>]

    public init() { clusters = [] }

    public func update(_ items: [CR], epsilon: Double) async {
        self.clusters = await makeClusters(items, epsilon: epsilon)
    }

    public func update(_ items: [CR], mapProxy: MapProxy, spacing: Int) async {
        guard let distance = mapProxy.degrees(fromPixels: spacing) else { return }
        self.clusters = await makeClusters(items, epsilon: distance)
    }

    private func makeClusters(_ items: [CR], epsilon: Double) async -> [PlaceCluster<CR>] {
        guard !items.isEmpty else { return [] }

        return await Task { () -> [PlaceCluster] in
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
            return clusters.compactMap { cluster -> PlaceCluster? in
                guard !cluster.isEmpty else { return nil }
                
                // Get original items for each cluster by matching coordinates
                let clusterItems = cluster.compactMap { point in
                    items.first { item in
                        item.coordinate.latitude == point.x &&
                        item.coordinate.longitude == point.y
                    }
                }
                
                guard !clusterItems.isEmpty else { return nil }
                return PlaceCluster(items: clusterItems)
            }
        }.value
    }
}