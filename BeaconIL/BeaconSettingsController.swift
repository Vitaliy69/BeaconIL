//
//  BeaconSettingsController.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 01.03.2021.
//

import UIKit
import CoreLocation

class BeaconSettingsController: UITableViewController {
    
    @IBOutlet weak var editX: UITextField!
    @IBOutlet weak var editY: UITextField!
    @IBOutlet weak var editOnMeterRSSI: UITextField!
    @IBOutlet weak var editName: UITextField!
    @IBOutlet weak var buttonCalibrate: UIButton!
    
    var editXText = "0.0"
    var editYText = "0.0"
    var editOnMeterRSSIText = "-59"
    
    var beaconKnown: BeaconKnown!
    var uuid: UUID!
    var major: Int!
    var minor: Int!
    var name: String!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private let rangeRSSI = (-110)...(-40)
    
    private var valueBeforeCalibration: String?
    private var averageRSSI = 0.0
    private var countRSSI = 0
    private var сalibrationInProgress = false {
        didSet {
            guard сalibrationInProgress == false else { return }
            
            NotificationCenter.default.post(name: NSNotification.Name.init(ApplicationSettings.notificationRSSIStop), object: nil)
            
            if countRSSI >= appDelegate.appSettings.calibrationDataSize {
                editOnMeterRSSI.text = String(Int(averageRSSI))
                showAllert(title: "Calibration complete", message: "The average value is \(Int(averageRSSI))")
            }
            
            editOnMeterRSSI.isEnabled = true
            buttonCalibrate.setTitle("Start calibration", for: .normal)
            
            averageRSSI = 0.0
            countRSSI = 0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editX.text = editXText
        editY.text = editYText
        editOnMeterRSSI.text = editOnMeterRSSIText
        editName.text = name
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tableTapped))
        tap.numberOfTouchesRequired = 1
        tap.numberOfTapsRequired = 1
        tableView.addGestureRecognizer(tap)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init(ApplicationSettings.notificationBeaconRSSI), object: nil, queue: nil, using: { (notification) in
            if let dict = notification.userInfo as NSDictionary? {
                if let data = dict["rssi"] as? CLBeacon {
                    self.countRSSI += 1
                    self.averageRSSI += Double(-data.rssi)
                    
                    if self.countRSSI >= self.appDelegate.appSettings.calibrationDataSize {
                        self.averageRSSI = -self.averageRSSI / Double(self.countRSSI)
                        self.сalibrationInProgress = false
                    } else {
                        DispatchQueue.main.async {
                            self.editOnMeterRSSI.text = String(Int(data.rssi))
                        }
                    }
                }
            }
        })
    }
    
    @objc func tableTapped() {
        tableView.endEditing(true)
    }
    
    @IBAction func buttonCancelTapped(_ sender: UIBarButtonItem) {
        tableView.endEditing(true)
        if !сalibrationInProgress {
            dismiss(animated: true)
        } else {
            calibrationInProgress(saved: false)
        }
    }
    
    @IBAction func buttonSaveTapped(_ sender: UIBarButtonItem) {
        tableView.endEditing(true)
        if validateAndSaveValues() && !сalibrationInProgress {
            dismiss(animated: true)
        } else if сalibrationInProgress {
            calibrationInProgress(saved: true)
        }
    }
    
    @IBAction func editNameChanged(_ sender: UITextField) {
        guard editName.text != nil else { return }
        if editName.text!.count > 12 {
            editName.deleteBackward()
        }
    }
    
    @IBAction func buttonCalibrateTapped(_ sender: UIButton) {
        var alert: UIAlertController
        var alertStyle = UIAlertController.Style.actionSheet
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            alertStyle = UIAlertController.Style.alert
        }
        
        if сalibrationInProgress {
            alert = UIAlertController(title: "Confirm the action", message: "Stop сalibration?", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_) in
                self.сalibrationInProgress = false
                self.editOnMeterRSSI.text = self.valueBeforeCalibration
            }))
        } else {
            alert = UIAlertController(title: "Start сalibration?", message: "Please place your iPhone/iPad at a distance of 1 meter/foot from the Beacon at the same height. Do not close or minimize the application while calibrating and wait until \(self.appDelegate.appSettings.calibrationDataSize!) values received.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_) in
                self.сalibrationInProgress = true
                self.editOnMeterRSSI.isEnabled = false
                self.buttonCalibrate.setTitle("Stop calibration", for: .normal)
                self.valueBeforeCalibration = self.editOnMeterRSSI.text
                
                let beacon = BeaconData(rssi: 0, major: self.major, minor: self.minor, coordinateX: 0.0, coordinateY: 0.0, distance: 0.0, imageName: "", lastUpdateTime: Date(), onMeterRSSI: 0, name: "")
                NotificationCenter.default.post(name: NSNotification.Name.init(ApplicationSettings.notificationRSSIStart), object: nil, userInfo: ["calibrate": beacon])
            }))
        }
        
        alert.addAction(UIAlertAction(title: "No", style: .destructive))
        self.present(alert, animated: true)
    }
    
    private func calibrationInProgress(saved: Bool) {
        var alertStyle = UIAlertController.Style.actionSheet
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            alertStyle = UIAlertController.Style.alert
        }
        
        let alert = UIAlertController(title: "Calibration in the progress", message: "Stop сalibration?", preferredStyle: alertStyle)
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_) in
            self.сalibrationInProgress = false
            
            if saved {
                self.editOnMeterRSSI.text = self.valueBeforeCalibration
                if self.validateAndSaveValues() {
                    self.dismiss(animated: true)
                }
            } else {
                self.dismiss(animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "No", style: .destructive))
        
        self.present(alert, animated: true)
    }
    
    private func validateAndSaveValues() -> Bool {
        if editX.text != nil && editY.text != nil && editOnMeterRSSI.text != nil {
            let valueXY = appDelegate.appSettings.areaSize!
            if let x = Double(editX.text!), let y = Double(editY.text!), let rssi = Int(editOnMeterRSSI.text!) {
                if abs(Int32(x)) <= valueXY && abs(Int32(y)) <= valueXY && rangeRSSI ~= rssi {
                    beaconKnown.addBeacon(uuid: self.uuid, major: self.major, minor: self.minor, coordinates: (x, y), onMeterRSSI: rssi, name: editName.text)
                } else {
                    showAllert(title: "Save error", message: "Wrong format: coordinates must be in the range of -\(valueXY)...\(valueXY), RSSI \(rangeRSSI.max()!)...\(rangeRSSI.min()!)")
                    return false
                }
            } else {
                showAllert(title: "Save error", message: "One of the field is not a numeric format or empty")
                return false
            }
        } else {
            showAllert(title: "Save error", message: "One of the field is empty")
            return false
        }
        
        return true
    }
    
    private func showAllert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        
        alert.addAction(action)
        
        present(alert, animated: false)
    }
}
