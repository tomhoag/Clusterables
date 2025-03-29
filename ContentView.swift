//
//  ContentView.swift
//  MichiganMapClustering
//
//  Created by Tom Hoag on 3/28/25.
//

import SwiftUI
import MapKit
import MichiganCities
import Clusterables

extension MichiganCity: @retroactive Clusterable {}

struct ContentView: View, ClusterManagerProvider {    

    @State var clusterManager = ClusterManager<MichiganCity>()

    @State var items:[MichiganCity] = MichiganCities.random(count: 1000) ?? []
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

    var mapRegion: MKCoordinateRegion {
        // Center point between both peninsulas
        let center = CLLocationCoordinate2D(
            latitude: 43.802819,
            longitude: -86.112938
        )

        // Span to show both peninsulas with some padding
        let span = MKCoordinateSpan(
            latitudeDelta: 6.0,
            longitudeDelta: 8.0
        )

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

#Preview {
    ContentView()
}
