//
//  ClusterContentView.swift
//  MichiganMapClustering
//
//  Created by Tom Hoag on 3/28/25.
//

import Clusterables
import MapKit
import SwiftUI
import CoreLocation

struct ClusterContentView: View, ClusterManagerProvider {

    @State var clusterManager = ClusterManager<City>()
    @State var items: [City] =  []
    @State var cameraPosition: MapCameraPosition = .automatic
    @State private var useKDTree = true
    @State private var lastUpdateDuration: TimeInterval?
    @State private var dbscanDuration: TimeInterval?

    @State private var availableUSCityFiles: [String] = []
    @State private var selectedUSCityFile: String = ""
    @State private var isLoading: Bool = false

    @State private var spacing: Double = 30

    @State private var cachedMapProxy: MapProxy?
    @State private var cachedItemsRegion: MKCoordinateRegion?
    @State private var clusterUpdateTask: Task<Void, Never>?

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
                            items = Bundle.main.decodeCached([City].self, "USCities/\(selectedUSCityFile)") ?? []
                            cameraPosition = .region(itemsMapRegion) // will force clusterManager.update
                        }
                    }
                    .onMapCameraChange { context in
                        cachedMapProxy = mapProxy
                        cachedItemsRegion = context.region
                        scheduleClusterUpdate()
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

                VStack (alignment: .leading, spacing: 4) {
                    Text("Total cities: \(items.count)")
                    Text("Visible cities: \(clusterManager.clusters.reduce(0) { $0 + $1.items.count })")
                    Text("Total clusters: \(clusterManager.clusters.filter {$0.items.count > 1 }.count)")
                }
                .padding(.leading)
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Picker("", selection: $selectedUSCityFile) {
                        ForEach(availableUSCityFiles, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.top, 8)
                    .onChange(of: selectedUSCityFile) { oldFile, newFile in
                        guard !newFile.isEmpty else { return }
                        guard oldFile != newFile else { return }

                        Task { @MainActor in
                            isLoading = true
                            items = [] // clear all markers from the map
                            if let proxy = cachedMapProxy {
                                _ = await clusterManager.update([], mapProxy: proxy, spacing: Int(spacing), useKDTree: useKDTree)
                            }

                            items = Bundle.main.decode([City].self, "USCities/\(newFile)") ?? []
                            cameraPosition = .region(itemsMapRegion) // will force a clusterManager.update
                            isLoading = false
                        }
                    }

                    HStack {
                        Text("Spacing \(Int(spacing))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $spacing, in: 10...100, step: 5)
                            .frame(width: 150)
                            .onChange(of: spacing) { oldValue, newValue in
                                guard oldValue != newValue else { return }
                                Task { @MainActor in
                                    isLoading = true
                                    scheduleClusterUpdate() // schedule a new update with the new spacing value
                                    isLoading = false
                                }
                            }
                    }
                    .padding(.top, 8)

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
                .padding(.trailing)
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

    var itemsMapRegion:MKCoordinateRegion {
        let coordinateArray = items.map { $0.coordinate }
        return coordinateArray.boundingRegion() ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5),
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        )
    }

    // Debounced / cancellable cluster update
    private func scheduleClusterUpdate(withVisibleOnly: Bool = true, delayMilliseconds: UInt64 = 150) {
        // cancel any in-flight task
        clusterUpdateTask?.cancel()
        clusterUpdateTask = Task { @MainActor in
            // simple debounce
            try? await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }

            guard let proxy = cachedMapProxy else {
                return
            }

            let sourceItems: [City] // ???
            if withVisibleOnly {
                sourceItems = visibleItems(in: cachedItemsRegion!, from: items)
            } else {
                sourceItems = items
            }

            // perform async update and capture results on main actor
            let results = await clusterManager.update(sourceItems, mapProxy: proxy, spacing: Int(spacing), useKDTree: useKDTree)
            lastUpdateDuration = results.0
            dbscanDuration = results.1
        }
    }

    private func visibleItems(in region: MKCoordinateRegion, from allItems: [City]) -> [City] {
        return allItems.filter { item in
            return region.contains(item.coordinate)
        }
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

private extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let center = self.center
        let span = self.span

        let minLatitude = center.latitude - span.latitudeDelta / 2
        let maxLatitude = center.latitude + span.latitudeDelta / 2
        let minLongitude = center.longitude - span.longitudeDelta / 2
        let maxLongitude = center.longitude + span.longitudeDelta / 2

        // Handle longitude wrapping around the international date line if necessary for a production app
        return coordinate.latitude >= minLatitude && coordinate.latitude <= maxLatitude &&
               coordinate.longitude >= minLongitude && coordinate.longitude <= maxLongitude
    }
}

// Add a small Bundle helper to decode JSON files from the bundle into Decodable types.
private extension Bundle {

    private static var _decodeCache = [String: Any]()

    func decodeCached<T: Decodable>(_ type: T.Type, _ resource: String) -> T? {
        if let cached = Bundle._decodeCache[resource] as? T {
            return cached
        }
        guard let decoded: T = decode(type, resource) else { return nil }
        Bundle._decodeCache[resource] = decoded
        return decoded
    }

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

extension Array where Element == CLLocationCoordinate2D {

    /// Returns an `MKCoordinateRegion` that encloses all coordinates, handling antimeridian crossing.
    /// - Parameters:
    ///   - padding: fractional padding to add to the computed span (0.1 = 10\%).
    ///   - minSpan: minimum latitude/longitude delta to avoid zero-sized spans.
    /// - Returns: `MKCoordinateRegion` or `nil` for empty array.
    func boundingRegion(padding: Double = 0.1, minSpan: CLLocationDegrees = 0.005) -> MKCoordinateRegion? {
        guard !isEmpty else { return nil }

        // lat min/max
        var minLat = 90.0, maxLat = -90.0
        for coord in self {
            minLat = Swift.min(minLat, coord.latitude)
            maxLat = Swift.max(maxLat, coord.latitude)
        }

        // Normalize longitudes to \(-180, 180] and compute two candidate spans:
        let normLon: (Double) -> Double = { lon in
            var x = lon.truncatingRemainder(dividingBy: 360.0)
            if x <= -180.0 { x += 360.0 }
            else if x > 180.0 { x -= 360.0 }
            return x
        }
        let lonNorm = self.map { normLon($0.longitude) }

        // Candidate 1: use normalized longitudes in [-180, 180]
        let minLon1 = lonNorm.min() ?? 0.0
        let maxLon1 = lonNorm.max() ?? 0.0
        let span1 = maxLon1 - minLon1

        // Candidate 2: shift negatives into [0, 360) to account for wrap-around
        let lonShifted = lonNorm.map { $0 < 0 ? $0 + 360.0 : $0 }
        let minLon2 = lonShifted.min() ?? 0.0
        let maxLon2 = lonShifted.max() ?? 0.0
        let span2 = maxLon2 - minLon2

        // Choose the smaller span (handles antimeridian)
        let useShifted = span2 < span1
        let (minLon, maxLon, rawLonSpan): (Double, Double, Double) = {
            if useShifted {
                return (minLon2, maxLon2, span2)
            } else {
                return (minLon1, maxLon1, span1)
            }
        }()

        // Center longitude: if using shifted coords, convert back to [-180, 180]
        var centerLon = (minLon + maxLon) / 2.0
        if useShifted {
            if centerLon > 180.0 { centerLon -= 360.0 }
        }

        let centerLat = (minLat + maxLat) / 2.0

        // Apply padding and enforce minimum spans
        let latSpanRaw = maxLat - minLat
        let lonSpanRaw = rawLonSpan

        let latSpan = Swift.max(latSpanRaw * (1.0 + padding), minSpan)
        let lonSpan = Swift.max(lonSpanRaw * (1.0 + padding), minSpan)

        // Clamp to valid ranges
        let finalLatSpan = Swift.min(latSpan, 180.0)
        let finalLonSpan = Swift.min(lonSpan, 360.0)

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: finalLatSpan, longitudeDelta: finalLonSpan)
        return MKCoordinateRegion(center: center, span: span)
    }
}



#Preview {
    ClusterContentView()
}

