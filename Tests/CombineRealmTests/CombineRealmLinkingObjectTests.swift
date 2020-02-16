//
//  CombineRealmLinkingObjectTests.swift
//  CombinTests
//
//  Created by István Kreisz on 08/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

@testable import CombineRealm
import Combine
import RealmSwift
import XCTest


class CombineRealmLinkingObjectTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    let realm = inMemoryRealm()
    
    override func setUp() {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testLinkingObjectsType() {
        var results = [Int]()
        let exp = expectation(description: "")
        let configuration = realm.configuration

        let message = Message("first")
        try! realm.write {
            realm.add(message)
        }
        
        RealmPublishers.array(from: message.mentions)
            .map { $0.count }
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)

        let user1 = User("user1")
        user1.lastMessage = message

            try! realm.write {
                realm.add(user1)
            }

        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            let user1 = realm.objects(User.self).first!
            try! realm.write {
                realm.delete(user1)
            }
        }
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], 0)
        XCTAssertEqual(results[1], 1)
        XCTAssertEqual(results[2], 0)
    }

    func testLinkingObjectsTypeChangeset() {
        var results = [String]()
        let exp = expectation(description: "")
        let configuration = realm.configuration

        let message = Message("first")
        try! realm.write {
            realm.add(message)
        }
        
        RealmPublishers.changeset(from: message.mentions)
            .map(stringifyChanges)
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)

        let user1 = User("user1")
        user1.lastMessage = message

            try! realm.write {
                realm.add(user1)
            }

        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            let user1 = realm.objects(User.self).first!
            try! realm.write {
                realm.delete(user1)
            }
        }
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], "count:0")
        XCTAssertEqual(results[1], "count:1 inserted:[0] deleted:[] updated:[]")
        XCTAssertEqual(results[2], "count:0 inserted:[] deleted:[0] updated:[]")
    }
}
