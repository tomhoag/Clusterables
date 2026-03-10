//
//  ClusterContentView.swift
//  MichiganMapClustering
//
//  Created by Tom Hoag on 3/28/25.
//

import Clusterables
import MapKit
import SwiftUI

// MARK: - View Model

/// View model that manages all state for the cluster map view.
///
/// This observable class consolidates map state, clustering settings, performance metrics,
/// and data source information into logical groups for better organization and testability.
@Observable
class ClusterMapViewModel {
    var clusterManager = ClusterManager<City>()
    var items: [City] = []
    var visibleItems: [City] = []
    var cameraPosition: MapCameraPosition = .automatic
    
    /// Settings related to clustering behavior
    struct ClusteringSettings {
        var enabled: Bool = false
        var useKDTree: Bool = true
        var spacing: Double = MapConstants.defaultSpacing
        var onlyVisible: Bool = true
    }
    var clusteringSettings = ClusteringSettings()
    
    /// Performance metrics for clustering operations
    struct PerformanceMetrics {
        var lastUpdateDuration: TimeInterval?
        var dbscanDuration: TimeInterval?
    }
    var metrics = PerformanceMetrics()
    
    /// Data source state for file loading
    struct DataSource {
        var availableFiles: [String] = []
        var selectedFile: String = ""
        var isLoading: Bool = false
    }
    var dataSource = DataSource()
    
    // Map state
    var cachedMapProxy: MapProxy?
    var cachedItemsRegion: MKCoordinateRegion?
    
    let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5),
        span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0))
}

// MARK: - Constants

/// Constants used throughout the map view for consistent sizing and timing.
enum MapConstants {
    /// Size of individual city annotation markers
    static let annotationSize: CGFloat = 7
    
    /// Debounce delay in milliseconds for map updates
    static let updateDebounceMS: UInt64 = 150
    
    /// Valid range for cluster spacing slider
    static let spacingRange: ClosedRange<Double> = 10...100
    
    /// Step increment for spacing slider
    static let spacingStep: Double = 5
    
    /// Default spacing value for new instances
    static let defaultSpacing: Double = 30
    
    /// Width of the spacing slider control
    static let sliderWidth: CGFloat = 150
    
    /// Opacity of the loading overlay background
    static let loadingOverlayOpacity: Double = 0.25
    
    /// Corner radius for the loading overlay
    static let loadingOverlayCornerRadius: CGFloat = 8
    
    /// Scale factor for the loading spinner
    static let loadingScaleFactor: CGFloat = 1.5
}

// MARK: - Region Helper

/// Utility for map region calculations and coordinate filtering.
enum MapRegionHelper {
    /// Normalizes longitude to the standard [-180, 180] range.
    ///
    /// - Parameter longitude: The longitude value to normalize
    /// - Returns: Normalized longitude in the range [-180, 180]
    static func normalizeLongitude(_ longitude: Double) -> Double {
        var lon = longitude
        while lon < -180.0 { lon += 360.0 }
        while lon > 180.0 { lon -= 360.0 }
        return lon
    }
    
    /// Filters items to only those within the specified region, handling antimeridian crossing.
    ///
    /// This method properly handles regions that cross the International Date Line (antimeridian)
    /// by detecting when the minimum longitude is greater than the maximum longitude.
    ///
    /// - Parameters:
    ///   - items: The array of items to filter
    ///   - region: The map region to filter within
    /// - Returns: Array of items that fall within the specified region
    static func filterItems<T: Clusterable>(_ items: [T], in region: MKCoordinateRegion) -> [T] {
        let centerLon = normalizeLongitude(region.center.longitude)
        let lonDelta = region.span.longitudeDelta
        let minLon = normalizeLongitude(centerLon - lonDelta / 2.0)
        let maxLon = normalizeLongitude(centerLon + lonDelta / 2.0)
        let minLat = region.center.latitude - region.span.latitudeDelta / 2.0
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2.0
        let crossesAntimeridian = minLon > maxLon
        
        return items.filter { item in
            let lat = item.coordinate.latitude
            guard lat >= minLat && lat <= maxLat else { return false }
            let lon = normalizeLongitude(item.coordinate.longitude)
            if crossesAntimeridian {
                return lon >= minLon || lon <= maxLon
            } else {
                return lon >= minLon && lon <= maxLon
            }
        }
    }
}

// MARK: - Update Coordinator

/// Actor that coordinates debounced map updates with automatic cancellation.
///
/// This actor ensures thread-safe management of update tasks and provides
/// automatic cancellation of in-flight updates when new ones are scheduled.
actor UpdateCoordinator {
    private var currentTask: Task<Void, Never>?
    
    /// Schedules an update with debouncing, canceling any previous pending update.
    ///
    /// - Parameters:
    ///   - delay: Delay in milliseconds before executing the work
    ///   - work: The async work to perform after the delay
    func scheduleUpdate(
        delay: UInt64,
        work: @escaping @Sendable () async -> Void
    ) {
        currentTask?.cancel()
        currentTask = Task {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            guard !Task.isCancelled else { return }
            await work()
        }
    }
    
    /// Cancels all pending updates.
    func cancelAll() {
        currentTask?.cancel()
    }
}

// MARK: - Main View

/// A SwiftUI view that displays an interactive map with optional clustering of city markers.
///
/// This view provides:
/// - Interactive map with city annotations
/// - Optional DBSCAN-based clustering with adjustable spacing
/// - Performance metrics display
/// - Multiple city data file sources
/// - Visibility filtering for better performance
struct ClusterContentView: View, ClusterManagerProvider {

    @State private var viewModel = ClusterMapViewModel()
    @State private var updateCoordinator = UpdateCoordinator()
    
    var clusterManager: ClusterManager<City> { viewModel.clusterManager }

    var body: some View {
        VStack(spacing: 0) {
            mapView
            Divider()
            controlsView
                .padding()
        }
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
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
            
            loadingOverlay
        }
    }
    
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        if viewModel.clusteringSettings.enabled {
            ForEach(viewModel.clusterManager.clusters) { cluster in
                if cluster.size == 1, let city = cluster.items.first {
                    Annotation(city.name, coordinate: city.coordinate) {
                        cityAnnotationView
                    }
                } else {
                    Annotation("", coordinate: cluster.center) {
                        ClusterAnnotationView(size: cluster.size)
                    }
                }
            }
        } else {
            ForEach(viewModel.visibleItems, id: \.self) { city in
                Annotation(city.name, coordinate: city.coordinate) {
                    cityAnnotationView
                }
            }
        }
    }

    /// Map Annotation Views
    private var cityAnnotationView: some View {
        Circle()
            .foregroundColor(.red)
            .frame(width: MapConstants.annotationSize)
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

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.dataSource.isLoading {
            Color.black.opacity(MapConstants.loadingOverlayOpacity)
                .cornerRadius(MapConstants.loadingOverlayCornerRadius)
                .allowsHitTesting(false)
            
            ProgressView {
                Text("Loading \(viewModel.dataSource.selectedFile)")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .progressViewStyle(.circular)
            .scaleEffect(MapConstants.loadingScaleFactor)
            .zIndex(1)
        }
    }
    
    // MARK: - Controls View
    
    private var controlsView: some View {
        HStack(spacing: 24) {
            StatisticsView(
                totalCities: viewModel.items.count,
                useClustering: viewModel.clusteringSettings.enabled,
                visibleCount: visibleCount,
                cityCount: cityCount,
                clusterCount: clusterCount
            )
            
            Spacer()
            
            ClusteringControlsView(
                useClustering: $viewModel.clusteringSettings.enabled,
                useKDTree: $viewModel.clusteringSettings.useKDTree,
                spacing: $viewModel.clusteringSettings.spacing,
                onlyVisible: viewModel.clusteringSettings.onlyVisible,
                onSpacingChange: {
                    Task { @MainActor in
                        viewModel.dataSource.isLoading = true
                        scheduleUpdate(withVisibleOnly: viewModel.clusteringSettings.onlyVisible)
                        viewModel.dataSource.isLoading = false
                    }
                }
            )
            
            Divider()
                .frame(height: 60)
            
            DataSourceControlsView(
                availableFiles: viewModel.dataSource.availableFiles,
                selectedFile: $viewModel.dataSource.selectedFile,
                onlyVisible: $viewModel.clusteringSettings.onlyVisible,
                onFileChange: { oldFile, newFile in
                    handleFileChange(oldFile: oldFile, newFile: newFile)
                }
            )
        }
    }
    
    // MARK: - Computed Properties for Statistics
    
    private var visibleCount: Int {
        viewModel.clusteringSettings.enabled 
            ? viewModel.clusterManager.clusters.reduce(0) { $0 + $1.items.count } 
            : viewModel.visibleItems.count
    }
    
    private var cityCount: Int {
        viewModel.clusterManager.clusters.filter { $0.items.count == 1 }.count
    }
    
    private var clusterCount: Int {
        viewModel.clusterManager.clusters.filter { $0.items.count > 1 }.count
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
        
        Task { @MainActor in
            viewModel.items = Bundle.main.decodeCached([City].self, "USCities/\(viewModel.dataSource.selectedFile)") ?? []
            viewModel.cameraPosition = .region(itemsMapRegion)
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
            viewModel.items = [] // clear all markers from the map
            
            if viewModel.clusteringSettings.enabled {
                if let proxy = viewModel.cachedMapProxy {
                    _ = await viewModel.clusterManager.update(
                        [],
                        mapProxy: proxy,
                        spacing: Int(viewModel.clusteringSettings.spacing),
                        useKDTree: viewModel.clusteringSettings.useKDTree
                    )
                }
            }
            
            viewModel.items = Bundle.main.decode([City].self, "USCities/\(newFile)") ?? []
            viewModel.cameraPosition = .region(itemsMapRegion)
            viewModel.dataSource.isLoading = false
        }
    }

    // MARK: - Computed Regions
    
    /// Computes a map region that encompasses all loaded city items.
    ///
    /// - Returns: A region that fits all items, or the default region if items is empty
    var itemsMapRegion: MKCoordinateRegion {
        let coordinateArray = viewModel.items.map { $0.coordinate }
        return coordinateArray.boundingRegion() ?? viewModel.defaultRegion
    }

    // MARK: - Region Filtering
    
    /// Filters items to only those within the specified region using the MapRegionHelper.
    ///
    /// - Parameters:
    ///   - items: The array of cities to filter
    ///   - region: The map region to filter within
    /// - Returns: Array of cities that fall within the specified region
    private func filterItemsInRegion(_ items: [City], region: MKCoordinateRegion) -> [City] {
        MapRegionHelper.filterItems(items, in: region)
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
                let overallStart = DispatchTime.now()

                if withVisibleOnly {
                    // determine region to use (safe fallback to computed region)
                    let regionToUse: MKCoordinateRegion
                    if let cachedRegion = regionSnapshot {
                        regionToUse = cachedRegion
                    } else {
                        // compute from items
                        let coordinateArray = itemsSnapshot.map { $0.coordinate }
                        regionToUse = await coordinateArray.boundingRegion() ?? defaultRegionSnapshot
                    }

                    let sourceItems = await MainActor.run {
                        self.filterItemsInRegion(itemsSnapshot, region: regionToUse)
                    }
                    
                    let overallEnd = DispatchTime.now()

                    await MainActor.run {
                        self.viewModel.visibleItems = sourceItems
                        self.viewModel.metrics.lastUpdateDuration = Double(overallEnd.uptimeNanoseconds - overallStart.uptimeNanoseconds) / 1e9
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
        let useKDTreeSnapshot = viewModel.clusteringSettings.useKDTree
        let itemsSnapshot = viewModel.items
        let regionSnapshot = viewModel.cachedItemsRegion
        let defaultRegionSnapshot = viewModel.defaultRegion
        let withVisibleOnlySnapshot = withVisibleOnly

        Task {
            await updateCoordinator.scheduleUpdate(delay: delayMilliseconds) {
                // compute source items (visible-only or all)
                let sourceItems: [City]
                if withVisibleOnlySnapshot {
                    // determine region to use (safe fallback to computed region)
                    let regionToUse: MKCoordinateRegion
                    if let cachedRegion = regionSnapshot {
                        regionToUse = cachedRegion
                    } else {
                        // compute from items
                        let coordinateArray = itemsSnapshot.map { $0.coordinate }
                        regionToUse = await coordinateArray.boundingRegion() ?? defaultRegionSnapshot
                    }

                    sourceItems = await MainActor.run {
                        self.filterItemsInRegion(itemsSnapshot, region: regionToUse)
                    }
                } else {
                    sourceItems = itemsSnapshot
                }

                await MainActor.run {
                    guard let proxy = self.viewModel.cachedMapProxy else { return }

                    Task { @MainActor in
                        await self.viewModel.clusterManager.update(
                            sourceItems,
                            mapProxy: proxy,
                            spacing: spacingSnapshot,
                            useKDTree: useKDTreeSnapshot
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

/// Displays statistics about total cities, visible items, and clustering breakdown.
private struct StatisticsView: View {
    let totalCities: Int
    let useClustering: Bool
    let visibleCount: Int
    let cityCount: Int
    let clusterCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            statisticRow(label: "Total Cities", value: "\(totalCities)")
            statisticRow(label: "Visible", value: "\(visibleCount)")
            
            if useClustering {
                HStack(spacing: 12) {
                    statisticRow(label: "Cities", value: "\(cityCount)")
                    statisticRow(label: "Clusters", value: "\(clusterCount)")
                }
                .padding(.leading, 8)
            }
        }
        .font(.system(.body, design: .rounded))
    }
    
    private func statisticRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

/// Controls for enabling clustering and adjusting clustering parameters.
private struct ClusteringControlsView: View {
    @Binding var useClustering: Bool
    @Binding var useKDTree: Bool
    @Binding var spacing: Double
    let onlyVisible: Bool
    let onSpacingChange: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            controlRow(label: "Clustering", toggle: $useClustering)
            
            if useClustering {
                VStack(alignment: .trailing, spacing: 8) {
                    controlRow(label: "Use KD-Tree", toggle: $useKDTree)
                    
                    HStack(spacing: 8) {
                        Text("Spacing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(spacing))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .frame(width: 30, alignment: .trailing)
                        Slider(value: $spacing, in: MapConstants.spacingRange, step: MapConstants.spacingStep)
                            .frame(width: MapConstants.sliderWidth)
                            .onChange(of: spacing) { oldValue, newValue in
                                guard oldValue != newValue else { return }
                                onSpacingChange()
                            }
                    }
                }
            }
        }
    }
    
    private func controlRow(label: String, toggle: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Toggle("", isOn: toggle)
                .labelsHidden()
        }
    }
}

/// Controls for selecting data source files and visibility filtering options.
private struct DataSourceControlsView: View {
    let availableFiles: [String]
    @Binding var selectedFile: String
    @Binding var onlyVisible: Bool
    let onFileChange: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            VStack(alignment: .trailing, spacing: 6) {
                Text("Data Source")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedFile) {
                    ForEach(availableFiles, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedFile) { oldFile, newFile in
                    onFileChange(oldFile, newFile)
                }
            }
            
            HStack(spacing: 8) {
                Text("Visible Only")
                Toggle("", isOn: $onlyVisible)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    ClusterContentView()
}
