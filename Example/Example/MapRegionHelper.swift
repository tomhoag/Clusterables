//
//  MapRegionHelper.swift
//  Example
//
//  Created by Tom Hoag on 3/28/25.
//

import Clusterables
import MapKit

/// Utility for map region calculations and coordinate filtering.
enum MapRegionHelper {
    
    /// Normalizes longitude to the standard [-180, 180] range.
    ///
    /// - Parameter longitude: The longitude value to normalize
    /// - Returns: Normalized longitude in the range [-180, 180]
    nonisolated static func normalizeLongitude(_ longitude: Double) -> Double {
        var lon = longitude
        while lon < -180.0 { lon += 360.0 }
        while lon > 180.0 { lon -= 360.0 }
        return lon
    }
    

    ///
    /// - Parameters:
    ///   - cached: A previously cached map region, if available
    ///   - items: The items to compute a bounding region from if no cache exists
    ///   - fallback: The default region to use if items produce no bounding region
    /// - Returns: The resolved map region
    nonisolated static func resolveRegion(
        cached: MKCoordinateRegion?,
        items: [some Clusterable],
        fallback: MKCoordinateRegion
    ) async -> MKCoordinateRegion {
        if let cached {
            return cached
        }
        return await items.map { $0.coordinate }.boundingRegion() ?? fallback
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
    /// Resolves the region to use for filtering, preferring a cached region
    /// and falling back to computing a bounding region from items.
    nonisolated static func filterItems<T: Clusterable>(_ items: [T], in region: MKCoordinateRegion) -> [T] {
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
