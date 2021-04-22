//
//  Beacons+CoreDataProperties.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 06.03.2021.
//
//

import Foundation
import CoreData


extension Beacons {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Beacons> {
        return NSFetchRequest<Beacons>(entityName: "Beacons")
    }
    
    @NSManaged public var data: String?
    
    var dataAccessor: BeaconCoordinates {
        get {
            return (try? JSONDecoder().decode(BeaconCoordinates.self, from: Data(data!.utf8)))!
        }
        set {
            do {
                let coordinatesData = try JSONEncoder().encode(newValue)
                data = String(data: coordinatesData, encoding: .utf8)!
            } catch {
                data = ""
            }
        }
    }
    
}

extension Beacons : Identifiable {
    
}
