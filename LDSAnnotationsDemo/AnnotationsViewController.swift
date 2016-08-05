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

class AnnotationsViewController: UIViewController {
    let annotationStore: AnnotationStore
    let status: AnnotationStatus
    
    init(annotationStore: AnnotationStore, status: AnnotationStatus) {
        self.annotationStore = annotationStore
        self.status = status
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        switch status {
        case .Active:
            title = "Annotations"
        case .Trashed:
            title = "Trashed Annotations"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Delete All", style: .Plain, target: self, action: #selector(deleteAll))
        case .Deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .Plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.registerClass(SubtitleTableViewCell.self, forCellReuseIdentifier: AnnotationsViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        annotationStore.annotationObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.annotationsDidChange)
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
    
    var annotations = [Annotation]()
    
    func reloadData() {
        switch status {
        case .Active:
            annotations = annotationStore.annotations().sort { $0.lastModified > $1.lastModified }
        case .Trashed:
            annotations = annotationStore.trashedAnnotations().sort { $0.lastModified > $1.lastModified }
        case .Deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
    
    func annotationsDidChange(source: NotificationSource, annotations: [Annotation]) {
        assert(NSThread.isMainThread())
        
        reloadData()
        tableView.reloadData()
    }
}

// MARK: - Add/rename/delete annotations
extension AnnotationsViewController {
    func textFieldDidChange(textField: UITextField) {
        if let alertController = presentedViewController as? UIAlertController {
            let name = alertController.textFields?[safe: 0]?.text ?? ""
            alertController.preferredAction?.enabled = (name.length > 0)
        }
    }
    
    func deleteAll() {
        do {
            try annotationStore.deleteAnnotations(annotations)
        } catch {
            NSLog("Failed to delete annotations: %@", "\(error)")
        }
    }
}

// MARK: - UITableViewDataSource
extension AnnotationsViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return annotations.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(AnnotationsViewController.CellIdentifier, forIndexPath: indexPath)
        
        let annotation = annotations[indexPath.row]
        cell.textLabel?.text = "\(annotation.id ?? 0)"
        cell.detailTextLabel?.text = subtitleFor(annotation: annotation)
        
        return cell
    }
    
    private func subtitleFor(annotation annotation: Annotation) -> String {
        var parts = [String]()
        if let _ = annotationStore.noteWithAnnotationID(annotation.id) {
            parts.append("1 note")
        }
        if let _ = annotationStore.bookmarkWithAnnotationID(annotation.id) {
            parts.append("1 bookmark")
        }
        let highlights = annotationStore.highlightsWithAnnotationID(annotation.id)
        if !highlights.isEmpty {
            parts.append("\(highlights.count) highlight(s)")
        }
        let tags = annotationStore.tagsWithAnnotationID(annotation.id)
        if !tags.isEmpty {
            parts.append("\(tags.count) tag(s)")
        }
        let links = annotationStore.linksWithAnnotationID(annotation.id)
        if !links.isEmpty {
            parts.append("\(links.count) link(s)")
        }
        let notebooks = annotationStore.notebooksWithAnnotationID(annotation.id)
        if !notebooks.isEmpty {
            parts.append("\(notebooks.count) notebook(s)")
        }
        
        return parts.joinWithSeparator(", ")
    }
    
    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
        switch status {
        case .Active:
            return "Trash"
        case .Trashed:
            return "Delete"
        case .Deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let annotation = annotations[indexPath.row]
            switch annotation.status {
            case .Active:
                do {
                    try annotationStore.trashAnnotations([annotation])
                } catch {
                    NSLog("Failed to trash annotation: %@", "\(error)")
                }
            case .Trashed:
                do {
                    try annotationStore.deleteAnnotations([annotation])
                } catch {
                    NSLog("Failed to trash annotation: %@", "\(error)")
                }
            case .Deleted:
                fatalError("Deleted annotations are not supported")
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension AnnotationsViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch status {
        case .Active:
            let annotation = annotations[indexPath.row]
            navigationController?.pushViewController(AnnotationViewController(annotation: annotation, annotationStore: annotationStore), animated: true)
        case .Trashed:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            
            let annotation = annotations[indexPath.row]
            do {
                try annotationStore.restoreAnnotations([annotation])
            } catch {
                NSLog("Failed to restore annotation: %@", "\(error)")
            }
        case .Deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
}
