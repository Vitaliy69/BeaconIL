//
//  ApplicationSettings.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 04.03.2021.
//

import UIKit
import Foundation

class ApplicationSettings {
    var uuid: UUID!
    var animateUpdates: Bool!
    var showNames: Bool!
    var cloudSync: Bool!
    var areaSize: Int!
    var calibrationDataSize: Int!
    var emaSize: Int!
    
    static var notificationSettingsChanged = "AppSettingsUpdated"
    static var notificationNewData = "BeaconNewData"
    static var notificationRSSIStart = "RSSIStart"
    static var notificationRSSIStop = "RSSIStop"
    static var notificationBeaconRSSI = "BeaconRSSI"
    
    static private let defaultUUID = "07070707-0405-0607-0809-0A0B0C0D0E00"
    static private let defaultAnimateUpdates = true
    static private let defaultShowNames = true
    static private let defaultCloudSync = true
    static private let defaultAreaSize = 50
    static private let defaultCalibrationDataSize = 30
    static private let defaultEmaSize = 10
    
    static private let uuidId = "UUID"
    static private let animateUpdatesId = "animateUpdates"
    static private let showNamesId = "showNames"
    static private let cloudSyncId = "iCloud"
    static private let areaSizeId = "areaSize"
    static private let defaultCalibrationDataSizeId = "calibrationDataSize"
    static private let emaSizeId = "ema"
    
    static private let imageId = "background"
    
    private let defaults = UserDefaults.standard
    
    init() {
        let uuidString = defaults.string(forKey: ApplicationSettings.uuidId)
        if let uuidString = uuidString {
            uuid = UUID(uuidString: uuidString)!
        } else {
            uuid = UUID(uuidString: ApplicationSettings.defaultUUID)!
            defaults.setValue(ApplicationSettings.defaultUUID, forKey: ApplicationSettings.uuidId)
        }
        
        if defaults.string(forKey: ApplicationSettings.cloudSyncId) == nil {
            cloudSync = ApplicationSettings.defaultCloudSync
            defaults.set(cloudSync, forKey: ApplicationSettings.cloudSyncId)
        } else {
            cloudSync = defaults.bool(forKey: ApplicationSettings.cloudSyncId)
        }
        
        if defaults.string(forKey: ApplicationSettings.animateUpdatesId) == nil {
            animateUpdates = ApplicationSettings.defaultAnimateUpdates
            defaults.set(animateUpdates, forKey: ApplicationSettings.animateUpdatesId)
        } else {
            animateUpdates = defaults.bool(forKey: ApplicationSettings.animateUpdatesId)
        }
        
        if defaults.string(forKey: ApplicationSettings.showNamesId) == nil {
            showNames = ApplicationSettings.defaultShowNames
            defaults.set(showNames, forKey: ApplicationSettings.showNamesId)
        } else {
            showNames = defaults.bool(forKey: ApplicationSettings.showNamesId)
        }
        
        areaSize = defaults.integer(forKey: ApplicationSettings.areaSizeId)
        if areaSize == 0 {
            areaSize = ApplicationSettings.defaultAreaSize
            defaults.setValue(ApplicationSettings.defaultAreaSize, forKey: ApplicationSettings.areaSizeId)
        }
        
        calibrationDataSize = defaults.integer(forKey: ApplicationSettings.defaultCalibrationDataSizeId)
        if calibrationDataSize == 0 {
            calibrationDataSize = ApplicationSettings.defaultCalibrationDataSize
            defaults.setValue(ApplicationSettings.defaultCalibrationDataSize, forKey: ApplicationSettings.defaultCalibrationDataSizeId)
        }
        
        emaSize = defaults.integer(forKey: ApplicationSettings.emaSizeId)
        if emaSize == 0 {
            emaSize = ApplicationSettings.defaultEmaSize
            defaults.setValue(ApplicationSettings.defaultEmaSize, forKey: ApplicationSettings.emaSizeId)
        }
    }
    
    func updateSettings(uuid: String, animateUpdates: Bool, showNames: Bool, cloudSync: Bool, areaSize: Int, calibrationDataSize: Int, emaSize: Int) {
        self.uuid = UUID(uuidString: uuid)!
        defaults.setValue(uuid, forKey: ApplicationSettings.uuidId)
        
        self.animateUpdates = animateUpdates
        defaults.setValue(animateUpdates, forKey: ApplicationSettings.animateUpdatesId)
        
        self.showNames = showNames
        defaults.setValue(showNames, forKey: ApplicationSettings.showNamesId)
        
        self.cloudSync = cloudSync
        defaults.setValue(cloudSync, forKey: ApplicationSettings.cloudSyncId)
        
        self.areaSize = areaSize
        defaults.setValue(areaSize, forKey: ApplicationSettings.areaSizeId)
        
        self.calibrationDataSize = calibrationDataSize
        defaults.setValue(calibrationDataSize, forKey: ApplicationSettings.defaultCalibrationDataSizeId)
        
        self.emaSize = emaSize
        defaults.setValue(emaSize, forKey: ApplicationSettings.emaSizeId)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name.init(ApplicationSettings.notificationSettingsChanged), object: nil)
        }
    }
    
    static func addImage(image: UIImage) {
        UserDefaults.standard.setValue(image.pngData(), forKey: ApplicationSettings.imageId)
    }
    
    static func removeImage() {
        UserDefaults.standard.removeObject(forKey: ApplicationSettings.imageId)
    }
    
    static func getImage() -> UIImage? {
        if let data = UserDefaults.standard.data(forKey: ApplicationSettings.imageId) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    static func getCloudSyncState() -> Bool {
        if UserDefaults.standard.string(forKey: cloudSyncId) == nil {
            return defaultCloudSync
        } else {
            return UserDefaults.standard.bool(forKey: ApplicationSettings.cloudSyncId)
        }
    }
}
