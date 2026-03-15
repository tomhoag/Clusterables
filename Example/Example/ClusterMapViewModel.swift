//
//  ClusterMapViewModel.swift
//  Example
//
//  Created by Tom Hoag on 3/28/25.
//

import Clusterables
import MapKit
import SwiftUI

/// View model that manages all state for the cluster map view.
///
/// This observable class consolidates map state, clustering settings,
/// and data source information into logical groups for better organization and testability.
@Observable
@MainActor
class ClusterMapViewModel {
    var clusterManager = ClusterManager<City>()
    var items: [City] = []
    var visibleItems: [City] = []
    var cameraPosition: MapCameraPosition = .automatic

    /// Settings related to clustering behavior
    struct ClusteringSettings {
        var enabled: Bool = true
        var spacing: Double = MapConstants.defaultSpacing
        var onlyVisible: Bool = true
        var showStatistics: Bool = true
    }
    var clusteringSettings = ClusteringSettings()

    /// Data source state for file loading
    struct DataSource {
        var availableFiles: [String] = []
        var selectedFile: String = ""
        var isLoading: Bool = false
    }
    var dataSource = DataSource()

    /// Persisted position of the statistics overlay across show/hide toggles
    var statisticsOverlayOffset: CGSize = .zero

    // Map state
    var cachedMapProxy: MapProxy?
    var cachedItemsRegion: MKCoordinateRegion?

    let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.0, longitude: -85.5),
        span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0))
}
