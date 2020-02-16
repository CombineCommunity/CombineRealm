//
//  Models.swift
//  Example
//
//  Created by István Kreisz on 06/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

import UIKit
import RealmSwift

let formatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .long
    return f
}()

class Color: Object {
    @objc dynamic var time: TimeInterval = Date().timeIntervalSinceReferenceDate
    @objc dynamic var colorR = Double.random(in: 0...1.0)
    @objc dynamic var colorG = Double.random(in: 0...1.0)
    @objc dynamic var colorB = Double.random(in: 0...1.0)
    
    var color: UIColor {
        return UIColor(red: CGFloat(colorR), green: CGFloat(colorG), blue: CGFloat(colorB), alpha: 1.0)
    }
}

class TickCounter: Object {
    @objc dynamic var id = UUID().uuidString
    @objc dynamic var ticks: Int = 0
    override static func primaryKey() -> String? { return "id" }
}
