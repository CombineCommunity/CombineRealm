//
//  CombineRealm.swift
//  CombineRealm
//
//  Created by István Kreisz on 02/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

import Foundation
import Combine
import RealmSwift


public enum CombineRealmError: Error {
    case objectDeleted
    case unknown
}

// MARK: Realm Collections type extensions

/**
 `NotificationEmitter` is a protocol to allow for Realm's collections to be handled in a generic way.
 
 All collections already include a `addNotificationBlock(_:)` method - making them conform to `NotificationEmitter` just makes it easier to add Combine methods to them.
 
 The methods of essence in this protocol are `observe(...)`, which allow for observing for changes on Realm's collections.
 */
public protocol NotificationEmitter {
    associatedtype ElementType: RealmCollectionValue
    
    /**
     Returns a `NotificationToken`, which while retained enables change notifications for the current collection.
     
     - returns: `NotificationToken` - retain this value to keep notifications being emitted for the current collection.
     */
    func observe(on queue: DispatchQueue?, _ block: @escaping (RealmCollectionChange<Self>) -> Void) -> NotificationToken
    
    func toArray() -> [ElementType]
    
    func toAnyCollection() -> AnyRealmCollection<ElementType>
}

extension List: NotificationEmitter {
    
    public func toAnyCollection() -> AnyRealmCollection<Element> {
        return AnyRealmCollection<Element>(self)
    }
        
    public typealias ElementType = Element
    public func toArray() -> [Element] {
        return Array(self)
    }
}

extension AnyRealmCollection: NotificationEmitter {
    public func toAnyCollection() -> AnyRealmCollection<Element> {
        return AnyRealmCollection<ElementType>(self)
    }
    
    public typealias ElementType = Element
    public func toArray() -> [Element] {
        return Array(self)
    }
}

extension Results: NotificationEmitter {
    public func toAnyCollection() -> AnyRealmCollection<Element> {
        return AnyRealmCollection<ElementType>(self)
    }
    
    public typealias ElementType = Element
    public func toArray() -> [Element] {
        return Array(self)
    }
}

extension LinkingObjects: NotificationEmitter {
    public func toAnyCollection() -> AnyRealmCollection<Element> {
        return AnyRealmCollection<ElementType>(self)
    }
    
    public typealias ElementType = Element
    public func toArray() -> [Element] {
        return Array(self)
    }
}

/**
 `RealmChangeset` is a struct that contains the data about a single realm change set.
 
 It includes the insertions, modifications, and deletions indexes in the data set that the current notification is about.
 */
public struct RealmChangeset {
    /// the indexes in the collection that were deleted
    public let deleted: [Int]
    
    /// the indexes in the collection that were inserted
    public let inserted: [Int]
    
    /// the indexes in the collection that were modified
    public let updated: [Int]
}

struct RealmPublisher<Output, Failure: Swift.Error>: Publisher {
    
    public typealias Output = Output
    public typealias Failure = Failure
    
    private let handler: (AnySubscriber<Output, Failure>) -> NotificationToken
    private let initialValue: Output?
    
    init(initialValue: Output? = nil, handler: @escaping (AnySubscriber<Output, Failure>) -> NotificationToken) {
        self.handler = handler
        self.initialValue = initialValue
    }
    
    func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, S.Input == Output {
        subscriber.receive(subscription: RealmSubscription<Output, Failure>(subscriber: subscriber, initialValue: initialValue, handler: handler))
    }
}
    
final class RealmSubscription<Output, Failure: Error>: Subscription {
    
    private var subscriber: AnySubscriber<Output, Failure>?
    private var token: NotificationToken?
    private var handler: (AnySubscriber<Output, Failure>) -> NotificationToken
    private var initialValue: Output?
    
    init<S>(subscriber: S, initialValue: Output?, handler: @escaping (AnySubscriber<Output, Failure>) -> NotificationToken)
        where S: Subscriber,
        Failure == S.Failure,
        Output == S.Input {
            self.subscriber = AnySubscriber(subscriber)
            self.initialValue = initialValue
            self.handler = handler
    }
    
    func request(_ demand: Subscribers.Demand) {
        if let subscriber = subscriber, token == nil {
            token = handler(subscriber)
            if let initialValue = initialValue {
                _ = subscriber.receive(initialValue)
            }
        }
    }
    
    func cancel() {
        token?.invalidate()
        subscriber = nil
    }
}

public enum RealmPublishers {
    
    /**
     Returns an `AnyPublisher<Output, Error>` that emits each time the collection data changes.
     The publisher emits an initial value upon subscription.
     
     - parameter from: A Realm collection of type `Output`: either `Results`, `List`, `LinkingObjects` or `AnyRealmCollection`.
     - parameter synchronousStart: whether the resulting `Publisher` should emit its first element synchronously (e.g. better for UI bindings)
     
     - returns: `AnyPublisher<Output, Error>`, e.g. when called on `Results<Model>` it will return `AnyPublisher<Results<Model>, Error>`, on a `List<User>` it will return `AnyPublisher<List<User>, Error>`, etc.
     */
    public static func collection<Output: NotificationEmitter>(from collection: Output,
                                                               synchronousStart: Bool = true)
        -> AnyPublisher<Output, Error> {
            
            let initialValue: Output? = synchronousStart ? collection : nil
            return RealmPublisher<Output, Error>(initialValue: initialValue) { subscriber in
                return collection.observe(on: nil) { changeset in
                    let value: Output
                
                    switch changeset {
                    case let .initial(latestValue):
                        guard !synchronousStart else { return }
                        value = latestValue
                    case .update(let latestValue, _, _, _):
                        value = latestValue
                    case let .error(error):
                        subscriber.receive(completion: .failure(error))
                        return
                }
                    _ = subscriber.receive(value)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Returns an `AnyPublisher<Array<Output.ElementType>, Error>` that emits each time the collection data changes. The publisher emits an initial value upon subscription.
     The result emits an array containing all objects from the source collection.
     
     This method emits an `Array` containing all the realm collection objects, this means they all live in the memory. If you're using this method to observe large collections you might hit memory warnings.
     
     - parameter from: A Realm collection of type `Output`: either `Results`, `List`, `LinkingObjects` or `AnyRealmCollection`.
     - parameter synchronousStart: whether the resulting `Publisher` should emit its first element synchronously (e.g. better for UI bindings)
     
     - returns: `AnyPublisher<Array<Output.ElementType>, Error>`, e.g. when called on `Results<Model>` it will return `AnyPublisher<Array<Model>, Error>`, on a `List<User>` it will return `AnyPublisher<Array<User>, Error>`, etc.
     */
    public static func array<Output: NotificationEmitter>(from collection: Output,
                                                   synchronousStart: Bool = true)
        -> AnyPublisher<[Output.ElementType], Error> {
            
            return RealmPublishers.collection(from: collection, synchronousStart: synchronousStart)
            .map { $0.toArray() }
            .eraseToAnyPublisher()
    }
    
    /**
     Returns an `AnyPublisher<(Output, RealmChangeset?), Error>` that emits each time the collection data changes. The publisher emits an initial value upon subscription.
     
     When the publisher emits for the first time (if the initial notification is not coalesced with an update) the second tuple value will be `nil`.
     
     Each following emit will include a `RealmChangeset` with the indexes inserted, deleted or modified.
     
     - parameter from: A Realm collection of type `Output`: either `Results`, `List`, `LinkingObjects` or `AnyRealmCollection`.
     - parameter synchronousStart: whether the resulting `Publisher` should emit its first element synchronously (e.g. better for UI bindings)
     
     - returns: `AnyPublisher<(Output, RealmChangeset?), Error>`, e.g. when called on `Results<Model>` it will return `AnyPublisher<(Results<Model>, RealmChangeset?), Error>`, on a `List<User>` it will return `AnyPublisher<(List<User>, RealmChangeset?), Error>`, etc.
     */
    public static func changeset<Output: NotificationEmitter>(from collection: Output,
                                                              synchronousStart: Bool = true)
        -> AnyPublisher<(AnyRealmCollection<Output.ElementType>, RealmChangeset?), Error> {
            
            let initialValue: (AnyRealmCollection<Output.ElementType>, RealmChangeset?)? = synchronousStart ? (collection.toAnyCollection(), nil) : nil
            return RealmPublisher<(AnyRealmCollection<Output.ElementType>, RealmChangeset?), Error>(initialValue: initialValue) { subscriber in
                return collection.toAnyCollection().observe(on: nil) { changeset in
                    switch changeset {
                    case let .initial(value):
                        guard !synchronousStart else { return }
                        _ = subscriber.receive((value, nil))
                    case let .update(value, deletes, inserts, updates):
                        _ = subscriber.receive((value, RealmChangeset(deleted: deletes, inserted: inserts, updated: updates)))
                    case let .error(error):
                        subscriber.receive(completion: .failure(error))
                        return
                }
            }
        }
            .eraseToAnyPublisher()
    }
    
    /**
     Returns an `AnyPublisher<(Array<Output.ElementType>, RealmChangeset?), Error>` that emits each time the collection data changes. The publisher emits an initial value upon subscription.
     
     This method emits an `Array` containing all the realm collection objects, this means they all live in the memory. If you're using this method to observe large collections you might hit memory warnings.
     
     When the observable emits for the first time (if the initial notification is not coalesced with an update) the second tuple value will be `nil`.
     
     Each following emit will include a `RealmChangeset` with the indexes inserted, deleted or modified.
     
     - parameter from: A Realm collection of type `Output`: either `Results`, `List`, `LinkingObjects` or `AnyRealmCollection`.
     - parameter synchronousStart: whether the resulting `Publisher` should emit its first element synchronously (e.g. better for UI bindings)
     
     - returns: `AnyPublisher<(Array<Output.ElementType>, RealmChangeset?), Error>`, e.g. when called on `Results<Model>` it will return `AnyPublisher<(Array<Model>, RealmChangeset?), Error>`, on a `List<User>` it will return `AnyPublisher<(Array<User>, RealmChangeset?), Error>`, etc.
     */
    public static func arrayWithChangeset<Output: NotificationEmitter>(from collection: Output,
                                                                synchronousStart: Bool = true)
        -> AnyPublisher<([Output.ElementType], RealmChangeset?), Error> {
        
            return RealmPublishers.changeset(from: collection)
                .map { ($0.toArray(), $1) }
                .eraseToAnyPublisher()
    }
    
    /**
     Returns an `AnyPublisher<(Realm, Realm.Notification), Error>` that emits each time the Realm emits a notification.
     
     The Publisher you will get emits a tuple made out of:
     
     * the realm that emitted the event
     * the notification type: this can be either `.didChange` which occurs after a refresh or a write transaction ends,
     or `.refreshRequired` which happens when a write transaction occurs from a different thread on the same realm file
     
     For more information look up: [Realm.Notification](https://realm.io/docs/swift/latest/#notifications)
     
     - parameter realm: A Realm instance
     - returns: `AnyPublisher<(Realm, Realm.Notification), Error>`, which you can subscribe to
     */
    public static func from(realm: Realm) -> AnyPublisher<(Realm, Realm.Notification), Error> {
        
        return RealmPublisher<(Realm, Realm.Notification), Error> { subscriber in
            return realm.observe { (notification: Realm.Notification, realm: Realm) in
                _ = subscriber.receive((realm, notification))
            }
        }
        .eraseToAnyPublisher()
    }
        
    /**
     Returns an `AnyPublisher<Object, Error>` that emits each time the object changes. The publisher emits an initial value upon subscription.
     
     - parameter object: A Realm Object to observe
     - parameter emitInitialValue: whether the resulting `Publisher` should emit its first element synchronously (e.g. better for UI bindings)
     - parameter properties: changes to which properties would triger emitting a .next event
     - returns: `AnyPublisher<Object, Error>` will emit any time the observed object changes + one initial emit upon subscription
     */
    
    public static func from<O: Object>(object: O,
                                emitInitialValue: Bool = true,
                                properties: [String]? = nil)
        -> AnyPublisher<O, Error> {
            
            let initialValue: O? = emitInitialValue ? object : nil
            return RealmPublisher<O, Error>(initialValue: initialValue) { subscriber in
                return object.observe(on: nil) { change in
                    switch change {
                    case let .change(_, changedProperties):
                        if let properties = properties, !changedProperties.contains(where: { return properties.contains($0.name) }) {
                            // if change property isn't an observed one, just return
                            return
                        }
                        _ = subscriber.receive(object)
                    case .deleted:
                        subscriber.receive(completion: .failure(CombineRealmError.objectDeleted))
                    case let .error(error):
                        subscriber.receive(completion: .failure(error))
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    /**
     Returns an `AnyPublisher<PropertyChange, Error>` that emits the object `PropertyChange`.
     
     - parameter object: A Realm Object to observe
     - returns: `AnyPublisher<PropertyChange, Error>` will emit any time a change is detected on the object
     */
    
    public static func propertyChanges<O: Object>(object: O) -> AnyPublisher<PropertyChange, Error> {
        
        return RealmPublisher<PropertyChange, Error> { subscriber in
            return object.observe(on: nil) { change in
                switch change {
                case let .change(_, changes):
                    for change in changes {
                        _ = subscriber.receive(change)
                    }
                case .deleted:
                    subscriber.receive(completion: .failure(CombineRealmError.objectDeleted))
                case let .error(error):
                    subscriber.receive(completion: .failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
