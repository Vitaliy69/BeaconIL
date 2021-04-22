//
//  ViewController.swift
//  iBeacon
//
//  Created by Vitaliy Gribko on 25.02.2021.
//

import UIKit
import SpriteKit
import CoreLocation
import CoreBluetooth

class ScanController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var visualizationView: SKView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var visualizationScene: VisualizationScene!
    private var beaconKnown: BeaconKnown!
    private var beaconScan: BeaconScan!
    private var indoorMath: IndoorMath!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        appDelegate.appSettings = ApplicationSettings()
        appDelegate.dataSource = DataSource(tableView: tableView, cellProvider: { (tableView, indexPath, beaconData) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
            cell.major = beaconData.major
            cell.minor = beaconData.minor
            
            cell.labelRSSI.text = String("RSSI: \(beaconData.rssi)dBm")
            
            cell.valueX = beaconData.coordinateX
            cell.valueY = beaconData.coordinateY
            
            cell.labelDistance.text = String(format: "D: %.2fm", beaconData.distance)
            
            cell.imageSignal.image = UIImage(named: beaconData.imageName)
            
            cell.lastUpdateTime = beaconData.lastUpdateTime
            cell.onMeterRSSI = beaconData.onMeterRSSI
            cell.name = beaconData.name
            
            cell.accessoryType = .disclosureIndicator
            
            return cell
        })
        
        DispatchQueue.main.async {
            self.appDelegate.dataSource.apply(self.initialSnapshot())
        }
        
        tableView.tableFooterView = UIView()
        
        setupVisualizationView()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init(ApplicationSettings.notificationSettingsChanged), object: nil, queue: nil, using: { (_) in
            self.beaconScan.stopScanning()
            self.indoorMath.setEmaSize(thresholdEma: self.appDelegate.appSettings.emaSize)
            self.visualizationScene.resize()
            self.beaconScan.startScanning()
        })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init(ApplicationSettings.notificationNewData), object: nil, queue: nil, using: { (_) in
            self.calculateLocation()
        })
        
        beaconKnown = BeaconKnown()
        beaconScan = BeaconScan(appSettings: appDelegate.appSettings, beaconKnown: beaconKnown)
        
        indoorMath = IndoorMath(thresholdEma: appDelegate.appSettings.emaSize)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.tableShouldUpdate = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appDelegate.tableShouldUpdate = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "beaconSettings" {
            if let destNC = segue.destination as? UINavigationController {
                if let destVC = destNC.topViewController as? BeaconSettingsController {
                    guard let cell = sender as? TableViewCell else { return }
                    destVC.beaconKnown = beaconKnown
                    destVC.uuid = appDelegate.appSettings.uuid
                    destVC.major = cell.major
                    destVC.minor = cell.minor
                    destVC.editXText = String(format: "%.2f", cell.valueX)
                    destVC.editYText = String(format: "%.2f", cell.valueY)
                    destVC.editOnMeterRSSIText = String(format: "%d", cell.onMeterRSSI)
                    destVC.name = cell.name
                }
            }
        }
    }
    
    private func initialSnapshot() -> NSDiffableDataSourceSnapshot<Section, BeaconData> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, BeaconData>()
        snapshot.appendSections([.main])
        
        return snapshot
    }
    
    private func setupVisualizationView() {
        visualizationScene = VisualizationScene(size: visualizationView.bounds.size)
        
        visualizationScene.backgroundColor = UIColor(red: 0.0, green: 132 / 255, blue: 255 / 255, alpha: 1.0)
        
        visualizationScene.scaleMode = .aspectFill
        visualizationScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        visualizationView.preferredFramesPerSecond = 1
        // visualizationView.showsNodeCount = true
        
        visualizationView.presentScene(visualizationScene)
        
        let tapRecognizer = UITapGestureRecognizer()
        tapRecognizer.addTarget(self, action: #selector(tappedView(_:)))
        tapRecognizer.numberOfTouchesRequired = 1
        tapRecognizer.numberOfTapsRequired = 1
        visualizationView.addGestureRecognizer(tapRecognizer)
        
        if let background = ApplicationSettings.getImage() {
            visualizationScene.addBackground(image: background)
        }
    }
    
    private func calculateLocation() {
        let snapshot = appDelegate.dataSource.snapshot().itemIdentifiers(inSection: .main)
        indoorMath.updateVisibleBeacons(beacons: snapshot)
        let location = indoorMath.getLocation()
        
        visualizationScene.updateVisualisation(beacons: snapshot, locationX: location.0, locationY: location.1, showNames: appDelegate.appSettings.showNames)
    }
    
    @objc func tappedView(_ sender: UITapGestureRecognizer) {
        let setBackground = UIAlertAction(title: "Add background", style: .default) { _ in
            self.chooseImagePicker(source: .photoLibrary)
        }
        
        let removeBackground = UIAlertAction(title: "Remove background", style: .destructive) { _ in
            self.visualizationScene.removeBackground()
            ApplicationSettings.removeImage()
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        
        let setIcon = UIImage(systemName: "photo")
        setBackground.setValue(setIcon, forKey: "image")
        setBackground.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        
        let removeIcon = UIImage(systemName: "minus.circle")
        removeBackground.setValue(removeIcon, forKey: "image")
        removeBackground.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        
        var alertStyle = UIAlertController.Style.actionSheet
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            alertStyle = UIAlertController.Style.alert
        }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)
        actionSheet.addAction(setBackground)
        actionSheet.addAction(removeBackground)
        actionSheet.addAction(cancel)
        
        present(actionSheet, animated: true)
    }
}

// MARK: - Data Source
extension ScanController {
    class DataSource: UITableViewDiffableDataSource<Section, BeaconData> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            return Section(rawValue: section)?.description()
        }
        
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            return false
        }
    }
}

// MARK: - Work With Image

extension ScanController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func chooseImagePicker(source: UIImagePickerController.SourceType) {
        if UIImagePickerController.isSourceTypeAvailable(source) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            imagePicker.sourceType = source
            present(imagePicker, animated: true)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let backgroundImage = info[.editedImage] as? UIImage {
            visualizationScene.addBackground(image: backgroundImage)
            ApplicationSettings.addImage(image: backgroundImage)
        }
        
        dismiss(animated: true)
    }
}
