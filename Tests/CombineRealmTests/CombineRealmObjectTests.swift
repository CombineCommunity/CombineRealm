//
//  CombineRealmObjectTests.swift
//  CombinTests
//
//  Created by István Kreisz on 08/02/2020.
//  Copyright © 2020 István Kreisz. All rights reserved.
//

@testable import CombineRealm
import RealmSwift
import Combine
import XCTest


class CombineRealmObjectTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    let realm = inMemoryRealm()
    
    override func setUp() {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testObjectChangeNotifications() {
        var results = [String]()
        let exp1 = expectation(description: "")
        let exp2 = expectation(description: "")

        let configuration = realm.configuration
        
        let idValue = 1024
        let object = UniqueObject(idValue)
        
        try! realm.write {
            realm.add(object)
        }
        
        RealmPublishers.from(object: object)
            .map { $0.name }
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    exp2.fulfill()
                }
            }, receiveValue: {
                results.append($0)
                if results.count == 3 {
                    exp1.fulfill()
                }
            })
            .store(in: &subscriptions)
        
        try! realm.write {
            object.name = "test1"
        }
        
        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            try! realm.write {
                realm.objects(UniqueObject.self).filter("id == %@", idValue).first!.name = "test2"
            }
        }
        
        wait(for: [exp1], timeout: 0.1)

        XCTAssertEqual(results, ["", "test1", "test2"])
        
        try! realm.write {
            realm.delete(object)
        }
        
        wait(for: [exp2], timeout: 0.1)
    }

    func testObjectEmitsInitialChange() {
        var result = false
        let exp = expectation(description: "")
        
        let object = UniqueObject(1024)
        try! realm.write {
            realm.add(object)
        }
        
        RealmPublishers.from(object: object, emitInitialValue: true)
            .prefix(1)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: { _ in
                result = true
            })
            .store(in: &subscriptions)

        wait(for: [exp], timeout: 0.1)
        
        XCTAssert(result)
    }

    func testObjectDoesntEmitInitialValue() {
        var result = false
        let exp = expectation(description: "")
        
        let object = UniqueObject(1024)
        try! realm.write {
            realm.add(object)
        }
        
        RealmPublishers.from(object: object, emitInitialValue: false)
            .prefix(1)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: { _ in
                result = true
            })
            .store(in: &subscriptions)

        _ = XCTWaiter.wait(for: [exp], timeout: 0.1)
        
        XCTAssertFalse(result)
    }

    func testObjectPropertyChangeNotifications() {
        var results = [String]()
        let exp1 = expectation(description: "")
        let exp2 = expectation(description: "")

        let configuration = realm.configuration
        
        let idValue = 1024
        let object = UniqueObject(idValue)
        
        try! realm.write {
            realm.add(object)
        }
        
        RealmPublishers.propertyChanges(object: object)
            .map { "\($0.name):\($0.newValue!)" }
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    exp2.fulfill()
                }
            }, receiveValue: {
                results.append($0)
                if results.count == 2 {
                    exp1.fulfill()
                }
            })
            .store(in: &subscriptions)
        
        try! realm.write {
            object.name = "test1"
        }
        
        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            try! realm.write {
                realm.objects(UniqueObject.self).filter("id == %@", idValue).first!.name = "test2"
            }
        }
        
        wait(for: [exp1], timeout: 0.1)

        XCTAssertEqual(results, ["name:test1", "name:test2"])
        
        try! realm.write {
            realm.delete(object)
        }
        
        wait(for: [exp2], timeout: 0.1)
    }

    func testObjectChangeNotificationsForProperties() {
        var results = [String]()
        let exp1 = expectation(description: "")
        let exp2 = expectation(description: "")

        let configuration = realm.configuration
        
        let idValue = 1024
        let object = UniqueObject(idValue)
        
        try! realm.write {
            realm.add(object)
        }
        
        RealmPublishers.from(object: object, emitInitialValue: false, properties: ["name"])
            .map { "\($0.name)" }
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    exp2.fulfill()
                }
            }, receiveValue: {
                results.append($0)
                if results.count == 2 {
                    exp1.fulfill()
                }
            })
            .store(in: &subscriptions)
        
        try! realm.write {
            object.name = "test1"
        }
        
        DispatchQueue.global(qos: .background).sync {
            let realm = try! Realm(configuration: configuration)
            try! realm.write {
                realm.objects(UniqueObject.self).filter("id == %@", idValue).first!.name = "test2"
            }
        }
        
        wait(for: [exp1], timeout: 0.1)

        XCTAssertEqual(results, ["test1", "test2"])
        
        try! realm.write {
            realm.delete(object)
        }
        
        wait(for: [exp2], timeout: 0.1)
    }
}
