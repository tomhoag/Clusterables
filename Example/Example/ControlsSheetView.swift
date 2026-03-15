//
//  ControlsSheetView.swift
//  Example
//
//  Created by Tom Hoag on 3/14/26.
//

import SwiftUI

/// A sheet view containing clustering and data source controls.
///
/// The layout is designed to fit within a half-height sheet without scrolling.
struct ControlsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ClusterMapViewModel
    let onClusteringToggle: () -> Void
    let onSpacingChange: () -> Void
    let onVisibleOnlyToggle: () -> Void
    let onFileChange: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Clustering", isOn: $viewModel.clusteringSettings.enabled)
                        .onChange(of: viewModel.clusteringSettings.enabled) { _, _ in
                            onClusteringToggle()
                        }

                    if viewModel.clusteringSettings.enabled {
                        HStack {
                            Text("Spacing \(Int(viewModel.clusteringSettings.spacing))")
                                .monospacedDigit()
                            Slider(
                                value: $viewModel.clusteringSettings.spacing,
                                in: MapConstants.spacingRange,
                                step: MapConstants.spacingStep
                            )
                            .onChange(of: viewModel.clusteringSettings.spacing) { oldValue, newValue in
                                guard oldValue != newValue else { return }
                                onSpacingChange()
                            }
                        }
                    }

                    Picker("Data Source", selection: $viewModel.dataSource.selectedFile) {
                        ForEach(viewModel.dataSource.availableFiles, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .onChange(of: viewModel.dataSource.selectedFile) { oldFile, newFile in
                        onFileChange(oldFile, newFile)
                    }
                    Toggle("Visible Only", isOn: $viewModel.clusteringSettings.onlyVisible)
                        .onChange(of: viewModel.clusteringSettings.onlyVisible) { _, _ in
                            onVisibleOnlyToggle()
                        }
                    Toggle("Show Statistics", isOn: $viewModel.clusteringSettings.showStatistics)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
    }
}

#Preview {
    @Previewable @State var viewModel = ClusterMapViewModel()

    ControlsSheetView(
        viewModel: viewModel,
        onClusteringToggle: {},
        onSpacingChange: {},
        onVisibleOnlyToggle: {},
        onFileChange: { _, _ in }
    )
}
