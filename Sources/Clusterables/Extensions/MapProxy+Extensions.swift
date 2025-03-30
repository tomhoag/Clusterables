import MapKit
import SwiftUI

extension MapProxy {
    /**
     Converts a pixel distance to geographic degrees (longitude) at the current map zoom level

     This function calculates how many degrees of longitude are represented by a given number of pixels
     at the current map zoom level. This is useful for determining clustering distances that adapt to
     the current zoom level of the map.

     - Parameter pixels: The number of pixels to convert to degrees
     - Returns: The number of longitude degrees that correspond to the given pixel distance at the current zoom level,
     or `nil` if the conversion cannot be performed
     */
    public func degrees(fromPixels pixels: Int) -> Double? {
        let point1 = CGPoint.zero
        let coord1 = self.convert(point1, from: .global)
        let point2 = CGPoint(x: Double(pixels), y: 0.0)
        let coord2 = self.convert(point2, from: .global)
        if let lon1 = coord1?.longitude, let lon2 = coord2?.longitude {
            return abs(lon1 - lon2)
        }
        return nil
    }
}
