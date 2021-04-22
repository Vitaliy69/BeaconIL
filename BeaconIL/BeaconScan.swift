//
//  BeaconScan.swift
//  iBeacon
//
//  Created by Vitaliy Gribko on 27.02.2021.
//

import UIKit
import CoreLocation

class BeaconScan: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    
    private var beaconRegion: CLBeaconRegion!
    private var identityConstraint: CLBeaconIdentityConstraint!
    
    private var appSettings: ApplicationSettings
    private var beaconKnown: BeaconKnown
    
    private var calibratingBeacon: BeaconData?
    
//    private struct DebugBeacon {
//        var timestamp: Date
//        var uuid: UUID
//        var major: NSNumber
//        var minor: NSNumber
//        var proximity: CLProximity
//        var accuracy: CLLocationAccuracy
//        var rssi: Int
//    }
    
    init(appSettings: ApplicationSettings, beaconKnown: BeaconKnown) {
        self.appSettings = appSettings
        self.beaconKnown = beaconKnown
        
        super.init()
        
        updateScanSettings()
        locationManager.delegate = self
        if (CLLocationManager.authorizationStatus() != .authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init(ApplicationSettings.notificationRSSIStart), object: nil, queue: nil, using: { (notification) in
            if let dict = notification.userInfo as NSDictionary? {
                if let data = dict["calibrate"] as? BeaconData {
                    self.calibratingBeacon = data
                }
            }
        })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init(ApplicationSettings.notificationRSSIStop), object: nil, queue: nil, using: { (_) in
            self.calibratingBeacon = nil
        })
        
//        let uuid = UUID(uuidString: "07070707-0405-0607-0809-0A0B0C0D0E00")!
//        let knownBeacons = [DebugBeacon(timestamp: Date(), uuid: uuid, major: 256, minor: 256, proximity: .near, accuracy: CLLocationAccuracy(1.4), rssi: -52),
//                            DebugBeacon(timestamp: Date(), uuid: uuid, major: 256, minor: 512, proximity: .far, accuracy: CLLocationAccuracy(4.5), rssi: -65),
//                            DebugBeacon(timestamp: Date(), uuid: uuid, major: 256, minor: 1024, proximity: .far
//                                        , accuracy: CLLocationAccuracy(6.7), rssi: -69)]
//
//        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        var snapshot = appDelegate.dataSource.snapshot()
//        snapshot.appendSections([.main])
    }
    
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        if calibratingBeacon != nil {
            if let beacon = beacons.filter( { $0.major.intValue == calibratingBeacon?.major && $0.minor.intValue == calibratingBeacon?.minor } ).first {
                NotificationCenter.default.post(name: NSNotification.Name.init(ApplicationSettings.notificationBeaconRSSI), object: nil, userInfo: ["rssi": beacon])
            }
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if !appDelegate.tableShouldUpdate {
            return
        }
        
        var snapshot = appDelegate.dataSource.snapshot()
        let knownBeacons = beacons.filter{ $0.proximity != .unknown }
        
        for (_, beacon) in knownBeacons.enumerated() {
            var imageName = ""
            switch beacon.proximity {
            case .immediate:
                imageName = "immediate"
            case .near:
                imageName = "near"
            case .far:
                imageName = "far"
            default:
                break
            }
            
            var (x, y): (Double, Double) = (0.0, 0.0)
            var distance = Double(beacon.accuracy)
            var onMeterRSSI = -59
            var name = ""
            
            for (_, beaconsCoordinate) in beaconKnown.beaconsCoordinate.enumerated() {
                if beaconsCoordinate.dataAccessor.uuid == beacon.uuid &&
                    beaconsCoordinate.dataAccessor.major == beacon.major.intValue &&
                    beaconsCoordinate.dataAccessor.minor == beacon.minor.intValue {
                    (x, y) = (beaconsCoordinate.dataAccessor.valueX, beaconsCoordinate.dataAccessor.valueY)
                    distance = IndoorMath.calculateRealDistance(txCalibratedPower: onMeterRSSI, rssi: beacon.rssi)
                    onMeterRSSI = beaconsCoordinate.dataAccessor.onMeterRSSI
                    name = beaconsCoordinate.dataAccessor.name
                }
            }
            
            let beaconData = BeaconData(rssi: beacon.rssi, major: beacon.major.intValue, minor: beacon.minor.intValue, coordinateX: x, coordinateY: y, distance: distance, imageName: imageName, lastUpdateTime: beacon.timestamp, onMeterRSSI: onMeterRSSI, name: name)
            var updated = false
            
            for item in snapshot.itemIdentifiers(inSection: .main) {
                if item.contains(major: beacon.major.intValue, minor: beacon.minor.intValue) {
                    
                    if item.rssi != beaconData.rssi || item.distance != beaconData.distance {
                        snapshot.insertItems([beaconData], beforeItem: item)
                        snapshot.deleteItems([item])
                    }
                    
                    updated = true
                }
            }
            
            if !updated {
                snapshot.appendItems([beaconData], toSection: .main)
            }
        }
        
        for item in snapshot.itemIdentifiers(inSection: .main) {
            if item.lastUpdateTime.distance(to: Date()) > IndoorMath.maxAgeSeconds {
                snapshot.deleteItems([item])
            }
        }
        
        DispatchQueue.main.async {
            appDelegate.dataSource.apply(snapshot, animatingDifferences: self.appSettings.animateUpdates)
            NotificationCenter.default.post(name: NSNotification.Name.init(ApplicationSettings.notificationNewData), object: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                if CLLocationManager.isRangingAvailable() {
                    startScanning()
                }
            }
        } else {
            if status != .notDetermined {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    AlertManager.showAllert(title: "Scaning error", message: "Allow the application the location access in the settings.")
                    
                }
                stopScanning()
            }
            
        }
    }
    
    func startScanning() {
        updateScanSettings()
        locationManager.startMonitoring(for: beaconRegion)
        locationManager.startRangingBeacons(satisfying: identityConstraint)
    }
    
    func stopScanning() {
        locationManager.stopMonitoring(for: beaconRegion)
        locationManager.stopRangingBeacons(satisfying: identityConstraint)
    }
    
    private func updateScanSettings() {
        beaconRegion = CLBeaconRegion(uuid: appSettings.uuid, identifier: "My Beacon")
        identityConstraint = CLBeaconIdentityConstraint(uuid: appSettings.uuid)
    }
}
