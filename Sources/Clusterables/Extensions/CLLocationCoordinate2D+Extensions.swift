import CoreLocation

extension CLLocationCoordinate2D: @retroactive Equatable, @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.latitude)
        hasher.combine(self.longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
