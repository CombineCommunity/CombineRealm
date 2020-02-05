//
//  Yo.swift
//  CombineRealm_Test
//
//  Created by István Kreisz on 04/02/2020.
//  Copyright © 2020 István Kreisz. All rights reserved.
//

import Foundation
import Combine
import RealmSwift


class Delete<Input, Failure: Error>: Subscriber, Cancellable {
        
    public let combineIdentifier = CombineIdentifier()
    
    private let realm: Realm?
    
    private let onError: ((Swift.Error) -> Void)?
    private var subscription: Subscription?
    
    init(realm: Realm?, onError: ((Swift.Error) -> Void)?) {
        self.realm = realm
        self.onError = onError
    }
    
    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(.unlimited)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            let realm = try self.realm ?? Realm()
            try realm.write { [weak self] in
                self?.deleteFromRealm(realm, input: input)
            }
        } catch let error {
            onError?(error)
        }
        return .unlimited
    }
    
    func deleteFromRealm(_ realm: Realm, input: Input) {
        preconditionFailure("Subclasses must override this method")
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        subscription = nil
    }
    
    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}

final class DeleteOne<Input: Object, Failure: Error>: Delete<Input, Failure> {
    override func deleteFromRealm(_ realm: Realm, input: Input) {
        realm.delete(input)
    }
}

final class DeleteMany<Input: Sequence, Failure: Error>: Delete<Input, Failure> where Input.Iterator.Element: Object {
    override func deleteFromRealm(_ realm: Realm, input: Input) {
        realm.delete(input)
    }
}

public extension Publisher where Output: Object, Failure: Error {
    
    /**
     Subscribes publisher to subscriber which deletes objects from a Realm. The objects are deleted from the default realm instance `Realm()`.

     - returns: `AnyCancellable`
     */
    func deleteFromRealm() -> AnyCancellable {
        return deleteFromRealm(nil)
    }
    
    /**
     Subscribes publisher to subscriber which deletes objects from a Realm.

     - parameter realm - realm instance which contains the deletable objects (defaults to `Realm()` if not specified)
     - returns: `AnyCancellable`
     */
    func deleteFromRealm(_ realm: Realm) -> AnyCancellable {
        return deleteFromRealm(realm, onError: nil)
    }
    
    /**
     Subscribes publisher to subscriber which deletes objects from a Realm.

     - parameter realm - realm instance which contains the deletable objects (defaults to `Realm()` if not specified)
     - parameter onError - closure to implement custom error handling
     - returns: `AnyCancellable`
     */
    func deleteFromRealm(_ realm: Realm? = nil, onError: ((Swift.Error) -> Void)? = nil) -> AnyCancellable {
        let subscriber = DeleteOne<Output, Failure>(realm: realm, onError: onError)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}

public extension Publisher where Output: Sequence, Failure: Error, Output.Iterator.Element: Object {
    
    /**
     Subscribes publisher to subscriber which deletes objects from a Realm. The objects are deleted from the default realm instance `Realm()`.

     - returns: `AnyCancellable`
     */
    func deleteFromRealm() -> AnyCancellable {
        return deleteFromRealm(nil)
    }
    
    /**
     Subscribes publisher to subscriber which deletes objects from a Realm.

     - parameter realm - realm instance which contains the deletable objects (defaults to `Realm()` if not specified)
     - returns: `AnyCancellable`
     */
    func deleteFromRealm(_ realm: Realm) -> AnyCancellable {
        return deleteFromRealm(realm, onError: nil)
    }
    
    /**
     Subscribes publisher to subscriber which deletes objects from a Realm.

     - parameter realm - realm instance which contains the deletable objects (defaults to `Realm()` if not specified)
     - parameter onError - closure to implement custom error handling
     - returns: `AnyCancellable`
     */
    func deleteFromRealm(_ realm: Realm? = nil, onError: ((Swift.Error) -> Void)? = nil) -> AnyCancellable {
        let subscriber = DeleteMany<Output, Failure>(realm: realm, onError: onError)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
