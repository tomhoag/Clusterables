//
//  City.swift
//  Clusterables
//
//  Created by Tom Hoag on 1/25/26.
//

import MapKit
import SwiftUI
import Clusterables

/**
 A structure representing a city in Michigan.

 This structure encapsulates the basic information about a Michigan city including
 its unique identifier, name, and geographic coordinates.
 */
public struct City: Clusterable, Equatable, Hashable, Sendable, Codable {
    // MARK: - Equatable Implementation

    public static func == (lhs: City, rhs: City) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable Implementation

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    // MARK: - Properties

    /// Unique identifier for the city
    public let id: UUID
    /// Name of the city
    public var name: String
    /// Geographic coordinates of the city
    public var coordinate: CLLocationCoordinate2D

    // MARK: - Initializers

    /**
     Creates a new City with a name and coordinates, generating a new UUID for the id.
     */
    public init(name: String, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.name = name
        self.coordinate = coordinate
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case name
        case coordinate
    }

    enum CoordinateKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        let coordinateContainer = try container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
        let latitude = try coordinateContainer.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try coordinateContainer.decode(CLLocationDegrees.self, forKey: .longitude)
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.id = UUID()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        var coordinateContainer = container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
        try coordinateContainer.encode(coordinate.latitude, forKey: .latitude)
        try coordinateContainer.encode(coordinate.longitude, forKey: .longitude)
    }
}

// MARK: - City collection helpers
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


