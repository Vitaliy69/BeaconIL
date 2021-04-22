//
//  VisualizationScene.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 07.03.2021.
//

import SpriteKit

class VisualizationScene: SKScene {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override init(size: CGSize) {
        super.init(size: size)
        resize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        resize()
    }
    
    func updateVisualisation(beacons: [BeaconData], locationX: Double?, locationY: Double?, showNames: Bool) {
        for node in children {
            if node.name == VisualizationObjectType.beacon.rawValue {
                node.removeFromParent()
            }
        }
        
        guard beacons.count > 0 else { return }
        let scale = CGFloat(Double(appDelegate.appSettings.areaSize!) / 50.0)
        
        for beacon in beacons.enumerated() {
            for node in VisualizationObject.populate(type: .beacon, at: CGPoint(x: beacon.element.coordinateX, y: beacon.element.coordinateY), scale: scale, name: beacon.element.name) {
                if node as? SKLabelNode == nil {
                    addChild(node)
                } else if showNames {
                    addChild(node)
                }
            }
        }
        
        for node in children {
            if node.name == VisualizationObjectType.location.rawValue {
                node.removeFromParent()
            }
        }
        
        if let locationX = locationX, let locationY = locationY {
            let name = String(format: "%.2f, %.2f", locationX, locationY)
            for node in VisualizationObject.populate(type: .location, at: CGPoint(x: locationX, y: locationY), scale: scale, name: name) {
                addChild(node)
            }
        }
    }
    
    func addBackground(image: UIImage) {
        removeBackground()
        
        let texture = SKTexture(image: image)
        let background = SKSpriteNode(texture: texture)
        
        background.zPosition = 0
        background.size = size
        background.alpha = 0.5
        background.name = VisualizationObjectType.background.rawValue
        
        addChild(background)
    }
    
    func removeBackground() {
        for node in children {
            if node.name == VisualizationObjectType.background.rawValue {
                node.removeFromParent()
            }
        }
    }
    
    func resize() {
        let newSize = CGFloat(Double(appDelegate.appSettings.areaSize) + VisualizationObject.defaultSize + 6.0) * 2
        size = CGSize(width: newSize, height: newSize)
        
        children.forEach({ (node) in
            if node.name != VisualizationObjectType.background.rawValue {
                node.removeFromParent()
            }
            else {
                if let background = node as? SKSpriteNode {
                    background.size = size
                }
            }
        })
    }
}
