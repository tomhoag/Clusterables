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
extension Array where Element == City {
    /// Compute a geographic centroid for the coordinates in this array.
    /// This converts lat/lon to 3D Cartesian coords, averages them, and
    /// converts back to latitude/longitude. It's more accurate for points
    /// spread across the globe than a simple arithmetic mean.
    var centerCoordinateGeographic: CLLocationCoordinate2D? {
        guard !self.isEmpty else { return nil }

        var x = 0.0
        var y = 0.0
        var z = 0.0

        for city in self {
            let latRad = city.coordinate.latitude * .pi / 180.0
            let lonRad = city.coordinate.longitude * .pi / 180.0
            x += cos(latRad) * cos(lonRad)
            y += cos(latRad) * sin(lonRad)
            z += sin(latRad)
        }

        let total = Double(self.count)
        x /= total
        y /= total
        z /= total

        let lon = atan2(y, x)
        let hyp = sqrt(x * x + y * y)
        let lat = atan2(z, hyp)

        return CLLocationCoordinate2D(latitude: lat * 180.0 / .pi,
                                      longitude: lon * 180.0 / .pi)
    }

    /// A simple arithmetic mean of latitudes and longitudes.
    /// Use this for quick, inexpensive approximations for small geographic extents.
    var centerCoordinateSimple: CLLocationCoordinate2D? {
        guard !self.isEmpty else { return nil }
        var latSum = 0.0
        var lonSum = 0.0
        for city in self {
            latSum += city.coordinate.latitude
            lonSum += city.coordinate.longitude
        }
        return CLLocationCoordinate2D(latitude: latSum / Double(count), longitude: lonSum / Double(count))
    }

    /// Center of the bounding box: midpoint between min/max latitudes and longitudes.
        var centerCoordinateBoundingBox: CLLocationCoordinate2D? {
            guard let first = self.first else { return nil }

            var minLat = first.coordinate.latitude
            var maxLat = minLat
            var minLon = first.coordinate.longitude
            var maxLon = minLon

            for city in self {
                let lat = city.coordinate.latitude
                let lon = city.coordinate.longitude
                if lat < minLat { minLat = lat }
                if lat > maxLat { maxLat = lat }
                if lon < minLon { minLon = lon }
                if lon > maxLon { maxLon = lon }
            }

            let midLat = (minLat + maxLat) / 2.0
            let midLon = (minLon + maxLon) / 2.0
            return CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
        }
}


