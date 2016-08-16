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
        case Notebooks
        case Annotations
        case TrashedNotebooks
        case TrashedAnnotations
    }
    
    let sections: [(title: String, rows: [Row])] = [
        (title: "Active", rows: [
            .Notebooks,
            .Annotations
        ]),
        (title: "Trashed", rows: [
            .TrashedNotebooks,
            .TrashedAnnotations
        ]),
    ]
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .Grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.registerClass(Value1TableViewCell.self, forCellReuseIdentifier: AccountViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        annotationStore.notebookObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.notebooksDidChange)
        annotationStore.annotationObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.annotationsDidChange)
        
        performSync()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
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
    
    func notebooksDidChange(source: NotificationSource, notebookIDs: Set<Int64>) {
        reloadData()
        tableView.reloadData()
        
        if source != .Sync {
            performSync()
        }
    }
    
    func annotationsDidChange(source: NotificationSource, annotationIDs: Set<Int64>) {
        reloadData()
        tableView.reloadData()
        
        if source != .Sync {
            performSync()
        }
    }
    
    func performSync() {
        let token = AccountController.sharedController.syncTokenForUsername(session.username)
        session.sync(annotationStore: annotationStore, token: token) { syncResult in
            dispatch_sync(dispatch_get_main_queue()) {
                switch syncResult {
                case let .Success(token: token, changes: changes, deserializationErrors: deserializationErrors):
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
                    
                    NSLog("Sync completed:\n    Uploaded: %@\n    Downloaded: %@", uploaded.joinWithSeparator(", "), downloaded.joinWithSeparator(", "))
                    
                    deserializationErrors.forEach { NSLog("%@", $0) }
                    
                    AccountController.sharedController.setSyncToken(token, forUsername: self.session.username)
                case let .Error(errors: errors):
                    NSLog("Sync failed: %@", errors)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension AccountViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(AccountViewController.CellIdentifier, forIndexPath: indexPath)
        
        switch sections[indexPath.section].rows[indexPath.row] {
        case .Notebooks:
            cell.textLabel?.text = "Notebooks"
            cell.detailTextLabel?.text = "\(notebookCount)"
            cell.accessoryType = .DisclosureIndicator
        case .Annotations:
            cell.textLabel?.text = "Annotations"
            cell.detailTextLabel?.text = "\(annotationCount)"
            cell.accessoryType = .DisclosureIndicator
        case .TrashedNotebooks:
            cell.textLabel?.text = "Notebooks"
            cell.detailTextLabel?.text = "\(trashedNotebookCount)"
            cell.accessoryType = .DisclosureIndicator
        case .TrashedAnnotations:
            cell.textLabel?.text = "Annotations"
            cell.detailTextLabel?.text = "\(trashedAnnotationCount)"
            cell.accessoryType = .DisclosureIndicator
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AccountViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch sections[indexPath.section].rows[indexPath.row] {
        case .Notebooks:
            let viewController = NotebooksViewController(annotationStore: annotationStore, status: .Active)
            
            navigationController?.pushViewController(viewController, animated: true)
        case .Annotations:
            let viewController = AnnotationsViewController(annotationStore: annotationStore, status: .Active)
            
            navigationController?.pushViewController(viewController, animated: true)
        case .TrashedNotebooks:
            let viewController = NotebooksViewController(annotationStore: annotationStore, status: .Trashed)
            
            navigationController?.pushViewController(viewController, animated: true)
        case .TrashedAnnotations:
            let viewController = AnnotationsViewController(annotationStore: annotationStore, status: .Trashed)
            
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}
