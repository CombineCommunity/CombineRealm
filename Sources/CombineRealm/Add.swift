//
//  Add.swift
//  CombineRealm_Test
//
//  Created by István Kreisz on 05/02/2020.
//  Copyright © 2020 István Kreisz. All rights reserved.
//

import Foundation
import Combine
import RealmSwift


class Add<Input, Failure: Error>: Subscriber, Cancellable {
        
    public let combineIdentifier = CombineIdentifier()
    
    private let realm: Realm?
    
    private let updatePolicy: Realm.UpdatePolicy
    private let onError: ((Swift.Error) -> Void)?
    private var subscription: Subscription?
    
    init(realm: Realm?, updatePolicy: Realm.UpdatePolicy, onError: ((Swift.Error) -> Void)?) {
        self.realm = realm
        self.updatePolicy = updatePolicy
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
                guard let self = self else { return }
                self.addToRealm(realm, input: input, updatePolicy: self.updatePolicy)
            }
        } catch let error {
            onError?(error)
        }
        return .unlimited
    }
    
    func addToRealm(_ realm: Realm, input: Input, updatePolicy: Realm.UpdatePolicy) {
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

final class AddOne<Input: Object, Failure: Error>: Add<Input, Failure> {
    override func addToRealm(_ realm: Realm, input: Input, updatePolicy: Realm.UpdatePolicy) {
        realm.add(input, update: updatePolicy)
    }
}

final class AddMany<Input: Sequence, Failure: Error>: Add<Input, Failure> where Input.Iterator.Element: Object {
    override func addToRealm(_ realm: Realm, input: Input, updatePolicy: Realm.UpdatePolicy) {
        realm.add(input, update: updatePolicy)
    }
}

public extension Publisher where Output: Object, Failure: Error {
    
    /**
     Subscribes publisher to subscriber which adds objects to a Realm. The objects are added to the default realm instance `Realm()`.

     - returns: `AnyCancellable`
     */
    func addToRealm() -> AnyCancellable {
        return addToRealm(nil)
    }
    
    /**
     Subscribes publisher to subscriber which adds objects to a Realm.

     - parameter realm - realm instance which the objects will be added to (defaults to `Realm()` if not specified)
     - returns: `AnyCancellable`
     */
    func addToRealm(_ realm: Realm) -> AnyCancellable {
        return addToRealm(realm, updatePolicy: .error)
    }
        
    /**
     Subscribes publisher to subscriber which adds objects to a Realm.

     - parameter realm - realm instance which the objects will be added to (defaults to `Realm()` if not specified)
     - parameter updatePolicy - update according to `Realm.UpdatePolicy`
     - parameter onError - closure to implement custom error handling
     - returns: `AnyCancellable` 
     */
    func addToRealm(_ realm: Realm? = nil, updatePolicy: Realm.UpdatePolicy = .error, onError: ((Swift.Error) -> Void)? = nil) -> AnyCancellable {
        let subscriber = AddOne<Output, Failure>(realm: realm, updatePolicy: updatePolicy, onError: onError)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}

public extension Publisher where Output: Sequence, Failure: Error, Output.Iterator.Element: Object {
    
    /**
     Subscribes publisher to subscriber which adds objects in sequence to a Realm. The objects are added to the default realm instance `Realm()`.

     - returns: `AnyCancellable`
     */
    func addToRealm() -> AnyCancellable {
        return addToRealm(nil)
    }
    
    /**
     Subscribes publisher to subscriber which adds objects in sequence to a Realm.

     - parameter realm - realm instance which the objects will be added to (defaults to `Realm()` if not specified)
     - returns: `AnyCancellable`
     */
    func addToRealm(_ realm: Realm) -> AnyCancellable {
        return addToRealm(realm, updatePolicy: .error)
    }
    
    /**
     Subscribes publisher to subscriber which adds objects in sequence to a Realm.

     - parameter realm - realm instance which the objects will be added to (defaults to `Realm()` if not specified)
     - parameter updatePolicy - update according to `Realm.UpdatePolicy`
     - parameter onError - closure to implement custom error handling
     - returns: `AnyCancellable`
     */
    func addToRealm(_ realm: Realm?, updatePolicy: Realm.UpdatePolicy = .error, onError: ((Swift.Error) -> Void)? = nil) -> AnyCancellable {
        let subscriber = AddMany<Output, Failure>(realm: realm, updatePolicy: updatePolicy, onError: onError)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
