# CombineRealm

![CombineRealm Logo](CombineRealm.png)

[![Version](https://img.shields.io/cocoapods/v/Combine-Realm.svg?style=flat)](http://cocoapods.org/pods/Combine-Realm)
[![License](https://img.shields.io/cocoapods/l/Combine-Realm.svg?style=flat)](http://cocoapods.org/pods/Combine-Realm)
![Platform](https://img.shields.io/badge/platforms-iOS%2013%20&%20macOS%2010.15%20&%20tvOS%2013%20&%20watchOS%206-success.svg)

This library is a thin wrapper around __RealmSwift__ ([Realm Docs](https://realm.io/docs/swift/latest/)), inspired by the RxSwift Community's [RxRealm](https://github.com/RxSwiftCommunity/RxRealm) library.

## Usage

**Table of contents:**

 1. [Observing object collections](https://github.com/istvan-kreisz/CombineRealm#observing-object-collections)
 2. [Observing a single object](https://github.com/istvan-kreisz/CombineRealm#observing-a-single-object)
 3. [Observing a realm instance](https://github.com/istvan-kreisz/CombineRealm#observing-a-realm-instance)
 4. [Write transactions](https://github.com/istvan-kreisz/CombineRealm#write-transactions)
 5. [Delete transactions](https://github.com/istvan-kreisz/CombineRealm#delete-transactions)
 6. [Example app](https://github.com/istvan-kreisz/CombineRealm#example-app)

### Observing object collections

CombineRealm can be used to create `Publisher`s from objects of type `Results`, `List`, `LinkingObjects` or `AnyRealmCollection`. These types are typically used to load and observe object collections from the Realm Mobile Database.

#### `RealmPublishers.collection(from:synchronousStart:)`

Emits an event each time the collection changes:

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self)

RealmPublishers.collection(from: colors)
    .map { colors in "colors: \(colors.count)" }
    .sink(receiveCompletion: { _ in
        print("Completed")
    }, receiveValue: { result in
        print(result)
    })
```

The above prints out "colors: X" each time a `Color` instance is added or removed from the database. If you set `synchronousStart` to `true` (the default value), the first element will be emitted synchronously - e.g. when you're binding UI it might not be possible for an asynchronous notification to come through.

#### `RealmPublishers.array(from:synchronousStart:)`
Upon each change fetches a snapshot of the Realm collection and converts it to an array value (for example if you want to use array methods on the collection):

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self)

RealmPublishers.array(from: colors)
    .map { colors in colors.prefix(3) }
    .sink(receiveCompletion: { _ in
        print("Completed")
    }, receiveValue: { colors in
        print(colors)
    })
```

#### `RealmPublishers.changeset(from:synchronousStart:)`
Emits every time the collection changes and provides the exact indexes that have been deleted, inserted or updated along with the appropriate `AnyRealmCollection<T>` value:

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self)

RealmPublishers.changeset(from: colors)
    .sink(receiveCompletion: { _ in
        print("Completed")
    }, receiveValue: { results, changes in
        if let changes = changes {
            // it's an update
            print(results)
            print("deleted: \(changes.deleted)")
            print("inserted: \(changes.inserted)")
            print("updated: \(changes.updated)")
        } else {
            // it's the initial data
            print(results)
        }
    })
```

#### `RealmPublishers.arrayWithChangeset(from:synchronousStart:)`

Emits every time the collection changes and provides the exact indexes that have been deleted, inserted or updated along with the `Array<T>` value:

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self))

RealmPublishers.arrayWithChangeset(from: colors)
    .sink(receiveCompletion: { _ in
        print("Completed")
    }, receiveValue: { array, changes in
        if let changes = changes {
            // it's an update
            print(array)
            print("deleted: \(changes.deleted)")
            print("inserted: \(changes.inserted)")
            print("updated: \(changes.updated)")
        } else {
            // it's the initial data
            print(array)
        }
    })
```

### Observing a single object

#### `RealmPublishers.from(object:emitInitialValue:properties:)`

Emits every time any of the properties of the observed object change.

It will by default emit the object's initial state as its first value. You can disable this behavior by using the `emitInitialValue` parameter and setting it to `false`.

```swift
RealmPublishers.from(object: color)
    .sink(receiveCompletion: { _ in
        print("Completed")
    }) { color in
        print(color)
    }
```

You can set which property changes you'd like to observe:

```swift
Observable.from(object: ticker, properties: ["red", "green", "blue"])
```

### Observing a realm instance

#### `RealmPublishers.from(realm:)`

Emits every time the realm changes: any create & update & delete operation happens in it. It provides the realm instance along with the realm change notification.

```swift
let realm = try! Realm()

RealmPublishers.from(realm: realm)
    .sink(receiveCompletion: { _ in
        print("Completed")
    }) { realm, notification in
        print("Something happened!")
    }
```

### Write transactions

#### `addToRealm()`

Writes object(s) to the default Realm: `Realm(configuration: .defaultConfiguration)`.

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self))

RealmPublishers.array(from: colors)
  .addToRealm()
```

#### `addToRealm(configuration:updatePolicy:onError:)`

Writes object(s) to a **custom** Realm. If you want to switch threads and not use the default Realm, provide a `Realm.Configuration`. You an also provide an error handler for the observer to be called if either creating the realm reference or the write transaction raise an error:

NOTE: All 3 arguments are optional, check the function definition for the default values

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self))

RealmPublishers.array(from: colors)
  .addToRealm(configuration: .defaultCOnfiguration, updatePolicy: .error, onError: {
      print($0)
  })
```

### Delete transactions

#### `deleteFromRealm()`

Deletes object(s) from the object(s)'s realm:

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self))

RealmPublishers.array(from: colors)
  .deleteFromRealm()
```

#### `deleteFromRealm(onError:)`

Deletes object(s) from the object(s)'s realm. You an also provide an error handler for the observer to be called if either creating the realm reference or the write transaction raise an error:

```swift
let realm = try! Realm()
let colors = realm.objects(Color.self))

RealmPublishers.array(from: colors)
  .deleteFromRealm(onError: {
      print($0)
  })
```

### Example app

To run the example project, clone the repo, navigate to the __Example__ folder and open the `Example.xcodeproj` file.

To ensure that you're using the latest version of CombineRealm, in Xcode select `Update to Latest Package Versions` in the `File/Swift Packages/Add Package Dependency...` menu.

The app uses CombineRealm to observe changes in and write to Realm.

## Testing

To inspect the library's Unit tests, check out the files in `Tests/CombineRealmTests`.
To run the tests, go to the root directory of the repo and run the command:

```swift
swift test
```

## Installation

### CocoaPods

Add the following line to your Podfile and run `pod install`:

```ruby
pod 'Combine-Realm'
```
Since import statements in Xcode can't contain dashes, the correct way to import the library is:

```swift
import Combine_Realm
```

### Swift Package Manager

- In Xcode select `File/Swift Packages/Add Package Dependency...`
- Paste `https://github.com/istvan-kreisz/CombineRealm.git` into the repository URL textfield.

### Future ideas

- Add CI tests
- Add Carthage support
- Your ideas?

## Author

__Istvan Kreisz__

[kreiszdev@gmail.com](mailto:kreiszdev@gmail.com)

[@IKreisz](https://twitter.com/IKreisz)

## License

CombineReachability is available under the MIT license. See the LICENSE file for more info.
