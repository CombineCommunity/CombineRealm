//
//  Models.swift
//  CombinTests
//
//  Created by István Kreisz on 08/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

import Foundation
import RealmSwift


// MARK: Message
class Message: Object {
    @objc dynamic var text = ""

    let recipients = List<User>()
    let mentions = LinkingObjects(fromType: User.self, property: "lastMessage")

    convenience init(_ text: String) {
        self.init()
        self.text = text
    }
}

// MARK: User
class User: Object {
    @objc dynamic var name = ""
    @objc dynamic var lastMessage: Message?

    convenience init(_ name: String) {
        self.init()
        self.name = name
    }
}

// MARK: UniqueObject
class UniqueObject: Object {
    @objc dynamic var id = 0
    @objc dynamic var name = ""

    convenience init(_ id: Int) {
        self.init()
        self.id = id
    }

    override class func primaryKey() -> String? {
        return "id"
    }
}
