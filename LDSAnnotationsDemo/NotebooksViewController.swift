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

class NotebooksViewController: UIViewController {
    
    let annotationStore: AnnotationStore
    let status: AnnotationStatus
    
    init(annotationStore: AnnotationStore, status: AnnotationStatus) {
        self.annotationStore = annotationStore
        self.status = status
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        switch status {
        case .Active:
            title = "Notebooks"
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(add))
        case .Trashed:
            title = "Trashed Notebooks"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Delete All", style: .Plain, target: self, action: #selector(deleteAll))
        case .Deleted:
            fatalError("Deleted notebooks are not supported")
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
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: NotebooksViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        annotationStore.notebookObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.notebooksDidChange)
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
    
    var notebooks = [Notebook]()
    
    func reloadData() {
        switch status {
        case .Active:
            notebooks = annotationStore.notebooks().sort { $0.name < $1.name }
        case .Trashed:
            notebooks = annotationStore.trashedNotebooks().sort { $0.name < $1.name }
        case .Deleted:
            fatalError("Deleted notebooks are not supported")
        }
    }
    
    func notebooksDidChange(source: NotificationSource, notebooks: [Notebook]) {
        assert(NSThread.isMainThread())
        
        reloadData()
        tableView.reloadData()
    }
    
}

// MARK: - Add/rename/delete notebooks

extension NotebooksViewController {
    
    func add() {
        let alertController = UIAlertController(title: "Add Notebook", message: "Enter the name for your notebook.", preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler { textField in
            textField.placeholder = "Name"
            textField.addTarget(self, action: #selector(NotebooksViewController.textFieldDidChange(_:)), forControlEvents: .EditingChanged)
        }
        
        let doneAction = UIAlertAction(title: "OK", style: .Default, handler: { _ in
            let name = alertController.textFields?[safe: 0]?.text ?? ""
            self.addNotebookWithName(name)
        })
        doneAction.enabled = false
        alertController.addAction(doneAction)
        alertController.preferredAction = doneAction
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    func textFieldDidChange(textField: UITextField) {
        if let alertController = presentedViewController as? UIAlertController {
            let name = alertController.textFields?[safe: 0]?.text ?? ""
            alertController.preferredAction?.enabled = (name.length > 0)
        }
    }
    
    func addNotebookWithName(name: String) {
        do {
            try annotationStore.addNotebook(name: name)
        } catch {
            NSLog("Failed to add notebook: %@", "\(error)")
            
            let alertController = UIAlertController(title: "Unable to Add Notebook", message: "Failed to save notebook.", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    func renameNotebook(notebook: Notebook, name: String) {
        do {
            var modifiedNotebook = notebook
            modifiedNotebook.name = name
            try annotationStore.updateNotebook(modifiedNotebook)
        } catch {
            NSLog("Failed to rename notebook: %@", "\(error)")
            
            let alertController = UIAlertController(title: "Unable to Rename Notebook", message: "Failed to save notebook.", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    func deleteAll() {
        do {
            try annotationStore.deleteNotebooks(notebooks)
        } catch {
            NSLog("Failed to delete notebooks: %@", "\(error)")
        }
    }
    
}

// MARK: - UITableViewDataSource

extension NotebooksViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notebooks.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(NotebooksViewController.CellIdentifier, forIndexPath: indexPath)
        
        let notebook = notebooks[indexPath.row]
        cell.textLabel?.text = notebook.name
        
        return cell
    }
    
    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
        switch status {
        case .Active:
            return "Trash"
        case .Trashed:
            return "Delete"
        case .Deleted:
            fatalError("Deleted notebooks are not supported")
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let notebook = notebooks[indexPath.row]
            switch notebook.status {
            case .Active:
                do {
                    try annotationStore.trashNotebooks([notebook])
                } catch {
                    NSLog("Failed to trash notebook: %@", "\(error)")
                }
            case .Trashed:
                do {
                    try annotationStore.deleteNotebooks([notebook])
                } catch {
                    NSLog("Failed to trash notebook: %@", "\(error)")
                }
            case .Deleted:
                fatalError("Deleted notebooks are not supported")
            }
        }
    }
    
}

// MARK: - UITableViewDelegate

extension NotebooksViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        switch status {
        case .Active:
            let notebook = notebooks[indexPath.row]
            
            let alertController = UIAlertController(title: "Rename Notebook", message: "Enter the new name for your notebook.", preferredStyle: .Alert)
            alertController.addTextFieldWithConfigurationHandler { textField in
                textField.text = notebook.name
                textField.placeholder = "Name"
                textField.addTarget(self, action: #selector(NotebooksViewController.textFieldDidChange(_:)), forControlEvents: .EditingChanged)
            }
            
            let doneAction = UIAlertAction(title: "OK", style: .Default, handler: { _ in
                let name = alertController.textFields?[safe: 0]?.text ?? ""
                self.renameNotebook(notebook, name: name)
            })
            alertController.addAction(doneAction)
            alertController.preferredAction = doneAction
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            
            presentViewController(alertController, animated: true, completion: nil)
        case .Trashed:
            let notebook = notebooks[indexPath.row]
            do {
                try annotationStore.restoreNotebooks([notebook])
            } catch {
                NSLog("Failed to restore notebook: %@", "\(error)")
            }
        case .Deleted:
            fatalError("Deleted notebooks are not supported")
        }
    }
    
}
