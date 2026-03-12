//
//  MapConstants.swift
//  Example
//
//  Created by Tom Hoag on 3/28/25.
//

import SwiftUI

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
