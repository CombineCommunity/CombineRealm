//
//  Add.swift
//  CombineRealm
//
//  Created by István Kreisz on 05/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

import Foundation
import Combine
import RealmSwift


class Add<Input, Failure: Error>: Subscriber, Cancellable {
        
    public let combineIdentifier = CombineIdentifier()
    
    private let configuration: Realm.Configuration
    
    private let updatePolicy: Realm.UpdatePolicy
    private let onError: ((Swift.Error) -> Void)?
    private var subscription: Subscription?
    
    init(configuration: Realm.Configuration, updatePolicy: Realm.UpdatePolicy, onError: ((Swift.Error) -> Void)?) {
        self.configuration = configuration
        self.updatePolicy = updatePolicy
        self.onError = onError
    }
    
    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(.unlimited)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            let realm = try Realm(configuration: configuration)
            try realm.write {
                addToRealm(realm, input: input, updatePolicy: updatePolicy)
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
        return addToRealm(configuration: .defaultConfiguration)
    }
    
    /**
     Subscribes publisher to subscriber which adds objects to a Realm.

     - parameter configuration (by default uses `Realm.Configuration.defaultConfiguration`) to use to get a Realm for the write operations
     - returns: `AnyCancellable`
     */
    func addToRealm(configuration: Realm.Configuration = .defaultConfiguration) -> AnyCancellable {
        return addToRealm(configuration: configuration, updatePolicy: .error)
    }
        
    /**
     Subscribes publisher to subscriber which adds objects to a Realm.

     - parameter configuration (by default uses `Realm.Configuration.defaultConfiguration`) to use to get a Realm for the write operations
     - parameter updatePolicy - update according to `Realm.UpdatePolicy`
     - parameter onError - closure to implement custom error handling
     - returns: `AnyCancellable`
     */
    func addToRealm(configuration: Realm.Configuration = .defaultConfiguration, updatePolicy: Realm.UpdatePolicy = .error, onError: ((Swift.Error) -> Void)? = nil) -> AnyCancellable {
        let subscriber = AddOne<Output, Failure>(configuration: configuration, updatePolicy: updatePolicy, onError: onError)
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
        return addToRealm(configuration: .defaultConfiguration)
    }
    
    /**
     Subscribes publisher to subscriber which adds objects in sequence to a Realm.

     - parameter configuration (by default uses `Realm.Configuration.defaultConfiguration`) to use to get a Realm for the write operations
     - returns: `AnyCancellable`
     */
    func addToRealm(configuration: Realm.Configuration = .defaultConfiguration) -> AnyCancellable {
        return addToRealm(configuration: configuration, updatePolicy: .error)
    }

    /**
     Subscribes publisher to subscriber which adds objects in sequence to a Realm.

     - parameter configuration (by default uses `Realm.Configuration.defaultConfiguration`) to use to get a Realm for the write operations
     - parameter updatePolicy - update according to `Realm.UpdatePolicy`
     - parameter onError - closure to implement custom error handling
     - returns: `AnyCancellable`
     */
    func addToRealm(configuration: Realm.Configuration = .defaultConfiguration, updatePolicy: Realm.UpdatePolicy = .error, onError: ((Swift.Error) -> Void)? = nil) -> AnyCancellable {
        let subscriber = AddMany<Output, Failure>(configuration: configuration, updatePolicy: updatePolicy, onError: onError)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
