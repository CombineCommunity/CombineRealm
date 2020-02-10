//
//  CombineRealmListTests.swift
//  CombinTests
//
//  Created by István Kreisz on 08/02/2020.
//  Copyright © 2020 István Kreisz. All rights reserved.
//

@testable import CombineRealm
import Combine
import RealmSwift
import XCTest


class CombineRealmListTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    let realm = inMemoryRealm()
    
    override func setUp() {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testListType() {
        var results = [Int]()
        let exp = expectation(description: "")
        let configuration = realm.configuration

        let message = Message("first")
        try! realm.write {
            realm.add(message)
        }
        
        RealmPublishers.array(from: message.recipients)
            .map { $0.count }
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)

        try! realm.write {
            message.recipients.append(User("user1"))
        }

        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            let message = realm.objects(Message.self).first!
            try! realm.write {
                message.recipients.remove(at: 0)
            }
        }
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], 0)
        XCTAssertEqual(results[1], 1)
        XCTAssertEqual(results[2], 0)
    }

    func testListTypeChangeset() {
        var results = [String]()
        let exp = expectation(description: "")
        let configuration = realm.configuration

        let message = Message("first")
        try! realm.write {
            realm.add(message)
        }

        RealmPublishers.changeset(from: message.recipients)
            .map(stringifyChanges)
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)

        try! realm.write {
            message.recipients.append(User("user1"))
        }
        
        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            let message = realm.objects(Message.self).first!
            try! realm.write {
                message.recipients.remove(at: 0)
            }
        }
        
        wait(for: [exp], timeout: 0.1)

        XCTAssertEqual(results[0], "count:0")
        XCTAssertEqual(results[1], "count:1 inserted:[0] deleted:[] updated:[]")
        XCTAssertEqual(results[2], "count:0 inserted:[] deleted:[0] updated:[]")
    }
}
