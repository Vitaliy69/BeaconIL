//
//  AppDelegate.swift
//  iBeacon
//
//  Created by Vitaliy Gribko on 25.02.2021.
//

import UIKit
import CoreData

typealias BeaconDataSource = ScanController.DataSource

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var appSettings: ApplicationSettings!
    
    var dataSource: BeaconDataSource!
    var tableShouldUpdate = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let cloudSync = ApplicationSettings.getCloudSyncState()
        
        let container: NSPersistentContainer!
        if cloudSync {
            container = NSPersistentCloudKitContainer(name: "Beacons")
        } else {
            container = NSPersistentContainer(name: "Beacons")
            
            let description = container.persistentStoreDescriptions.first
            description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                AlertManager.showAllert(title: "Database initialization error", message: error.localizedDescription)
            }
        })
        
        return container
    }()
    
    // MARK: - Core Data Saving Support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                AlertManager.showAllert(title: "Database save error", message: nserror.localizedDescription)
            }
        }
    }
}
