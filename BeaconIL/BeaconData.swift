//
//  BeaconData.swift
//  iBeacon
//
//  Created by Vitaliy Gribko on 26.02.2021.
//

import Foundation

struct BeaconData: Hashable {
    let rssi: Int
    let major: Int
    let minor: Int
    
    let coordinateX: Double
    let coordinateY: Double
    
    let distance: Double
    
    let imageName: String
    
    let lastUpdateTime: Date
    let onMeterRSSI: Int
    let name: String
    
    func contains(major: Int, minor: Int) -> Bool {
        if self.major == major && self.minor == minor {
            return true
        } else {
            return false
        }
    }
}

enum Section: Int {
    case main
    
    func description() -> String {
        switch self {
        case .main:
            return "Visible Beacons"
        }
    }
}
