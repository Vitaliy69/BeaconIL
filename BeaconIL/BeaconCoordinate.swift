//
//  BeaconCoordinate.swift
//  iBeacon
//
//  Created by Vitaliy Gribko on 27.02.2021.
//

import UIKit

public struct BeaconCoordinates: Codable {
    public var uuid: UUID
    public var major: Int
    public var minor: Int
    
    public var valueX: Double
    public var valueY: Double
    public var onMeterRSSI: Int
    public var name: String
}
