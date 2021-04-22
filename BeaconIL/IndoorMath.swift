//
//  IndoorMath.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 17.03.2021.
//

import Foundation

struct RssiStorage {
    let major: Int
    let minor: Int
    
    var lastUpdateTime: Date
    
    var x: Double
    var y: Double
    
    var onMeterRSSI: Int
    var RSSI: [Int]
}

class IndoorMath {
    static let maxAgeSeconds = 12.0
    
    private var beaconStorage: [RssiStorage] = []
    private var thresholdEma: Int
    
    static func calculateRealDistance(txCalibratedPower: Int, rssi: Int) -> Double {
        let ratioDB = txCalibratedPower - rssi
        return pow(10.0, Double(ratioDB) / 20)
    }
    
    init(thresholdEma: Int) {
        self.thresholdEma = thresholdEma
    }
    
    func setEmaSize(thresholdEma: Int) {
        self.thresholdEma = thresholdEma
        for (index, beacon) in beaconStorage.enumerated() {
            if beacon.RSSI.count > thresholdEma {
                beaconStorage[index].RSSI = Array(beacon.RSSI.reversed()[0..<thresholdEma]).reversed()
            }
        }
    }
    
    func updateVisibleBeacons(beacons: [BeaconData]) {
        // Calculate exponential moving average with left shifting
        for (index, beacon) in beacons.enumerated() {
            if var known = beaconStorage.first(where: {$0.major == beacon.major && $0.minor == beacon.minor}) {
                known.lastUpdateTime = beacon.lastUpdateTime
                known.x = beacon.coordinateX
                known.y = beacon.coordinateY
                known.onMeterRSSI = beacon.onMeterRSSI
                
                let rssiArray = known.RSSI
                if rssiArray.count > 0 && rssiArray.last! != beacon.rssi {
                    if rssiArray.count < thresholdEma + 1 {
                        known.RSSI.append(beacon.rssi)
                    } else {
                        let weight = 2 / Double(thresholdEma + 1)
                        let rssiEma = Double(beacon.rssi - rssiArray[thresholdEma]) * weight + Double(rssiArray[thresholdEma])
                        
                        known.RSSI = Array(known.RSSI[1...])
                        known.RSSI.append(Int(rssiEma.rounded(.toNearestOrAwayFromZero)))
                    }
                }
                
                beaconStorage[index] = known
            } else {
                beaconStorage.append(RssiStorage(major: beacon.major, minor: beacon.minor, lastUpdateTime: beacon.lastUpdateTime, x: beacon.coordinateX, y: beacon.coordinateY, onMeterRSSI: beacon.onMeterRSSI, RSSI: [beacon.rssi]))
            }
        }
        
        // Remove old values
        beaconStorage.removeAll { $0.lastUpdateTime.distance(to: Date()) > IndoorMath.maxAgeSeconds }
    }
    
    func getLocation() -> (Double?, Double?) {
        let localCopy = beaconStorage
        if localCopy.count < 3 {
            return (nil, nil)
        }
          
        var positions = [[Double]]()
        var distances = [Double]()
        
        for (_, beacon) in localCopy.enumerated() {
            positions.append([beacon.x, beacon.y])

            let dist = IndoorMath.calculateRealDistance(txCalibratedPower: beacon.onMeterRSSI, rssi: beacon.RSSI.last!)
            distances.append(dist)
        }
        
//        // Add fake test data
//        positions.append([1.5, 5.0])
//        distances.append(3.0)
//
//        positions.append([-4.5, -6.7])
//        distances.append(4.0)
//
//        positions.append([18.5, 12.5])
//        distances.append(5.9)
//
//        positions.append([10.5 , 15.6])
//        distances.append(13.1)
        
        let lmaMath = LMAMath()
        let location = lmaMath.solve(positions: positions, distances: distances)
        
        return (location.x, location.y)
    }
}
