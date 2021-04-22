//
//  SettingsViewController.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 01.03.2021.
//

import UIKit

class SettingsViewController: UITableViewController, UITabBarControllerDelegate {
    
    @IBOutlet weak var editUUID: UITextField!
    @IBOutlet weak var editAreaSize: UITextField!
    @IBOutlet weak var editCalibrationDataSize: UITextField!
    @IBOutlet weak var editEmaSize: UITextField!
    
    @IBOutlet weak var switchAnimate: UISwitch!
    @IBOutlet weak var switchShowNames: UISwitch!
    @IBOutlet weak var switchSync: UISwitch!
    
    private var hasChanges = false
    private let areaSizeRange = 10...200
    private let calibrationDataSizeRange = 10...150
    private let emaSizeRange = 5...100
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        
        loadSettings()
        
        tabBarController?.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tableTapped))
        tap.numberOfTouchesRequired = 1
        tap.numberOfTapsRequired = 1
        tableView.addGestureRecognizer(tap)
    }
    
    @objc func tableTapped() {
        tableView.endEditing(true)
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if viewController is SettingsViewController {
            loadSettings()
        }
        
        if viewController is ScanController {
            tableView.endEditing(true)
            
            if hasChanges && validateValues(silence: true) {
                tabBarController.selectedIndex = 1
                
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                    alertStyle = UIAlertController.Style.alert
                }
                
                let alert = UIAlertController(title: "Сhanges found", message: "Save?", preferredStyle: alertStyle)
                
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_) in
                    self.saveSettings()
                    self.tabBarController?.selectedIndex = 0
                }))
                alert.addAction(UIAlertAction(title: "No", style: .destructive, handler: { (_) in
                    self.loadSettings()
                    self.tabBarController?.selectedIndex = 0
                }))
                
                self.present(alert, animated: true)
            }
        }
    }
    
    @IBAction func buttonSaveTapped(_ sender: UIBarButtonItem) {
        if validateValues(silence: false) {
            saveSettings()
        }
    }
    
    @IBAction func swithSyncChanged(_ sender: UISwitch) {
        hasChanges = true
        if sender.tag == 10 {
            showMessage(title: "Warning", message: "Restart required to apply iCloud synchronization setting")
        }
    }
    
    @IBAction func editingChanged(_ sender: UITextField) {
        hasChanges = true
    }
    
    private func loadSettings() {
        hasChanges = false
        
        editUUID.text = appDelegate.appSettings.uuid.uuidString
        switchAnimate.isOn = appDelegate.appSettings.animateUpdates
        switchShowNames.isOn = appDelegate.appSettings.showNames
        switchSync.isOn = appDelegate.appSettings.cloudSync
        editAreaSize.text = String(appDelegate.appSettings.areaSize)
        editCalibrationDataSize.text = String(appDelegate.appSettings.calibrationDataSize)
        editEmaSize.text = String(appDelegate.appSettings.emaSize)
    }
    
    private func validateValues(silence: Bool) -> Bool {
        if editUUID.text != nil && editEmaSize.text != nil {
            let uuid = UUID(uuidString: editUUID.text!)
            if uuid == nil {
                if !silence {
                    showMessage(title: "Format error", message: "UUID should be in the heximal format 12345678-1234-1234-1234-1234567890AB")
                }
                return false
            }
            
            if let areaSize = Int(editAreaSize.text!) {
                if !areaSizeRange.contains(areaSize) {
                    if !silence {
                        showMessage(title: "Format error", message: "View Area Size must be in the range of \(areaSizeRange.min()!)...\(areaSizeRange.max()!)")
                    }
                    return false
                }
            } else {
                if !silence {
                    showMessage(title: "Format error", message: "View Area Size must be an integer number")
                }
                return false
            }
            
            if let calibrationDataSize = Int(editCalibrationDataSize.text!) {
                if !calibrationDataSizeRange.contains(calibrationDataSize) {
                    if !silence {
                        showMessage(title: "Format error", message: "Calibration Data Size must be in the range of \(calibrationDataSizeRange.min()!)...\(calibrationDataSizeRange.max()!)")
                    }
                    return false
                }
            } else {
                if !silence {
                    showMessage(title: "Format error", message: "Calibration Data Size must be an integer number")
                }
                return false
            }
            
            if let emaSize = Int(editEmaSize.text!) {
                if !emaSizeRange.contains(emaSize) {
                    if !silence {
                        showMessage(title: "Format error", message: "EMA Filter Size must be in the range of \(emaSizeRange.min()!)...\(emaSizeRange.max()!)")
                    }
                    return false
                }
            } else {
                if !silence {
                    showMessage(title: "Format error", message: "EMA Filter Size must be an integer number")
                }
                return false
            }
        } else {
            showMessage(title: "Format error", message: "One of the field is empty")
            return false
        }
        
        return true
    }
    
    private func saveSettings() {
        tableView.endEditing(true)
        appDelegate.appSettings.updateSettings(uuid: editUUID.text!, animateUpdates: switchAnimate.isOn, showNames: switchShowNames.isOn, cloudSync: switchSync.isOn, areaSize: Int(editAreaSize.text!)!, calibrationDataSize: Int(editCalibrationDataSize.text!)!, emaSize: Int(editEmaSize.text!)!)
        
        hasChanges = false
        showMessage(title: "Saved", message: " Settings changes applied")
    }
    
    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        
        alert.addAction(action)
        
        present(alert, animated: false)
    }
}
