//
//  ClusterContentView.swift
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

    @State private var useClustering = true
    @State private var useKDTree = true
    @State private var onlyVisible = true

    @State private var lastUpdateDuration: TimeInterval?
    @State private var dbscanDuration: TimeInterval?

    @State private var availableUSCityFiles: [String] = []
    @State private var selectedUSCityFile: String = ""
    @State private var isLoading: Bool = false

    @State private var spacing: Double = 30

    @State private var cachedMapProxy: MapProxy?
    @State private var cachedItemsRegion: MKCoordinateRegion?
    @State private var clusterUpdateTask: Task<Void, Never>?

    @State private var cachedCoordinates: [CLLocationCoordinate2D] = []

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
                        scheduleClusterUpdate(withVisibleOnly: onlyVisible)
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
                    Text("Visible on Map: \(clusterManager.clusters.reduce(0) { $0 + $1.items.count })")
                    Text("  as Cities: \(clusterManager.clusters.filter {$0.items.count == 1 }.count)")
                    Text("  as Clusters: \(clusterManager.clusters.filter {$0.items.count > 1 }.count)")
                }
                .padding(.leading)
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("Render Only Visible Cities")
                        Toggle("", isOn: $onlyVisible)
                            .labelsHidden()
                    }
                    .padding(.top, 12)

                    HStack(spacing: 5) {
                        Text("Use Clustering")
                        Toggle("", isOn: $useClustering)
                            .labelsHidden()
                    }
                    .padding(.top, 12)

                    if(useClustering) {
                        HStack(spacing: 5) {
                            Text("Use KD-Tree")
                            Toggle("", isOn: $useKDTree)
                                .labelsHidden()
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.trailing)

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
                                    scheduleClusterUpdate(withVisibleOnly: onlyVisible) // schedule a new update with the new spacing value
                                    isLoading = false
                                }
                            }
                    }
                    .padding(.top, 8)

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

    private func scheduleClusterUpdate(withVisibleOnly: Bool = true, delayMilliseconds: UInt64 = 150) {
        // cancel any in-flight task
        clusterUpdateTask?.cancel()

        // snapshot lightweight state so background work doesn't repeatedly read @State
        let spacingSnapshot = Int(self.spacing)
        let useKDTreeSnapshot = self.useKDTree
        let itemsSnapshot = self.items
        let coordsSnapshot = self.cachedCoordinates
        let regionSnapshot = self.cachedItemsRegion
        let withVisibleOnlySnapshot = withVisibleOnly
        let delay = delayMilliseconds

        // use a detached task to perform debounce and clustering off the main actor
        clusterUpdateTask = Task.detached { [spacingSnapshot, useKDTreeSnapshot, itemsSnapshot, coordsSnapshot, regionSnapshot, withVisibleOnlySnapshot, delay] in
            // simple debounce
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            guard !Task.isCancelled else { return }

            // determine region to use (safe fallback to computed region)
            let regionToUse: MKCoordinateRegion
            if let cachedRegion = regionSnapshot {
                regionToUse = cachedRegion
            } else {
                // compute from cached coordinates if available, otherwise compute from items
                let regionFromCoords: MKCoordinateRegion
                if coordsSnapshot.isEmpty {
                    // Need itemsMapRegion; compute here from itemsSnapshot to avoid capturing self
                    let coordinateArray = itemsSnapshot.map { $0.coordinate }
                    regionFromCoords = await coordinateArray.boundingRegion() ?? MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5),
                        span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
                    )
                } else {
                    // local helper to compute region from coordinates
                    func coordsToRegion(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
                        guard !coords.isEmpty else {
                            return MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5),
                                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
                            )
                        }
                        let latitudes = coords.map { $0.latitude }
                        let longitudes = coords.map { $0.longitude }
                        let minLat = latitudes.min() ?? 44.0
                        let maxLat = latitudes.max() ?? 44.0
                        let minLon = longitudes.min() ?? -85.5
                        let maxLon = longitudes.max() ?? -85.5
                        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLon + maxLon) / 2.0)
                        let span = MKCoordinateSpan(latitudeDelta: max(0.01, (maxLat - minLat)), longitudeDelta: max(0.01, (maxLon - minLon)))
                        return MKCoordinateRegion(center: center, span: span)
                    }
                    regionFromCoords = coordsToRegion(coordsSnapshot)
                }
                regionToUse = regionFromCoords
            }

            // compute source items (visible-only or all)
            let sourceItems: [City]
            if withVisibleOnlySnapshot {
                // local visibleItems implementation to avoid capturing self
                func normalize(_ lon: Double) -> Double {
                    var l = lon
                    while l < -180.0 { l += 360.0 }
                    while l > 180.0 { l -= 360.0 }
                    return l
                }
                let centerLon = normalize(regionToUse.center.longitude)
                let lonDelta = regionToUse.span.longitudeDelta
                let minLon = normalize(centerLon - lonDelta / 2.0)
                let maxLon = normalize(centerLon + lonDelta / 2.0)
                let minLat = regionToUse.center.latitude - regionToUse.span.latitudeDelta / 2.0
                let maxLat = regionToUse.center.latitude + regionToUse.span.latitudeDelta / 2.0
                let crossesAntimeridian = minLon > maxLon
                sourceItems = itemsSnapshot.filter { item in
                    let lat = item.coordinate.latitude
                    guard lat >= minLat && lat <= maxLat else { return false }
                    let lon = normalize(item.coordinate.longitude)
                    if crossesAntimeridian {
                        return lon >= minLon || lon <= maxLon
                    } else {
                        return lon >= minLon && lon <= maxLon
                    }
                }
            } else {
                sourceItems = itemsSnapshot
            }

            await MainActor.run {
                guard let proxy = self.cachedMapProxy else { return }
                // Directly call if it must be main-actor isolated:
                Task { @MainActor in
                    let results = await self.clusterManager.update(
                        sourceItems,
                        mapProxy: proxy,
                        spacing: spacingSnapshot,
                        useKDTree: useKDTreeSnapshot
                    )
                    self.lastUpdateDuration = results.0
                    self.dbscanDuration = results.1
                }
            }

        } as? Task<Void, Never>
    }

    // Small helper to build a region from a coordinates array
    private func coordsToRegion(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else { return itemsMapRegion }
        let latitudes = coords.map { $0.latitude }
        let longitudes = coords.map { $0.longitude }
        let minLat = latitudes.min() ?? 44.0
        let maxLat = latitudes.max() ?? 44.0
        let minLon = longitudes.min() ?? -85.5
        let maxLon = longitudes.max() ?? -85.5

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLon + maxLon) / 2.0)
        let span = MKCoordinateSpan(latitudeDelta: max(0.01, (maxLat - minLat)), longitudeDelta: max(0.01, (maxLon - minLon)))
        return MKCoordinateRegion(center: center, span: span)
    }

    // Optimized visibleItems helper (avoids repeated normalization per item)
    private func visibleItems(in region: MKCoordinateRegion, from allItems: [City]) -> [City] {
        // normalize helper
        func normalize(_ lon: Double) -> Double {
            var l = lon
            while l < -180.0 { l += 360.0 }
            while l > 180.0 { l -= 360.0 }
            return l
        }

        let centerLon = normalize(region.center.longitude)
        let lonDelta = region.span.longitudeDelta
        let minLon = normalize(centerLon - lonDelta / 2.0)
        let maxLon = normalize(centerLon + lonDelta / 2.0)
        let minLat = region.center.latitude - region.span.latitudeDelta / 2.0
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2.0

        let crossesAntimeridian = minLon > maxLon

        return allItems.filter { item in
            let lat = item.coordinate.latitude
            guard lat >= minLat && lat <= maxLat else { return false }

            let lon = normalize(item.coordinate.longitude)
            if crossesAntimeridian {
                return lon >= minLon || lon <= maxLon
            } else {
                return lon >= minLon && lon <= maxLon
            }
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

#Preview {
    ClusterContentView()
}
