//
//  Models.swift
//  CombineTests
//
//  Created by István Kreisz on 07/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

@testable import CombineRealm
import RealmSwift
import Foundation


enum WriteError: Error {
    case def
}

func inMemoryRealm(id: String = UUID().uuidString, autorefresh: Bool = true) -> Realm {
    var conf = Realm.Configuration()
    conf.inMemoryIdentifier = id
    let realm = try! Realm(configuration: conf)
    realm.autorefresh = autorefresh
    return realm
}

func stringifyChanges<E>(_ arg: (AnyRealmCollection<E>, RealmChangeset?)) -> String {
    let (result, changes) = arg
    if let changes = changes {
        return "count:\(result.count) inserted:\(changes.inserted) deleted:\(changes.deleted) updated:\(changes.updated)"
    } else {
        return "count:\(result.count)"
    }
}

@discardableResult func addMessage(_ realm: Realm, text: String) -> Message {
    let message = Message(text)
    try! realm.write {
        realm.add(message)
    }
    return message
}

func deleteMessage(_ realm: Realm, message: Message) {
    try! realm.write {
        realm.delete(message)
    }
}
