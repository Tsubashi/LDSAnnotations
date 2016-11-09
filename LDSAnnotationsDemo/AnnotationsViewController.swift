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
        case .active:
            title = "Annotations"
        case .trashed:
            title = "Trashed Annotations"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Delete All", style: .plain, target: self, action: #selector(deleteAll))
        case .deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    fileprivate static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.register(SubtitleTableViewCell.self, forCellReuseIdentifier: AnnotationsViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        annotationStore.annotationObservers.add(self, operationQueue: .main, type(of: self).annotationsDidChange)
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
    
    var annotations = [Annotation]()
    
    func reloadData() {
        switch status {
        case .active:
            annotations = annotationStore.annotations().sorted { $0.lastModified > $1.lastModified }
        case .trashed:
            annotations = annotationStore.trashedAnnotations().sorted { $0.lastModified > $1.lastModified }
        case .deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
    
    func annotationsDidChange(_ source: NotificationSource, annotationIDs: Set<Int64>) {
        assert(Thread.isMainThread)
        
        reloadData()
        tableView.reloadData()
    }
}

// MARK: - Add/rename/delete annotations
extension AnnotationsViewController {
    func textFieldDidChange(_ textField: UITextField) {
        if let alertController = presentedViewController as? UIAlertController {
            let name = alertController.textFields?[0].text ?? ""
            alertController.preferredAction?.isEnabled = (name.length > 0)
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
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return annotations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AnnotationsViewController.CellIdentifier, for: indexPath)
        
        let annotation = annotations[indexPath.row]
        cell.textLabel?.text = "\(annotation.id)"
        cell.detailTextLabel?.text = subtitleFor(annotation: annotation)
        
        return cell
    }
    
    fileprivate func subtitleFor(annotation: Annotation) -> String {
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
        
        return parts.joined(separator: ", ")
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        switch status {
        case .active:
            return "Trash"
        case .trashed:
            return "Delete"
        case .deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let annotation = annotations[indexPath.row]
            switch annotation.status {
            case .active:
                do {
                    try annotationStore.trashAnnotations([annotation])
                } catch {
                    NSLog("Failed to trash annotation: %@", "\(error)")
                }
            case .trashed:
                do {
                    try annotationStore.deleteAnnotations([annotation])
                } catch {
                    NSLog("Failed to trash annotation: %@", "\(error)")
                }
            case .deleted:
                fatalError("Deleted annotations are not supported")
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension AnnotationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch status {
        case .active:
            let annotation = annotations[indexPath.row]
            navigationController?.pushViewController(AnnotationViewController(annotation: annotation, annotationStore: annotationStore), animated: true)
        case .trashed:
            tableView.deselectRow(at: indexPath, animated: false)
            
            let annotation = annotations[indexPath.row]
            do {
                try annotationStore.restoreAnnotations([annotation])
            } catch {
                NSLog("Failed to restore annotation: %@", "\(error)")
            }
        case .deleted:
            fatalError("Deleted annotations are not supported")
        }
    }
}
