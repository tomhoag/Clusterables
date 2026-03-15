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

