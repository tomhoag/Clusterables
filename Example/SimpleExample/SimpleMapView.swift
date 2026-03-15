//
//  SimpleMapView.swift
//  SimpleExample
//
//  Created by Tom Hoag on 3/15/26.
//

import Clusterables
import MapKit
import SwiftUI

/// A minimal example demonstrating ClusterManager with MapKit.
///
/// Loads 1,813 US cities from bundled JSON, displays them on a map,
/// and clusters them using DBSCAN as the user pans and zooms.
struct SimpleMapView: View {
    @State private var clusterManager = ClusterManager<City>()
    @State private var cities: [City] = []
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6),
            span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 60)
        )
    )

    /// Pixel spacing used to compute the clustering epsilon.
    /// Larger values merge more cities into each cluster.
    private let clusterSpacing = 30

    var body: some View {
        MapReader { mapProxy in
            Map(position: $cameraPosition) {
                ForEach(clusterManager.clusters) { cluster in
                    if cluster.size == 1, let city = cluster.items.first {
                        Annotation(city.name, coordinate: city.coordinate) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8)
                        }
                    } else {
                        Annotation("", coordinate: cluster.center) {
                            Image(
                                systemName: cluster.size <= 50
                                    ? "\(cluster.size).circle.fill"
                                    : "plus.circle.fill"
                            )
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .blue)
                            .font(.title)
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .onAppear {
                loadCities()
            }
            .onMapCameraChange { _ in
                Task {
                    await updateClusters(mapProxy: mapProxy)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadCities() {
        guard let url = Bundle.main.url(
            forResource: "USCities1813",
            withExtension: "json"
        ) else { return }

        do {
            let data = try Data(contentsOf: url)
            cities = try JSONDecoder().decode([City].self, from: data)
        } catch {
            print("Failed to load cities: \(error)")
        }
    }

    // MARK: - Clustering

    private func updateClusters(mapProxy: MapProxy) async {
        guard let epsilon = mapProxy.degrees(fromPixels: clusterSpacing) else {
            return
        }
        await clusterManager.update(cities, epsilon: epsilon)
    }
}

#Preview {
    SimpleMapView()
}
