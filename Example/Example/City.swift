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
 A structure representing a city.

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
