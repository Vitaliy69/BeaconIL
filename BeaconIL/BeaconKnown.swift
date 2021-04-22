//
//  BeaconKnown.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 03.03.2021.
//

import UIKit
import CoreData

class BeaconKnown {
    
    var beaconsCoordinate: [Beacons] = []
    
    init() {
        let context = getContext()
        let fetchRequest: NSFetchRequest<Beacons> = Beacons.fetchRequest()
        
        do {
            try beaconsCoordinate = context.fetch(fetchRequest)
        } catch let error as NSError {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                AlertManager.showAllert(title: "Beacon database loading error", message: error.localizedDescription)
            }
        }
    }
    
    func addBeacon(uuid: UUID, major: Int, minor: Int, coordinates: (Double, Double), onMeterRSSI: Int, name: String?) {
        var update = false
        for (index, beacons) in beaconsCoordinate.enumerated() {
            if beacons.dataAccessor.uuid == uuid && beacons.dataAccessor.major == major && beacons.dataAccessor.minor == minor {
                beaconsCoordinate[index].dataAccessor.valueX = coordinates.0
                beaconsCoordinate[index].dataAccessor.valueY = coordinates.1
                beaconsCoordinate[index].dataAccessor.onMeterRSSI = onMeterRSSI
                beaconsCoordinate[index].dataAccessor.name = name ?? ""
                
                update = true
            }
        }
        
        if !update {
            let beacon = Beacons(context: getContext())
            beacon.dataAccessor = BeaconCoordinates(uuid: uuid, major: major, minor: minor, valueX: coordinates.0, valueY: coordinates.1, onMeterRSSI: onMeterRSSI, name: name ?? "")
            beaconsCoordinate.append(beacon)
        }

        do {
            try getContext().save()
        } catch let error as NSError {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                AlertManager.showAllert(title: "Beacon database insertion error", message: error.localizedDescription)
            }
        }
    }
    
    func deleteBeacon(uuid: String, major: Int, minor: Int) {
        let uuid = UUID(uuidString: uuid)!
        
        for (index, beacons) in beaconsCoordinate.enumerated() {
            if beacons.dataAccessor.uuid == uuid && beacons.dataAccessor.major == major && beacons.dataAccessor.minor == minor {
                beaconsCoordinate.remove(at: index)
                
                do {
                    try getContext().save()
                } catch let error as NSError {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        AlertManager.showAllert(title: "Beacon database deletion error", message: error.localizedDescription)
                    }
                }
                
                break
            }
        }
    }
    
    private func getContext() -> NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}
