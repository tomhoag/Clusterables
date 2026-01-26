//
//  ContentView.swift
//  MichiganMapClustering
//
//  Created by Tom Hoag on 3/28/25.
//

import Clusterables
import MapKit
import SwiftUI

struct ClusterContentView: View, ClusterManagerProvider {

    @State var clusterManager = ClusterManager<City>()

    @State var items: [City] = Bundle.main.decode("MichiganCities.json") ?? []
    @State var cameraPosition: MapCameraPosition = .automatic

    private let spacing = 30

    var body: some View {
        VStack {
            MapReader { mapProxy in
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
                .padding()
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
                .animation(.easeIn, value: cameraPosition)
                .mapStyle(
                    .hybrid(
                        elevation: .automatic,
                        pointsOfInterest: .excludingAll,
                        showsTraffic: false
                    )
                )
                .mapControls {
                    MapScaleView()
                    MapCompass()
                }
            }
        }
        .padding()
    }

    var mapRegion:MKCoordinateRegion {
        let center = items.centerCoordinateBoundingBox ?? CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5)
        let span = MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Helper Views
private struct ClusterAnnotationView: View {
    let size: Int

    var body: some View {
        Image(systemName: size <= 50 ? "\(size).circle.fill" : "plus.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .blue)
            .font(.largeTitle)
    }
}

// Add a small Bundle helper to decode JSON files from the bundle into Decodable types.
private extension Bundle {
    func decode<T: Decodable>(_ resource: String) -> T? {
        // Allow caller to pass either "MichiganCities.json" or just "MichiganCities"
        let resourceName: String
        let resourceExtension: String?
        if resource.hasSuffix(".json") {
            resourceName = String(resource.dropLast(5))
            resourceExtension = "json"
        } else {
            resourceName = resource
            resourceExtension = "json"
        }

        guard let url = self.url(forResource: resourceName, withExtension: resourceExtension) else {
            print("Bundle.decode: resource not found: \(resource)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Bundle.decode(\(resource)) failed: \(error)")
            return nil
        }
    }
}

#Preview {
    ClusterContentView()
}
