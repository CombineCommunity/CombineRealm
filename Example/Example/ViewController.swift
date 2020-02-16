//
//  ViewController.swift
//  Example
//
//  Created by István Kreisz on 06/02/2020.
//  Copyright (c) Combine Community. All rights reserved.
//

import UIKit
import RealmSwift
import Combine
import CombineRealm

class MainViewController: UITableViewController {
    
    var subscriptions = Set<AnyCancellable>()
        
    var colors: Results<Color>!
    
    let addedColors = PassthroughSubject<Color, Never>()
    let deletedColors = PassthroughSubject<Color, Never>()
    
    let tickUpdated = PassthroughSubject<Void, Never>()
    
    let footer: UIStackView = {
        let label1 = UILabel()
        let label2 = UILabel()
        label1.textAlignment = .center
        label2.textAlignment = .center
        let stackView = UIStackView(arrangedSubviews: [label1, label2])
        stackView.distribution = .fillEqually
        stackView.axis = .horizontal
        return stackView
    }()
            
    lazy var ticker: TickCounter = {
        let realm = try! Realm()
        let ticker = TickCounter()
        try! realm.write {
            realm.add(ticker)
        }
        return ticker
    }()
            
    @IBAction func addTapped(_ sender: Any) {
        addedColors.send(Color())
    }
    
    @IBAction func tickTapped(_ sender: Any) {
        tickUpdated.send()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let realm = try! Realm()
        colors = realm.objects(Color.self).sorted(byKeyPath: "time", ascending: false)
        
        tickUpdated
            .sink { [unowned self] in
                let realm = try! Realm()
                try! realm.write {
                    self.ticker.ticks += 1
                }
        }
        .store(in: &subscriptions)
        
        // Observing collection changes
        RealmPublishers.collection(from: colors)
            .map { results in "colors: \(results.count)" }
            .sink(receiveCompletion: { _ in
                print("Completed")
            }, receiveValue: { results in
                self.title = results
            })
            .store(in: &subscriptions)

        // Observing changesets
        RealmPublishers.changeset(from: colors)
            .sink(receiveCompletion: { _ in
                print("Completed")
            }, receiveValue: { [unowned self] _, changes in
                if let changes = changes {
                    self.tableView.applyChangeset(changes)
                } else {
                    self.tableView.reloadData()
                }
            })
            .store(in: &subscriptions)

        // Adding to realm
        addedColors
            .addToRealm()
            .store(in: &subscriptions)

        // Deleting from realm
        deletedColors
            .deleteFromRealm()
            .store(in: &subscriptions)
                        
        // Observing a single object
        RealmPublishers.propertyChanges(object: ticker)
            .filter { $0.name == "ticks" }
            .map { "\($0.newValue!) ticks" }
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [unowned self] ticks in
                    (self.footer.arrangedSubviews[0] as! UILabel).text = ticks
            })
            .store(in: &subscriptions)
        
        // Observing all database changes
        RealmPublishers.from(realm: realm)
            .map { _ in }
            .scan(0, { result, _ in
                return result + 1
            })
            .map { "\($0) changes" }
            .sink(receiveCompletion: { _ in },
                  receiveValue: { count in
                    (self.footer.arrangedSubviews[1] as! UILabel).text = count
            })
            .store(in: &subscriptions)
    }
}

extension MainViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return colors.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let color = colors[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = formatter.string(from: Date(timeIntervalSinceReferenceDate: color.time))
        cell.backgroundColor = color.color
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Delete objects by tapping them"
    }
}

extension MainViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        deletedColors.send(colors[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return footer
    }
}

extension UITableView {
    func applyChangeset(_ changes: RealmChangeset) {
        beginUpdates()
        deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        endUpdates()
    }
}

