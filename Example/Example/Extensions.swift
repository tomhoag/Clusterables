//
//  Extensions.swift
//  Example
//
//  Created by Tom Hoag on 2/26/26.
//

import MapKit
import CoreLocation

// Add a small Bundle helper to decode JSON files from the bundle into Decodable types.
extension Bundle {

    private static var _decodeCache = [String: Any]()

    func decodeCached<T: Decodable>(_ type: T.Type, _ resource: String) -> T? {
        if let cached = Bundle._decodeCache[resource] as? T {
            return cached
        }
        guard let decoded: T = decode(type, resource) else { return nil }
        Bundle._decodeCache[resource] = decoded
        return decoded
    }

    func decode<T: Decodable>(_ type: T.Type, _ resource: String) -> T? {
        // Allow caller to pass either "MichiganCities.json", "USCities/Name.json" or just "MichiganCities"
        var resourcePath = resource
        var subdirectory: String? = nil

        // If resource contains a path (e.g. "USCities/Name.json"), split into subdirectory + filename
        if resourcePath.contains("/") {
            let comps = resourcePath.split(separator: "/").map(String.init)
            if comps.count >= 2 {
                subdirectory = comps.dropLast().joined(separator: "/")
                resourcePath = comps.last ?? resourcePath
            }
        }

        let resourceName: String
        let resourceExtension: String?
        if resourcePath.hasSuffix(".json") {
            resourceName = String(resourcePath.dropLast(5))
            resourceExtension = "json"
        } else {
            resourceName = resourcePath
            resourceExtension = "json"
        }

        let url: URL?
        if let sub = subdirectory {
            url = self.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: sub)
        } else {
            url = self.url(forResource: resourceName, withExtension: resourceExtension)
        }

        guard let fileURL = url else {
            print("Bundle.decode: resource not found: \(resource) (resolved name: \(resourceName) subdirectory: \(subdirectory ?? "nil"))")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Bundle.decode(\(resource)) failed: \(error)")
            return nil
        }
    }
}

extension Array where Element == CLLocationCoordinate2D {

    /// Returns an `MKCoordinateRegion` that encloses all coordinates, handling antimeridian crossing.
    /// - Parameters:
    ///   - padding: fractional padding to add to the computed span (0.1 = 10\%).
    ///   - minSpan: minimum latitude/longitude delta to avoid zero-sized spans.
    /// - Returns: `MKCoordinateRegion` or `nil` for empty array.
    func boundingRegion(padding: Double = 0.1, minSpan: CLLocationDegrees = 0.005) -> MKCoordinateRegion? {
        guard !isEmpty else { return nil }

        // lat min/max
        var minLat = 90.0, maxLat = -90.0
        for coord in self {
            minLat = Swift.min(minLat, coord.latitude)
            maxLat = Swift.max(maxLat, coord.latitude)
        }

        // Normalize longitudes to \(-180, 180] and compute two candidate spans:
        let normLon: (Double) -> Double = { lon in
            var x = lon.truncatingRemainder(dividingBy: 360.0)
            if x <= -180.0 { x += 360.0 }
            else if x > 180.0 { x -= 360.0 }
            return x
        }
        let lonNorm = self.map { normLon($0.longitude) }

        // Candidate 1: use normalized longitudes in [-180, 180]
        let minLon1 = lonNorm.min() ?? 0.0
        let maxLon1 = lonNorm.max() ?? 0.0
        let span1 = maxLon1 - minLon1

        // Candidate 2: shift negatives into [0, 360) to account for wrap-around
        let lonShifted = lonNorm.map { $0 < 0 ? $0 + 360.0 : $0 }
        let minLon2 = lonShifted.min() ?? 0.0
        let maxLon2 = lonShifted.max() ?? 0.0
        let span2 = maxLon2 - minLon2

        // Choose the smaller span (handles antimeridian)
        let useShifted = span2 < span1
        let (minLon, maxLon, rawLonSpan): (Double, Double, Double) = {
            if useShifted {
                return (minLon2, maxLon2, span2)
            } else {
                return (minLon1, maxLon1, span1)
            }
        }()

        // Center longitude: if using shifted coords, convert back to [-180, 180]
        var centerLon = (minLon + maxLon) / 2.0
        if useShifted {
            if centerLon > 180.0 { centerLon -= 360.0 }
        }

        let centerLat = (minLat + maxLat) / 2.0

        // Apply padding and enforce minimum spans
        let latSpanRaw = maxLat - minLat
        let lonSpanRaw = rawLonSpan

        let latSpan = Swift.max(latSpanRaw * (1.0 + padding), minSpan)
        let lonSpan = Swift.max(lonSpanRaw * (1.0 + padding), minSpan)

        // Clamp to valid ranges
        let finalLatSpan = Swift.min(latSpan, 180.0)
        let finalLonSpan = Swift.min(lonSpan, 360.0)

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: finalLatSpan, longitudeDelta: finalLonSpan)
        return MKCoordinateRegion(center: center, span: span)
    }
}
