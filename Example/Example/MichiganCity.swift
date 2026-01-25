//
//  MichiganCity.swift
//  Clusterables
//
//  Created by Tom Hoag on 1/25/26.
//


//===----------------------------------------------------------------------===//
//
// Copyright (c) 2025 Tom Hoag and the MichiganCities project authors
// Licensed under MIT License
//
// See LICENSE for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import MapKit
import SwiftUI
import Clusterables

/**
 A structure representing a city in Michigan.

 This structure encapsulates the basic information about a Michigan city including
 its identifier, name, and geographic coordinates.
 */
public struct MichiganCity: Clusterable, Equatable, Hashable, Sendable {
    // MARK: - Equatable Implementation

    public static func == (lhs: MichiganCity, rhs: MichiganCity) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable Implementation

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    // MARK: - Properties

    /// Unique identifier for the city
    public var id: Int
    /// Name of the city
    public var name: String
    /// Geographic coordinates of the city
    public var coordinate: CLLocationCoordinate2D
}

/**
 An enumeration of Michigan cities with their geographic coordinates and names.

 This enum provides a list of Michigan cities along with their
 associated data and utility functions for mapping and random selection.
 */
public enum MichiganCities: Int, CaseIterable {
    // MARK: - City Cases

    case adrian = 1
    case albion
    case alpena
    case annarbor
    case baycity
    case bentonharbor
    case berkley
    case bigrapids
    case birmingham
    case bloomfieldhills
    case cadillac
    case charlevoix
    case chelsea
    case clawson
    case dearborn
    case detroit
    case eastlansing
    case eastpointe
    case ecorse
    case escanaba
    case fenton
    case ferndale
    case flint
    case grandrapids
    case grandhaven
    case hancock
    case holland
    case houghton
    case ironmountain
    case ishpeming
    case jackson
    case kalamazoo
    case lansing
    case lapeer
    case marquette
    case menominee
    case midland
    case monroe
    case mtclemens
    case mtpleasant
    case muskegon
    case novi
    case owosso
    case pontiac
    case porthuron
    case riverview
    case roseville
    case royaloak
    case saginaw
    case saultstemarie
    case southfield
    case stignace
    case traverse
    case wyandotte
    case ypsilanti

    // MARK: - Properties

    /**
     Returns the unique identifier for the city.

     This ID corresponds to the raw value of the enum case.
     */
    public var id: Int {
        return self.rawValue
    }

    /**
     Returns the geographic coordinates for the city.

     Provides the latitude and longitude for precise location mapping.
     */
    public var coordinate: CLLocationCoordinate2D {
        switch self {
        case .adrian: return CLLocationCoordinate2D(latitude: 41.8975, longitude: -84.0372)
        case .albion: return CLLocationCoordinate2D(latitude: 42.2431, longitude: -84.7530)
        case .alpena: return CLLocationCoordinate2D(latitude: 45.0617, longitude: -83.4327)
        case .annarbor: return CLLocationCoordinate2D(latitude: 42.2808, longitude: -83.7430)
        case .baycity: return CLLocationCoordinate2D(latitude: 43.5945, longitude: -83.8889)
        case .bentonharbor: return CLLocationCoordinate2D(latitude: 42.1167, longitude: -86.4542)
        case .berkley: return CLLocationCoordinate2D(latitude: 42.4987, longitude: -83.1835)
        case .bigrapids: return CLLocationCoordinate2D(latitude: 43.6981, longitude: -85.4837)
        case .birmingham: return CLLocationCoordinate2D(latitude: 42.5467, longitude: -83.2115)
        case .bloomfieldhills: return CLLocationCoordinate2D(latitude: 42.5837, longitude: -83.2454)
        case .cadillac: return CLLocationCoordinate2D(latitude: 44.2517, longitude: -85.4012)
        case .charlevoix: return CLLocationCoordinate2D(latitude: 45.3181, longitude: -85.2584)
        case .chelsea: return CLLocationCoordinate2D(latitude: 42.3181, longitude: -84.0208)
        case .clawson: return CLLocationCoordinate2D(latitude: 42.5339, longitude: -83.1463)
        case .dearborn: return CLLocationCoordinate2D(latitude: 42.3223, longitude: -83.1763)
        case .detroit: return CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)
        case .eastlansing: return CLLocationCoordinate2D(latitude: 42.7368, longitude: -84.4837)
        case .eastpointe: return CLLocationCoordinate2D(latitude: 42.466595, longitude: -82.959213)
        case .ecorse: return CLLocationCoordinate2D(latitude: 42.2543, longitude: -83.1499)
        case .escanaba: return CLLocationCoordinate2D(latitude: 45.7453, longitude: -87.0646)
        case .fenton: return CLLocationCoordinate2D(latitude: 42.79781, longitude: -83.70495)
        case .ferndale: return CLLocationCoordinate2D(latitude: 42.4606, longitude: -83.1346)
        case .flint: return CLLocationCoordinate2D(latitude: 43.0125, longitude: -83.6875)
        case .grandrapids: return CLLocationCoordinate2D(latitude: 42.9634, longitude: -85.6681)
        case .grandhaven: return CLLocationCoordinate2D(latitude: 43.0631, longitude: -86.2285)
        case .hancock: return CLLocationCoordinate2D(latitude: 47.1275, longitude: -88.5809)
        case .holland: return CLLocationCoordinate2D(latitude: 42.7875, longitude: -86.1089)
        case .houghton: return CLLocationCoordinate2D(latitude: 47.1215, longitude: -88.5695)
        case .ironmountain: return CLLocationCoordinate2D(latitude: 45.8202, longitude: -88.0659)
        case .ishpeming: return CLLocationCoordinate2D(latitude: 46.4874, longitude: -87.6674)
        case .jackson: return CLLocationCoordinate2D(latitude: 42.2459, longitude: -84.4013)
        case .kalamazoo: return CLLocationCoordinate2D(latitude: 42.2917, longitude: -85.5872)
        case .lansing: return CLLocationCoordinate2D(latitude: 42.7325, longitude: -84.5555)
        case .lapeer: return CLLocationCoordinate2D(latitude: 43.0514, longitude: -83.3188)
        case .marquette: return CLLocationCoordinate2D(latitude: 46.5437, longitude: -87.3954)
        case .menominee: return CLLocationCoordinate2D(latitude: 45.1077, longitude: -87.6141)
        case .midland: return CLLocationCoordinate2D(latitude: 43.6156, longitude: -84.2472)
        case .monroe: return CLLocationCoordinate2D(latitude: 41.9165, longitude: -83.3977)
        case .mtclemens: return CLLocationCoordinate2D(latitude: 42.5973, longitude: -82.8780)
        case .mtpleasant: return CLLocationCoordinate2D(latitude: 43.5978, longitude: -84.7675)
        case .muskegon: return CLLocationCoordinate2D(latitude: 43.2342, longitude: -86.2484)
        case .novi: return CLLocationCoordinate2D(latitude: 42.4806, longitude: -83.4755)
        case .owosso: return CLLocationCoordinate2D(latitude: 42.9978, longitude: -84.1744)
        case .pontiac: return CLLocationCoordinate2D(latitude: 42.6389, longitude: -83.2911)
        case .porthuron: return CLLocationCoordinate2D(latitude: 42.9709, longitude: -82.4249)
        case .riverview: return CLLocationCoordinate2D(latitude: 42.1742, longitude: -83.1827)
        case .roseville: return CLLocationCoordinate2D(latitude: 42.4972, longitude: -82.9371)
        case .royaloak: return CLLocationCoordinate2D(latitude: 42.4895, longitude: -83.1446)
        case .saginaw: return CLLocationCoordinate2D(latitude: 43.4195, longitude: -83.9508)
        case .saultstemarie: return CLLocationCoordinate2D(latitude: 46.4953, longitude: -84.3453)
        case .southfield: return CLLocationCoordinate2D(latitude: 42.4734, longitude: -83.2219)
        case .stignace: return CLLocationCoordinate2D(latitude: 45.8724, longitude: -84.7275)
        case .traverse: return CLLocationCoordinate2D(latitude: 44.7631, longitude: -85.6206)
        case .wyandotte: return CLLocationCoordinate2D(latitude: 42.2142, longitude: -83.1499)
        case .ypsilanti: return CLLocationCoordinate2D(latitude: 42.2411, longitude: -83.6138)
        }
    }

    /**
     Returns the formatted name of the city.

     Provides proper capitalization and spacing for city names.
     */
    public var name: String {
        switch self {
        case .adrian: return "Adrian"
        case .albion: return "Albion"
        case .alpena: return "Alpena"
        case .annarbor: return "Ann Arbor"
        case .baycity: return "Bay City"
        case .bentonharbor: return "Benton Harbor"
        case .berkley: return "Berkley"
        case .bigrapids: return "Big Rapids"
        case .birmingham: return "Birmingham"
        case .bloomfieldhills: return "Bloomfield Hills"
        case .cadillac: return "Cadillac"
        case .charlevoix: return "Charlevoix"
        case .chelsea: return "Chelsea"
        case .clawson: return "Clawson"
        case .dearborn: return "Dearborn"
        case .detroit: return "Detroit"
        case .eastlansing: return "East Lansing"
        case .eastpointe: return "East Pointe"
        case .ecorse: return "Ecorse"
        case .escanaba: return "Escanaba"
        case .fenton: return "Fenton"
        case .ferndale: return "Ferndale"
        case .flint: return "Flint"
        case .grandrapids: return "Grand Rapids"
        case .grandhaven: return "Grand Haven"
        case .hancock: return "Hancock"
        case .holland: return "Holland"
        case .houghton: return "Houghton"
        case .ironmountain: return "Iron Mountain"
        case .ishpeming: return "Ishpeming"
        case .jackson: return "Jackson"
        case .kalamazoo: return "Kalamazoo"
        case .lansing: return "Lansing"
        case .lapeer: return "Lapeer"
        case .marquette: return "Marquette"
        case .menominee: return "Menominee"
        case .midland: return "Midland"
        case .monroe: return "Monroe"
        case .mtclemens: return "Mount Clemens"
        case .mtpleasant: return "Mount Pleasant"
        case .muskegon: return "Muskegon"
        case .novi: return "Novi"
        case .owosso: return "Owosso"
        case .pontiac: return "Pontiac"
        case .porthuron: return "Port Huron"
        case .riverview: return "Riverview"
        case .roseville: return "Roseville"
        case .royaloak: return "Royal Oak"
        case .saginaw: return "Saginaw"
        case .saultstemarie: return "Sault Ste. Marie"
        case .southfield: return "Southfield"
        case .stignace: return "St. Ignace"
        case .traverse: return "Traverse City"
        case .wyandotte: return "Wyandotte"
        case .ypsilanti: return "Ypsilanti"
        }
    }

    /**
     Converts the enum case to a MichiganCity structure.

     This computed property provides an easy way to convert between the enum
     and struct representations of a city.
     */
    public var asMichiganCity: MichiganCity {
        return MichiganCity(id: self.id, name: self.name, coordinate: self.coordinate)
    }

    // MARK: - Static Methods

    /**
     Returns a random array of Michigan cities.

     - Parameter count: The number of random cities to return
     - Returns: An optional array of MichiganCity structures. Returns nil if count is 0 or negative
     */
    public static func random(count: Int) -> [MichiganCity]? {
        guard count > 0 else { return nil }

        guard count < MichiganCities.allCases.count else {
            return Array(MichiganCities.allCases.map { $0.asMichiganCity })
        }

        return Array(MichiganCities.allCases.shuffled().prefix(count)).map { $0.asMichiganCity }
    }

    /**
     Returns a map region that encompasses both Michigan peninsulas.

     This region is preconfigured with center coordinates and span
     to show both peninsulas with padding.
     */
    public static var mapRegion: MKCoordinateRegion {
        // Center point between both peninsulas
        let center = CLLocationCoordinate2D(
            latitude: 43.802819,
            longitude: -86.112938
        )

        // Span to show both peninsulas with some padding
        let span = MKCoordinateSpan(
            latitudeDelta: 6.0,
            longitudeDelta: 8.0
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}
