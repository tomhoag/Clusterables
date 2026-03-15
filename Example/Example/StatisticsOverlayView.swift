//
//  StatisticsOverlayView.swift
//  Example
//
//  Created by Tom Hoag on 3/14/26.
//

import SwiftUI
import Clusterables

/// A compact statistics overlay displayed on top of the map.
///
/// The overlay is draggable and clamped to remain within the bounds of its parent container.
struct StatisticsOverlayView: View {
    let viewModel: ClusterMapViewModel
    let containerSize: CGSize
    var safeAreaInsets: EdgeInsets = EdgeInsets()

    @State private var dragOffset: CGSize = .zero
    @State private var overlaySize: CGSize = .zero

    private var visibleCount: Int {
        viewModel.clusteringSettings.enabled
            ? viewModel.clusterManager.clusters.reduce(0) { $0 + $1.items.count }
                + viewModel.clusterManager.outliers.count
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
        StatisticsView(
            totalCities: viewModel.items.count,
            useClustering: viewModel.clusteringSettings.enabled,
            visibleCount: visibleCount,
            cityCount: cityCount,
            clusterCount: clusterCount,
            outlierCount: outlierCount
        )
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            overlaySize = newSize
        }
        .offset(
            x: viewModel.statisticsOverlayOffset.width + dragOffset.width,
            y: viewModel.statisticsOverlayOffset.height + dragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let proposed = CGSize(
                        width: viewModel.statisticsOverlayOffset.width + value.translation.width,
                        height: viewModel.statisticsOverlayOffset.height + value.translation.height
                    )
                    viewModel.statisticsOverlayOffset = clampedOffset(proposed)
                    dragOffset = .zero
                }
        )
    }

    /// Clamps the proposed offset so the overlay stays within the container bounds.
    ///
    /// The overlay starts at the top-leading corner (with padding applied by the parent).
    /// This method ensures no edge of the overlay extends beyond the container.
    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        // The overlay's resting origin is at the top-leading corner of the safe area.
        // containerSize is the safe-area region. Allow dragging beyond it in both
        // directions so the overlay can reach the physical screen edges.
        let minX = -safeAreaInsets.leading
        let minY = -safeAreaInsets.top
        let maxX = containerSize.width - overlaySize.width + safeAreaInsets.trailing
        let maxY = containerSize.height - overlaySize.height + safeAreaInsets.bottom

        return CGSize(
            width: min(max(proposed.width, minX), maxX),
            height: min(max(proposed.height, minY), maxY)
        )
    }
}

#Preview {
    StatisticsOverlayView(
        viewModel: ClusterMapViewModel(),
        containerSize: CGSize(width: 400, height: 800),
        safeAreaInsets: EdgeInsets()
    )
        .padding()
}
