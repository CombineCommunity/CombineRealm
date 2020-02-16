//
//  CombineRealmTests.swift
//  CombinTests
//
//  Created by István Kreisz on 08/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

@testable import CombineRealm
import RealmSwift
import Combine
import XCTest


class CombineRealmTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    let realm = inMemoryRealm()
    
    override func setUp() {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testRealmDidChangeNotifications() {
        var results = [Realm.Notification]()
        let exp = expectation(description: "")

        let configuration = realm.configuration
        
        RealmPublishers.from(realm: realm)
            .prefix(2)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0.1)
            })
            .store(in: &subscriptions)
        
        try! realm.write {
            realm.add(Message("first"))
        }

        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            try! realm.write {
                realm.add(Message("second"))
            }
        }
        
        wait(for: [exp], timeout: 0.1)

        XCTAssertEqual(results[0], .didChange)
        XCTAssertEqual(results[1], .didChange)
    }

    func testRealmRefreshRequiredNotifications() {
        let realmId = UUID().uuidString
        let realm = inMemoryRealm(id: realmId, autorefresh: false)
        var results = [Realm.Notification]()
        let exp = expectation(description: "")
        
        RealmPublishers.from(realm: realm)
            .prefix(2)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0.1)
            })
            .store(in: &subscriptions)
        
        try! realm.write {
            realm.add(Message("first"))
        }

        DispatchQueue.global(qos: .background).async {
            let realm = inMemoryRealm(id: realmId)
            try! realm.write {
                realm.add(Message("second"))
            }
        }
        
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(results[0], .didChange)
        XCTAssertEqual(results[1], .refreshRequired)
    }
}
