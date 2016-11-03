//
// Copyright (c) 2016 Hilton Campbell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit
import Swiftification
import LDSAnnotations

class AccountViewController: UIViewController {
    let session: Session
    let annotationStore: AnnotationStore
    
    init(session: Session, annotationStore: AnnotationStore) {
        self.session = session
        self.annotationStore = annotationStore
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        title = session.username
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    enum Row {
        case notebooks
        case annotations
        case trashedNotebooks
        case trashedAnnotations
    }
    
    let sections: [(title: String, rows: [Row])] = [
        (title: "Active", rows: [
            .notebooks,
            .annotations
        ]),
        (title: "Trashed", rows: [
            .trashedNotebooks,
            .trashedAnnotations
        ]),
    ]
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    fileprivate static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: AccountViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        annotationStore.notebookObservers.add(self, operationQueue: .main, type(of: self).notebooksDidChange)
        annotationStore.annotationObservers.add(self, operationQueue: .main, type(of: self).annotationsDidChange)
        
        performSync()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.flashScrollIndicators()
    }
    
    var notebookCount = 0
    var annotationCount = 0
    var trashedNotebookCount = 0
    var trashedAnnotationCount = 0
    
    func reloadData() {
        notebookCount = annotationStore.notebookCount()
        annotationCount = annotationStore.annotationCount()
        trashedNotebookCount = annotationStore.trashedNotebookCount()
        trashedAnnotationCount = annotationStore.trashedAnnotationCount()
    }
    
    func notebooksDidChange(_ source: NotificationSource, notebookIDs: Set<Int64>) {
        reloadData()
        tableView.reloadData()
        
        if case .local = source {
            performSync()
        }
    }
    
    func annotationsDidChange(_ source: NotificationSource, annotationIDs: Set<Int64>) {
        reloadData()
        tableView.reloadData()
        
        if case .local = source {
            performSync()
        }
    }
    
    func performSync() {
        let token = AccountController.sharedController.syncToken(forUsername: session.username)
        session.sync(annotationStore: annotationStore, token: token) { syncResult in
            DispatchQueue.main.sync {
                switch syncResult {
                case let .success(token: token, changes: changes, deserializationErrors: deserializationErrors):
                    let uploaded = [
                        "\(changes.uploadedNotebooks.count) notebooks",
                        "\(changes.uploadAnnotationCount) annotations",
                        "\(changes.uploadHighlightCount) highlights",
                        "\(changes.uploadNoteCount) notes",
                        "\(changes.uploadTagCount) tags",
                        "\(changes.uploadBookmarkCount) bookmarks",
                        "\(changes.uploadLinkCount) links",
                    ]
                    let downloaded = [
                        "\(changes.downloadedNotebooks.count) notebooks",
                        "\(changes.downloadAnnotationCount) annotations",
                        "\(changes.downloadHighlightCount) highlights",
                        "\(changes.downloadNoteCount) notes",
                        "\(changes.downloadTagCount) tags",
                        "\(changes.downloadBookmarkCount) bookmarks",
                        "\(changes.downloadLinkCount) links",
                    ]
                    
                    NSLog("Sync completed:\n    Uploaded: %@\n    Downloaded: %@", uploaded.joined(separator: ", "), downloaded.joined(separator: ", "))
                    
                    deserializationErrors.forEach { NSLog("\($0)") }
                    
                    AccountController.sharedController.setSyncToken(token, forUsername: self.session.username)
                case let .error(errors: errors):
                    NSLog("Sync failed: \(errors)")
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension AccountViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AccountViewController.CellIdentifier, for: indexPath)
        
        switch sections[indexPath.section].rows[indexPath.row] {
        case .notebooks:
            cell.textLabel?.text = "Notebooks"
            cell.detailTextLabel?.text = "\(notebookCount)"
            cell.accessoryType = .disclosureIndicator
        case .annotations:
            cell.textLabel?.text = "Annotations"
            cell.detailTextLabel?.text = "\(annotationCount)"
            cell.accessoryType = .disclosureIndicator
        case .trashedNotebooks:
            cell.textLabel?.text = "Notebooks"
            cell.detailTextLabel?.text = "\(trashedNotebookCount)"
            cell.accessoryType = .disclosureIndicator
        case .trashedAnnotations:
            cell.textLabel?.text = "Annotations"
            cell.detailTextLabel?.text = "\(trashedAnnotationCount)"
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AccountViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section].rows[indexPath.row] {
        case .notebooks:
            let viewController = NotebooksViewController(annotationStore: annotationStore, status: .Active)
            
            navigationController?.pushViewController(viewController, animated: true)
        case .annotations:
            let viewController = AnnotationsViewController(annotationStore: annotationStore, status: .Active)
            
            navigationController?.pushViewController(viewController, animated: true)
        case .trashedNotebooks:
            let viewController = NotebooksViewController(annotationStore: annotationStore, status: .Trashed)
            
            navigationController?.pushViewController(viewController, animated: true)
        case .trashedAnnotations:
            let viewController = AnnotationsViewController(annotationStore: annotationStore, status: .Trashed)
            
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}
