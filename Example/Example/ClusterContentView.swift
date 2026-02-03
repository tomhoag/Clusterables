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
    @State var items: [City] =  []
    @State var cameraPosition: MapCameraPosition = .automatic
    @State private var useKDTree = true
    @State private var lastUpdateDuration: TimeInterval?
    @State private var dbscanDuration: TimeInterval?
    @State private var cachedMapProxy: MapProxy?

    @State private var availableUSCityFiles: [String] = []
    @State private var selectedUSCityFile: String = ""
    @State private var isLoading: Bool = false

    private let spacing = 30

    var body: some View {
        VStack {
            ZStack {
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
                        // Cache the proxy so we can use it outside of MapReader's closure
                        cachedMapProxy = mapProxy

                        // Populate available files from the `USCities` subdirectory in the bundle
                        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "USCities") {
                            let names = urls.map { $0.deletingPathExtension().lastPathComponent }.sorted()
                            availableUSCityFiles = names
                            if selectedUSCityFile.isEmpty {
                                selectedUSCityFile = names.first ?? "USCities1813"
                            }
                        } else {
                            // Fallback default
                            availableUSCityFiles = ["USCities1813"]
                            if selectedUSCityFile.isEmpty {
                                selectedUSCityFile = "USCities1813"
                            }
                        }

                        Task { @MainActor in
                            items = Bundle.main.decode([City].self, "USCities/\(selectedUSCityFile)") ?? []
                            cameraPosition = .region(mapRegion)
                            (lastUpdateDuration, dbscanDuration) = await clusterManager.update(items, mapProxy: mapProxy, spacing: spacing, useKDTree: useKDTree)
                        }
                    }
                    .onMapCameraChange(frequency: .onEnd) { _ in
                        cachedMapProxy = mapProxy
                        Task { @MainActor in
                            (lastUpdateDuration, dbscanDuration) = await clusterManager.update(items, mapProxy: mapProxy, spacing: spacing, useKDTree: useKDTree)
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

                // Centered loading spinner shown above the map while loading
                if isLoading {
                    Color.black.opacity(0.25)
                        .cornerRadius(8)
                        .allowsHitTesting(false)

                    ProgressView(label: {
                        Text("Loading \(selectedUSCityFile)")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        }
                    )
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .zIndex(1)
                }
            }

            HStack {

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {

                    Picker("", selection: $selectedUSCityFile) {
                        ForEach(availableUSCityFiles, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.top, 8)
                    .onChange(of: selectedUSCityFile) { _, newFile in
                        guard !newFile.isEmpty else { return }

                        Task { @MainActor in
                            isLoading = true
                            items = []
                            if let proxy = cachedMapProxy {
                                _ = await clusterManager.update([], mapProxy: proxy, spacing: spacing, useKDTree: useKDTree)
                            }
                            
                            items = Bundle.main.decode([City].self, "USCities/\(newFile)") ?? []
                            cameraPosition = .region(mapRegion)
                            if let proxy = cachedMapProxy {
                                (lastUpdateDuration, dbscanDuration) = await clusterManager.update(items, mapProxy: proxy, spacing: spacing, useKDTree: useKDTree)
                            }
                            isLoading = false
                        }
                    }

                    HStack(spacing: 5) {
                        Text("Use KD-Tree")
                        Toggle("", isOn: $useKDTree)
                            .labelsHidden()
                    }
                    .padding(.top, 12)

                    Text(lastUpdateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 12)
            }
        }
        .padding()
    }

    private var lastUpdateText: String {
        if let d = lastUpdateDuration, let s = dbscanDuration {
            return "Last update: \(Int(d * 1000)) ms dbscan: \(Int(s * 1000))ms"
        } else {
            return "Last update: -- dbscan: -- "
        }
    }

    var mapRegion:MKCoordinateRegion {
        let coordinateArray = items.map { $0.coordinate }
        return coordinateArray.boundingRegion() ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5),
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        )
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
    func decode<T: Decodable>(_ type: T.Type, _ resource: String) -> T? {
        // Allow caller to pass either "MichiganCities.json", "USCities/Name.json" or just "MichiganCities"
        var resourcePath = resource
        var subdirectory: String? = nil

        // If resource contains a path (e.g. "USCities/Name.json"), split into subdirectory + filename
        if resourcePath.contains("/") {
            let comps = resourcePath.split(separator: "/").map(String.init)
            if comps.count >= 2 {
                subdirectory = comps.dropLast().joined(separator: "/")
                resourcePath = comps.last ?? resourcePath
            }
        }

        let resourceName: String
        let resourceExtension: String?
        if resourcePath.hasSuffix(".json") {
            resourceName = String(resourcePath.dropLast(5))
            resourceExtension = "json"
        } else {
            resourceName = resourcePath
            resourceExtension = "json"
        }

        let url: URL?
        if let sub = subdirectory {
            url = self.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: sub)
        } else {
            url = self.url(forResource: resourceName, withExtension: resourceExtension)
        }

        guard let fileURL = url else {
            print("Bundle.decode: resource not found: \(resource) (resolved name: \(resourceName) subdirectory: \(subdirectory ?? "nil"))")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
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
