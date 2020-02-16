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


class CombineRealmResultsTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    let realm = inMemoryRealm()
    
    override func setUp() {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testEmittedResultsValues() {
        var results = [[String]]()
        let exp = expectation(description: "")
        
        RealmPublishers.collection(from: realm.objects(Message.self))
            .map { Array($0.map { $0.text }) }
            .dropFirst()
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
        
        let first = addMessage(realm, text: "first(Results)")
        addMessage(realm, text: "second(Results)")
        deleteMessage(realm, message: first)
        
        wait(for: [exp], timeout: 0.1)

        XCTAssertEqual(results[0], ["first(Results)"])
        XCTAssertEqual(results[1], ["first(Results)", "second(Results)"])
        XCTAssertEqual(results[2], ["second(Results)"])
    }

    func testEmittedArrayValues() {
        var results = [[String]]()
        let exp = expectation(description: "")
        
        RealmPublishers.array(from: realm.objects(Message.self))
            .map { $0.map { $0.text } }
            .dropFirst()
            .prefix(3)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
        
        let first = addMessage(realm, text: "first(Results)")
        addMessage(realm, text: "second(Results)")
        deleteMessage(realm, message: first)
        
        wait(for: [exp], timeout: 0.1)

        XCTAssertEqual(results[0], ["first(Results)"])
        XCTAssertEqual(results[1], ["first(Results)", "second(Results)"])
        XCTAssertEqual(results[2], ["second(Results)"])
    }

    func testEmittedChangeset() {
        var results = [String]()
        let exp = expectation(description: "")
        
        // initial data
        addMessage(realm, text: "first(Changeset)")
        
        RealmPublishers.changeset(from: realm.objects(Message.self).sorted(byKeyPath: "text"))
            .map(stringifyChanges)
            .prefix(4)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
                
        // insert
        addMessage(realm, text: "second(Changeset)")

        // update
        try! realm.write {
            realm.objects(Message.self).filter("text='second(Changeset)'").first!.text = "third(Changeset)"
        }
        
        // coalesced + delete
        try! realm.write {
            realm.add(Message("zzzzz(Changeset)"))
            realm.delete(realm.objects(Message.self).filter("text='first(Changeset)'").first!)
        }
        
        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(results[0], "count:1")
        XCTAssertEqual(results[1], "count:2 inserted:[1] deleted:[] updated:[]")
        XCTAssertEqual(results[2], "count:2 inserted:[] deleted:[] updated:[1]")
        XCTAssertEqual(results[3], "count:2 inserted:[1] deleted:[0] updated:[]")
    }

    func testEmittedArrayChangeset() {
        var changesetResults = [String]()
        var arrayResults = [[String]]()
        let exp = expectation(description: "")
        
        // initial data
        addMessage(realm, text: "first(Changeset)")
        
        RealmPublishers.arrayWithChangeset(from: realm.objects(Message.self).sorted(byKeyPath: "text"))
            .map { (arg) -> (String, [String]) in
                let (result, changes) = arg
                if let changes = changes {
                    return ("count:\(result.count) inserted:\(changes.inserted) deleted:\(changes.deleted) updated:\(changes.updated)", result.map { $0.text })
                } else {
                    return ("count:\(result.count)", result.map { $0.text })
                }
            }
            .prefix(4)
            .sink(receiveCompletion: { _ in
                exp.fulfill()
            }, receiveValue: {
                changesetResults.append($0.0)
                arrayResults.append($0.1)
            })
            .store(in: &subscriptions)
                
        // insert
        addMessage(realm, text: "second(Changeset)")

        // update
        try! realm.write {
            realm.objects(Message.self).filter("text='second(Changeset)'").first!.text = "third(Changeset)"
        }

        // coalesced + delete
        try! realm.write {
            realm.add(Message("zzzzz(Changeset)"))
            realm.delete(realm.objects(Message.self).filter("text='first(Changeset)'").first!)
        }

        wait(for: [exp], timeout: 0.1)
        
        XCTAssertEqual(changesetResults[0], "count:1")
        XCTAssertEqual(changesetResults[1], "count:2 inserted:[1] deleted:[] updated:[]")
        XCTAssertEqual(changesetResults[2], "count:2 inserted:[] deleted:[] updated:[1]")
        XCTAssertEqual(changesetResults[3], "count:2 inserted:[1] deleted:[0] updated:[]")
        
        XCTAssertEqual(arrayResults[0], ["first(Changeset)"])
        XCTAssertEqual(arrayResults[1], ["first(Changeset)", "second(Changeset)"])
        XCTAssertEqual(arrayResults[2], ["first(Changeset)", "third(Changeset)"])
        XCTAssertEqual(arrayResults[3], ["third(Changeset)", "zzzzz(Changeset)"])
    }
}
