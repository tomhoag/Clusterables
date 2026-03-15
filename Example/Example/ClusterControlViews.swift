//
//  ClusterControlViews.swift
//  Example
//
//  Created by Tom Hoag on 3/28/25.
//

import SwiftUI

/// Displays statistics about total cities, visible items, and clustering breakdown.
struct StatisticsView: View {
    let totalCities: Int
    let useClustering: Bool
    let visibleCount: Int
    let cityCount: Int
    let clusterCount: Int
    let outlierCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            statisticRow(label: "Total Cities", value: "\(totalCities)")
            statisticRow(label: "Visible", value: "\(visibleCount)")
            
            if useClustering {
                HStack(spacing: 12) {
                    statisticRow(label: "Cities", value: "\(cityCount)")
                    statisticRow(label: "Clusters", value: "\(clusterCount)")
                    if outlierCount > 0 {
                        statisticRow(label: "Outliers", value: "\(outlierCount)")
                    }
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
        .accessibilityElement(children: .combine)
    }
}

/// Controls for enabling clustering and adjusting clustering parameters.
struct ClusteringControlsView: View {
    @Binding var useClustering: Bool
    @Binding var spacing: Double
    let onlyVisible: Bool
    let onClusteringToggle: () -> Void
    let onSpacingChange: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {

            Toggle("Clustering", isOn: $useClustering)
                .fixedSize()
                .onChange(of: useClustering) { _, _ in
                    onClusteringToggle()
                }

            if useClustering {
                VStack(alignment: .trailing, spacing: 8) {

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
}

/// Controls for selecting data source files and visibility filtering options.
struct DataSourceControlsView: View {
    let availableFiles: [String]
    @Binding var selectedFile: String
    @Binding var onlyVisible: Bool
    let onVisibleOnlyToggle: () -> Void
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
            
            Toggle("Visible Only", isOn: $onlyVisible)
                .fixedSize()
                .onChange(of: onlyVisible) { _, _ in
                    onVisibleOnlyToggle()
                }
        }
    }
}

#Preview("Statistics") {
    StatisticsView(
        totalCities: 1813,
        useClustering: true,
        visibleCount: 342,
        cityCount: 280,
        clusterCount: 15,
        outlierCount: 47
    )
    .padding()
}

#Preview("Clustering Controls") {
    @Previewable @State var useClustering = true
    @Previewable @State var spacing = 30.0

    ClusteringControlsView(
        useClustering: $useClustering,
        spacing: $spacing,
        onlyVisible: true,
        onClusteringToggle: {},
        onSpacingChange: {}
    )
    .padding()
}

#Preview("Data Source Controls") {
    @Previewable @State var selectedFile = "USCities1813"
    @Previewable @State var onlyVisible = true

    DataSourceControlsView(
        availableFiles: ["USCities938", "USCities1813", "USCities6463"],
        selectedFile: $selectedFile,
        onlyVisible: $onlyVisible,
        onVisibleOnlyToggle: {},
        onFileChange: { _, _ in }
    )
    .padding()
}
