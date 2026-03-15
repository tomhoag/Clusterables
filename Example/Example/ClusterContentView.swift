//
//  ClusterContentView.swift
//  Example
//
//  Created by Tom Hoag on 3/28/25.
//

import Clusterables
import MapKit
import SwiftUI

/// A SwiftUI view that displays an interactive map with optional clustering of city markers.
///
/// This view provides:
/// - Interactive map with city annotations
/// - Optional DBSCAN-based clustering with adjustable spacing
/// - Multiple city data file sources
/// - Visibility filtering for better performance
struct ClusterContentView: View {

    @State private var viewModel = ClusterMapViewModel()
    @State private var updateCoordinator = UpdateCoordinator()
    
    var clusterManager: ClusterManager<City> { viewModel.clusterManager }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MapReader { mapProxy in
                    Map(position: $viewModel.cameraPosition, interactionModes: .all) {
                        mapAnnotations
                    }
                    .padding()
                    .onAppear {
                        setupInitialState(mapProxy: mapProxy)
                    }
                    .onMapCameraChange { context in
                        viewModel.cachedMapProxy = mapProxy
                        viewModel.cachedItemsRegion = context.region
                        scheduleUpdate(withVisibleOnly: viewModel.clusteringSettings.onlyVisible)
                    }
                    .animation(.easeIn, value: viewModel.cameraPosition)
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
                
                LoadingOverlayView(
                    isLoading: viewModel.dataSource.isLoading,
                    selectedFile: viewModel.dataSource.selectedFile
                )
            }
            Divider()
            ControlsPanelView(
                viewModel: viewModel,
                onClusteringToggle: {
                    scheduleUpdate(withVisibleOnly: viewModel.clusteringSettings.onlyVisible)
                },
                onSpacingChange: {
                    Task { @MainActor in
                        viewModel.dataSource.isLoading = true
                        defer { viewModel.dataSource.isLoading = false }
                        scheduleUpdate(withVisibleOnly: viewModel.clusteringSettings.onlyVisible)
                    }
                },
                onVisibleOnlyToggle: {
                    scheduleUpdate(withVisibleOnly: viewModel.clusteringSettings.onlyVisible)
                },
                onFileChange: { oldFile, newFile in
                    handleFileChange(oldFile: oldFile, newFile: newFile)
                }
            )
            .padding()
        }
    }
    
    // MARK: - Map Annotations
    
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        if viewModel.clusteringSettings.enabled {
            ForEach(viewModel.clusterManager.clusters) { cluster in
                if cluster.size == 1, let city = cluster.items.first {
                    Annotation(city.name, coordinate: city.coordinate) {
                        CityAnnotationView()
                    }
                } else {
                    Annotation("", coordinate: cluster.center) {
                        ClusterAnnotationView(size: cluster.size)
                    }
                }
            }
            // Outliers are empty when using the default minimumPoints of 1.
            // Increase minimumPoints to see isolated points rendered here.
            ForEach(viewModel.clusterManager.outliers, id: \.self) { city in
                Annotation(city.name, coordinate: city.coordinate) {
                    OutlierAnnotationView()
                }
            }
        } else {
            ForEach(viewModel.visibleItems, id: \.self) { city in
                Annotation(city.name, coordinate: city.coordinate) {
                    CityAnnotationView()
                }
            }
        }
}

    private struct CityAnnotationView: View {
        var body: some View {
            Circle()
                .foregroundStyle(.red)
                .frame(width: MapConstants.annotationSize)
        }
    }

    private struct OutlierAnnotationView: View {
        var body: some View {
            Circle()
                .foregroundStyle(.gray)
                .frame(width: MapConstants.annotationSize)
        }
    }

    private struct ClusterAnnotationView: View {
        let size: Int

        var body: some View {
            Image(systemName: size <= 50 ? "\(size).circle.fill" : "plus.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
                .font(.largeTitle)
        }
    }

    private struct LoadingOverlayView: View {
        let isLoading: Bool
        let selectedFile: String

        var body: some View {
            if isLoading {
                Color.black.opacity(MapConstants.loadingOverlayOpacity)
                    .clipShape(.rect(cornerRadius: MapConstants.loadingOverlayCornerRadius))
                    .allowsHitTesting(false)
                
                ProgressView {
                    Text("Loading \(selectedFile)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .progressViewStyle(.circular)
                .scaleEffect(MapConstants.loadingScaleFactor)
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Controls Panel
    
    private struct ControlsPanelView: View {
        @Bindable var viewModel: ClusterMapViewModel
        let onClusteringToggle: () -> Void
        let onSpacingChange: () -> Void
        let onVisibleOnlyToggle: () -> Void
        let onFileChange: (String, String) -> Void
        
        private var visibleCount: Int {
            viewModel.clusteringSettings.enabled
                ? viewModel.clusterManager.clusters.reduce(0) { $0 + $1.items.count } + viewModel.clusterManager.outliers.count
                : viewModel.visibleItems.count
        }
        
        private var cityCount: Int {
            viewModel.clusterManager.clusters.filter { $0.items.count == 1 }.count
        }
        
        private var clusterCount: Int {
            viewModel.clusterManager.clusters.filter { $0.items.count > 1 }.count
        }
        
        private var outlierCount: Int {
            viewModel.clusterManager.outliers.count
        }
        
        var body: some View {
            HStack(spacing: 24) {
                StatisticsView(
                    totalCities: viewModel.items.count,
                    useClustering: viewModel.clusteringSettings.enabled,
                    visibleCount: visibleCount,
                    cityCount: cityCount,
                    clusterCount: clusterCount,
                    outlierCount: outlierCount
                )
                
                Spacer()
                
                ClusteringControlsView(
                    useClustering: $viewModel.clusteringSettings.enabled,
                    spacing: $viewModel.clusteringSettings.spacing,
                    onlyVisible: viewModel.clusteringSettings.onlyVisible,
                    onClusteringToggle: onClusteringToggle,
                    onSpacingChange: onSpacingChange
                )
                
                Divider()
                    .frame(height: 60)
                
                DataSourceControlsView(
                    availableFiles: viewModel.dataSource.availableFiles,
                    selectedFile: $viewModel.dataSource.selectedFile,
                    onlyVisible: $viewModel.clusteringSettings.onlyVisible,
                    onVisibleOnlyToggle: onVisibleOnlyToggle,
                    onFileChange: onFileChange
                )
            }
        }
    }
    
    // MARK: - Setup and Handlers
    
    /// Sets up the initial state when the map first appears.
    ///
    /// This method caches the map proxy, loads available city files from the bundle,
    /// and triggers the initial data load for the default or first available file.
    ///
    /// - Parameter mapProxy: The MapKit proxy for coordinate conversions
    private func setupInitialState(mapProxy: MapProxy) {
        viewModel.cachedMapProxy = mapProxy
        
        // Populate available files from the `USCities` subdirectory in the bundle
        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "USCities") {
            let names = urls.map { $0.deletingPathExtension().lastPathComponent }.sorted()
            viewModel.dataSource.availableFiles = names
            if viewModel.dataSource.selectedFile.isEmpty {
                viewModel.dataSource.selectedFile = names.first ?? "USCities1813"
            }
        } else {
            // Fallback default
            viewModel.dataSource.availableFiles = ["USCities1813"]
            if viewModel.dataSource.selectedFile.isEmpty {
                viewModel.dataSource.selectedFile = "USCities1813"
            }
        }
        
        let selectedFile = viewModel.dataSource.selectedFile
        Task.detached {
            let decoded = Bundle.main.decodeCached([City].self, "USCities/\(selectedFile)") ?? []
            await MainActor.run {
                self.viewModel.items = decoded
                self.viewModel.cameraPosition = .region(self.itemsMapRegion)
            }
        }
    }
    
    /// Handles switching between different city data files.
    ///
    /// This method clears the current items, optionally clears clusters if clustering is enabled,
    /// loads the new data file, and updates the camera position to fit the new items.
    ///
    /// - Parameters:
    ///   - oldFile: The previously selected file name
    ///   - newFile: The newly selected file name
    private func handleFileChange(oldFile: String, newFile: String) {
        guard !newFile.isEmpty else { return }
        guard oldFile != newFile else { return }
        
        Task { @MainActor in
            viewModel.dataSource.isLoading = true
            defer { viewModel.dataSource.isLoading = false }
            
            viewModel.items = [] // clear all markers from the map
            
            if viewModel.clusteringSettings.enabled {
                if let proxy = viewModel.cachedMapProxy,
                   let epsilon = proxy.degrees(fromPixels: Int(viewModel.clusteringSettings.spacing)) {
                    await viewModel.clusterManager.update([], epsilon: epsilon)
                }
            }
            
            let decoded = await Task.detached {
                Bundle.main.decode([City].self, "USCities/\(newFile)") ?? []
            }.value
            viewModel.items = decoded
            viewModel.cameraPosition = .region(itemsMapRegion)
        }
    }

    // MARK: - Computed Regions
    
    /// Computes a map region that encompasses all loaded city items.
    ///
    /// - Returns: A region that fits all items, or the default region if items is empty
    private var itemsMapRegion: MKCoordinateRegion {
        let coordinateArray = viewModel.items.map { $0.coordinate }
        return coordinateArray.boundingRegion() ?? viewModel.defaultRegion
    }

    // MARK: - Update Scheduling
    
    /// Schedules an update of visible items or clusters with debouncing.
    ///
    /// This method determines whether to update clusters or raw items based on
    /// the current clustering state, then delegates to the appropriate handler.
    ///
    /// - Parameters:
    ///   - withVisibleOnly: If true, filters to only items in the visible map region
    ///   - delayMilliseconds: Debounce delay before executing the update
    private func scheduleUpdate(withVisibleOnly: Bool = true, delayMilliseconds: UInt64 = MapConstants.updateDebounceMS) {
        if viewModel.clusteringSettings.enabled {
            scheduleClusterUpdate(withVisibleOnly: withVisibleOnly, delayMilliseconds: delayMilliseconds)
        } else {
            scheduleItemsUpdate(withVisibleOnly: withVisibleOnly, delayMilliseconds: delayMilliseconds)
        }
    }

    /// Schedules an update of visible items without clustering.
    ///
    /// This method filters items based on the visible map region and updates the
    /// `visibleItems` array. Updates are debounced using the UpdateCoordinator.
    ///
    /// - Parameters:
    ///   - withVisibleOnly: If true, filters to only items in the visible map region
    ///   - delayMilliseconds: Debounce delay before executing the update
    private func scheduleItemsUpdate(withVisibleOnly: Bool = true, delayMilliseconds: UInt64 = MapConstants.updateDebounceMS) {
        let itemsSnapshot = viewModel.items
        let regionSnapshot = viewModel.cachedItemsRegion
        let defaultRegionSnapshot = viewModel.defaultRegion

        Task {
            await updateCoordinator.scheduleUpdate(delay: delayMilliseconds) {
                if withVisibleOnly {
                    let regionToUse = await MapRegionHelper.resolveRegion(
                        cached: regionSnapshot,
                        items: itemsSnapshot,
                        fallback: defaultRegionSnapshot
                    )
                    let sourceItems = MapRegionHelper.filterItems(itemsSnapshot, in: regionToUse)

                    await MainActor.run {
                        self.viewModel.visibleItems = sourceItems
                    }
                } else {
                    await MainActor.run {
                        self.viewModel.visibleItems = itemsSnapshot
                    }
                }
            }
        }
    }

    /// Schedules a cluster update using DBSCAN algorithm.
    ///
    /// This method filters items based on the visible map region, then performs
    /// clustering using the ClusterManager. Updates are debounced using the UpdateCoordinator.
    ///
    /// - Parameters:
    ///   - withVisibleOnly: If true, clusters only items in the visible map region
    ///   - delayMilliseconds: Debounce delay before executing the update
    private func scheduleClusterUpdate(withVisibleOnly: Bool = true, delayMilliseconds: UInt64 = MapConstants.updateDebounceMS) {
        let spacingSnapshot = Int(viewModel.clusteringSettings.spacing)
        let itemsSnapshot = viewModel.items
        let regionSnapshot = viewModel.cachedItemsRegion
        let defaultRegionSnapshot = viewModel.defaultRegion
        let withVisibleOnlySnapshot = withVisibleOnly

        Task {
            await updateCoordinator.scheduleUpdate(delay: delayMilliseconds) {
                // compute source items (visible-only or all)
                let sourceItems: [City]
                if withVisibleOnlySnapshot {
                    let regionToUse = await MapRegionHelper.resolveRegion(
                        cached: regionSnapshot,
                        items: itemsSnapshot,
                        fallback: defaultRegionSnapshot
                    )
                    sourceItems = MapRegionHelper.filterItems(itemsSnapshot, in: regionToUse)

                } else {
                    sourceItems = itemsSnapshot
                }

                await MainActor.run {
                    self.viewModel.dataSource.isLoading = true
                }

                await MainActor.run {
                    guard let proxy = self.viewModel.cachedMapProxy,
                          let epsilon = proxy.degrees(fromPixels: spacingSnapshot) else {
                        Task { @MainActor in
                            self.viewModel.dataSource.isLoading = false
                        }
                        return
                    }

                    Task { @MainActor in
                        defer { self.viewModel.dataSource.isLoading = false }
                        await self.viewModel.clusterManager.update(
                            sourceItems,
                            epsilon: epsilon
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ClusterContentView()
}
