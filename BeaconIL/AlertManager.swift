//
//  AlertManager.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 03.03.2021.
//

import UIKit

class AlertManager {
    static func showAllert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        
        alert.addAction(action)
        
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
    }
}
