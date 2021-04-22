//
//  VisualizationObject.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 07.03.2021.
//

import SpriteKit

enum VisualizationObjectType: String {
    case beacon
    case location
    case background
}

class VisualizationObject: SKSpriteNode {
    static let defaultSize = 1.0
    
    static func populate(type: VisualizationObjectType, at point: CGPoint, scale: CGFloat, name: String?) -> [SKNode] {
        var objects = [SKNode]()
        
        let graphics = SKSpriteNode(imageNamed: type.rawValue)
        
        graphics.size = CGSize(width: defaultSize, height: defaultSize)
        graphics.setScale(scale)
        graphics.position = point
        graphics.zPosition = type == .location ? 20 : 10
        
        graphics.name = type.rawValue
        objects.append(graphics)
        
        if let name = name {
            let text = SKLabelNode(text: name)
            
            text.fontSize = 10
            text.fontName = "Avenir-Medium"
            text.fontColor = type == .location ? .red : .blue
            text.horizontalAlignmentMode = .center
            text.verticalAlignmentMode = .bottom
            text.position = CGPoint(x: point.x, y: point.y + scale)
            text.zPosition = type == .location ? 20 : 10

            text.setScale(0.20 * scale)
            
            text.name = type.rawValue
            objects.append(text)
        }
        
        return objects
    }
}
