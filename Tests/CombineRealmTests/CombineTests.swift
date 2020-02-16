//
//  CombineTests.swift
//  CombineTests
//
//  Created by István Kreisz on 07/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

@testable import CombineRealm
import RealmSwift
import Combine
import XCTest


class CombineRealmWriteTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    let realm = inMemoryRealm()
    
    override func setUp() {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testAddObject() {
        var results = [String]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(Message.self))
            .map { $0.map { $0.text } }
            .dropFirst()
            .prefix(1)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results = $0
            })
            .store(in: &subscriptions)
        
        Just(Message("1"))
            .addToRealm(configuration: realm.configuration)
            .store(in: &subscriptions)
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], "1")
    }
    
    func testAddSequence() {
        var results = [String]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(Message.self))
            .map { $0.map { $0.text } }
            .dropFirst()
            .prefix(1)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results = $0
            })
            .store(in: &subscriptions)
        
        
        Just([Message("1"), Message("2")])
            .addToRealm(configuration: realm.configuration)
            .store(in: &subscriptions)
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], "1")
        XCTAssertEqual(results[1], "2")
    }
    
    func testAddUpdateObjects() {
        var results = [[Int]]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
            .map { $0.map { $0.id } }
            .dropFirst()
            .prefix(2)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
        
        Just([UniqueObject(1), UniqueObject(2)])
            .addToRealm(configuration: realm.configuration)
            .store(in: &subscriptions)
        Just([UniqueObject(1), UniqueObject(3)])
            .addToRealm(configuration: realm.configuration, updatePolicy: .all)
            .store(in: &subscriptions)
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], [1, 2])
        XCTAssertEqual(results[1], [1, 2, 3])
    }
    
    func testDeleteItem() {
        var results = [[Int]]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
            .map { $0.map { $0.id } }
            .dropFirst()
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
        
        let object1 = UniqueObject(1)
        let object2 = UniqueObject(2)
        try! realm.write {
            realm.add([object1, object2])
        }
        
        Just(object1)
            .deleteFromRealm()
            .store(in: &subscriptions)
        Just(object2)
            .deleteFromRealm()
            .store(in: &subscriptions)
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], [1, 2])
        XCTAssertEqual(results[1], [2])
        XCTAssertEqual(results[2], [])
    }
    
    
    func testDeleteItems() {
        var results = [[Int]]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
            .map { $0.map { $0.id } }
            .dropFirst()
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
        
        let object1 = UniqueObject(1)
        let object2 = UniqueObject(2)
        let object3 = UniqueObject(3)
        let object4 = UniqueObject(4)
        
        try! realm.write {
            realm.add([object1, object2, object3, object4])
        }
        
        Just([object1, object2])
            .deleteFromRealm()
            .store(in: &subscriptions)
        
        Just([object3, object4])
            .deleteFromRealm()
            .store(in: &subscriptions)
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], [1, 2, 3, 4])
        XCTAssertEqual(results[1], [3, 4])
        XCTAssertEqual(results[2], [])
    }

    func testAddObjectsFromDifferentThreads() {
        let realmId = UUID().uuidString
        let realm = inMemoryRealm(id: realmId)
        let configuration = realm.configuration

        var results = [Int]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
            .map { $0.map { $0.id } }
            .filter { $0.count == 6 }
            .prefix(1)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results = $0
            })
            .store(in: &subscriptions)
        
        Just(UniqueObject(1))
            .addToRealm(configuration: configuration)
            .store(in: &subscriptions)
    
        // write on background thread
        DispatchQueue.global(qos: .background).sync {
            Just(UniqueObject(2))
                .addToRealm(configuration: configuration)
                .store(in: &self.subscriptions)
        }
    
        // write on main scheduler
        DispatchQueue.global(qos: .background).sync {
            Just(UniqueObject(3))
                .receive(on: DispatchQueue.main)
                .addToRealm(configuration: configuration)
                .store(in: &self.subscriptions)
        }
    
        // write on bg scheduler
        DispatchQueue.main.async {
            Just(UniqueObject(4))
                .receive(on: DispatchQueue.global(qos: .background))
                .addToRealm(configuration: configuration)
                .store(in: &self.subscriptions)
        }
    
        // subscribe on main, write in bg
        DispatchQueue.main.async {
            Just([UniqueObject(5), UniqueObject(6)])
                .receive(on: DispatchQueue.global(qos: .background))
                .addToRealm(configuration: configuration)
                .store(in: &self.subscriptions)
        }
        
        wait(for: [exp], timeout: 0.1)
    
        XCTAssertEqual(results, [1, 2, 3, 4, 5, 6])
    }
}
