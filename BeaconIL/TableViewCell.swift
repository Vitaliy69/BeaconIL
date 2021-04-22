//
//  TableViewCell.swift
//  iBeacon
//
//  Created by Vitaliy Gribko on 25.02.2021.
//

import UIKit

class TableViewCell: UITableViewCell {
    
    @IBOutlet weak var labelMajor: UILabel!
    @IBOutlet weak var labelMinor: UILabel!
    @IBOutlet weak var labelRSSI: UILabel!
    @IBOutlet weak var labelX: UILabel!
    @IBOutlet weak var labelY: UILabel!
    @IBOutlet weak var labelDistance: UILabel!
    
    @IBOutlet weak var imageSignal: UIImageView!
    
    var lastUpdateTime: Date!
    var onMeterRSSI: Int!
    var name: String!
    
    var major = 0 {
        didSet {
            labelMajor.text = String("Major: \(major)")
        }
    }
    
    var minor = 0 {
        didSet {
            labelMinor.text = String("Minor: \(minor)")
        }
    }
    
    var valueX = 0.0 {
        didSet {
            labelX.text = String(format: "X: %.2fm", valueX)
        }
    }
    
    var valueY = 0.0 {
        didSet {
            labelY.text = String(format: "Y: %.2fm", valueY)
        }
    }
}
