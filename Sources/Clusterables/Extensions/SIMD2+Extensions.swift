//
//  SIMD2+Extensions.swift
//  Clusterables
//
//  Created by Tom Hoag on 2/2/26.
//


import simd
import KDTree


extension SIMD2<Double>: KDTreePoint {
    public static var dimensions: Int {
        return 2
    }
    
    public func kdDimension(_ dimension: Int) -> Double {
        return dimension == 0 ? self.x : self.y
    }
    
    public func squaredDistance(to otherPoint: SIMD2<Scalar>) -> Double {
        return ((self.x - otherPoint.x) * (self.x - otherPoint.x)) + ((self.y - otherPoint.y) * (self.y - otherPoint.y))
    }
}
