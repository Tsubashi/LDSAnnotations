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

import Foundation
import SQLite
import Swiftification

// MARK: NotebookTable

class NotebookTable {
    
    static let table = Table("notebook")
    static let id = Expression<Int64>("_id")
    static let uniqueID = Expression<String>("unique_id")
    static let name = Expression<String>("name")
    static let description = Expression<String?>("description")
    static let status = Expression<AnnotationStatus>("status")
    static let lastModified = Expression<NSDate>("last_modified")
    
    static func fromRow(row: Row) -> Notebook {
        return Notebook(id: row[id], uniqueID: row[uniqueID], name: row[name], description: row[description], status: row.get(status), lastModified: row[lastModified])
    }
    
}

// MARK: AnnotationStore

extension AnnotationStore {
    
    func createNotebookTable() throws {
        try self.db.run(NotebookTable.table.create(ifNotExists: true) { builder in
            builder.column(NotebookTable.id, primaryKey: true)
            builder.column(NotebookTable.uniqueID)
            builder.column(NotebookTable.name)
            builder.column(NotebookTable.description)
            builder.column(NotebookTable.status)
            builder.column(NotebookTable.lastModified)
        })
    }
    
    /// Returns the number of active notebooks.
    public func notebookCount() -> Int {
        return db.scalar(NotebookTable.table.filter(NotebookTable.status == .Active).count)
    }
    
    /// Returns an unordered list of active notebooks.
    public func notebooks() -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.filter(NotebookTable.status == .Active)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Adds a new notebook with `name`.
    public func addNotebook(name name: String) throws -> Notebook {
        guard name.length > 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add a notebook without a name.")
        }
        
        let notebook = Notebook(id: nil, uniqueID: NSUUID().UUIDString, name: name, description: nil, status: .Active, lastModified: NSDate())
        
        let id = try db.run(NotebookTable.table.insert(
            NotebookTable.uniqueID <- notebook.uniqueID,
            NotebookTable.name <- notebook.name,
            NotebookTable.description <- notebook.description,
            NotebookTable.status <- notebook.status,
            NotebookTable.lastModified <- notebook.lastModified
        ))
        
        notifyModifiedNotebooksWithIDs([id])
        
        var modifiedNotebook = notebook
        modifiedNotebook.id = id
        return modifiedNotebook
    }
    
    /// Saves any changes to `notebook` and updates the `lastModified`.
    public func updateNotebook(notebook: Notebook) throws -> Notebook {
        guard notebook.name.length > 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot update a notebook without a name.")
        }
        
        var modifiedNotebook = notebook
        modifiedNotebook.lastModified = NSDate()
        
        guard let id = notebook.id else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot update a notebook without an ID.")
        }
        
        try db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
            NotebookTable.uniqueID <- modifiedNotebook.uniqueID,
            NotebookTable.name <- modifiedNotebook.name,
            NotebookTable.description <- modifiedNotebook.description,
            NotebookTable.status <- modifiedNotebook.status,
            NotebookTable.lastModified <- modifiedNotebook.lastModified
        ))
        
        notifyModifiedNotebooksWithIDs([id])
        
        return modifiedNotebook
    }
    
    /// Returns the number of trashed notebooks.
    public func trashedNotebookCount() -> Int {
        return db.scalar(NotebookTable.table.filter(NotebookTable.status == .Trashed).count)
    }
    
    /// Returns an unordered list of trashed notebooks.
    public func trashedNotebooks() -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.filter(NotebookTable.status == .Trashed)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Trashes the `notebooks`; throws if any of the `notebooks` are not active or trashed.
    public func trashNotebooks(notebooks: [Notebook]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if notebook.status != .Active && notebook.status != .Trashed {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to trash a notebook that is not active or trashed.")
                }
                
                if let id = notebook.id {
                    try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                        NotebookTable.status <- .Trashed,
                        NotebookTable.lastModified <- lastModified
                        ))
                    
                    ids.append(id)
                }
            }
            
            self.notifyModifiedNotebooksWithIDs(ids)
        }
    }
    
    /// Deletes the `notebooks`; throws if any of the `notebooks` are not trashed or deleted.
    public func deleteNotebooks(notebooks: [Notebook]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if notebook.status != .Trashed && notebook.status != .Deleted {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to delete a notebook that is not trashed or deleted.")
                }
                
                if let id = notebook.id {
                    try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                        NotebookTable.status <- .Deleted,
                        NotebookTable.lastModified <- lastModified
                    ))
                    
                    ids.append(id)
                }
            }
            
            self.notifyModifiedNotebooksWithIDs(ids)
        }
    }
    
    /// Restores the `notebooks` to active.
    public func restoreNotebooks(notebooks: [Notebook]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if let id = notebook.id {
                    try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                        NotebookTable.status <- .Active,
                        NotebookTable.lastModified <- lastModified
                    ))
                    
                    ids.append(id)
                }
            }
            
            self.notifyModifiedNotebooksWithIDs(ids)
        }
    }
    
    func allNotebooks(ids ids: [Int64]? = nil, lastModifiedAfter: NSDate? = nil, lastModifiedOnOrBefore: NSDate? = nil) -> [Notebook] {
        do {
            var query = NotebookTable.table
            if let ids = ids {
                query = query.filter(ids.contains(NotebookTable.id))
            }
            if let lastModifiedAfter = lastModifiedAfter {
                query = query.filter(NotebookTable.lastModified > lastModifiedAfter)
            }
            if let lastModifiedOnOrBefore = lastModifiedOnOrBefore {
                query = query.filter(NotebookTable.lastModified <= lastModifiedOnOrBefore)
            }
            return try db.prepare(query).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func deletedNotebooks(lastModifiedOnOrBefore lastModifiedOnOrBefore: NSDate) -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.filter(NotebookTable.lastModified <= lastModifiedOnOrBefore && NotebookTable.status == .Deleted)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func notebookWithUniqueID(uniqueID: String) -> Notebook? {
        return db.pluck(NotebookTable.table.filter(NotebookTable.uniqueID == uniqueID)).map { NotebookTable.fromRow($0) }
    }
    
    func addOrUpdateNotebook(notebook: Notebook) -> Notebook? {
        do {
            if let id = notebook.id {
                try db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                    NotebookTable.uniqueID <- notebook.uniqueID,
                    NotebookTable.name <- notebook.name,
                    NotebookTable.description <- notebook.description,
                    NotebookTable.status <- notebook.status,
                    NotebookTable.lastModified <- notebook.lastModified
                ))
                
                notifySyncModifiedNotebooksWithIDs([id])
                
                return notebook
            } else {
                let id = try db.run(NotebookTable.table.insert(
                    NotebookTable.uniqueID <- notebook.uniqueID,
                    NotebookTable.name <- notebook.name,
                    NotebookTable.description <- notebook.description,
                    NotebookTable.status <- notebook.status,
                    NotebookTable.lastModified <- notebook.lastModified
                ))
                
                notifySyncModifiedNotebooksWithIDs([id])
                
                return Notebook(id: id, uniqueID: notebook.uniqueID, name: notebook.name, description: notebook.description, status: notebook.status, lastModified: notebook.lastModified)
            }
        } catch {
            return nil
        }
    }
    
    func deleteNotebookWithID(id: Int64) {
        do {
            try db.run(NotebookTable.table.filter(NotebookTable.id == id).delete())
            notifySyncModifiedNotebooksWithIDs([id])
        } catch {}
    }
    
    public func notebooksWithAnnotationID(annotationID: Int64) -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID), on: NotebookTable.id == AnnotationNotebookTable.notebookID).order(AnnotationNotebookTable.displayOrder.asc)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
}

// MARK: Notifications

extension AnnotationStore {
    
    func notifyModifiedNotebooksWithIDs(ids: [Int64]) {
        let inSyncTransactionKey = "sync-txn:\(unsafeAddressOf(self))"
        guard NSThread.currentThread().threadDictionary[inSyncTransactionKey] == nil else {
            fatalError("A local transaction cannot be started in a sync transaction")
        }
        
        let inTransactionKey = "txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[inTransactionKey] != nil {
            let notebookIDsKey = "notebookIDs:\(unsafeAddressOf(self))"
            let notebookIDs = NSThread.currentThread().threadDictionary[notebookIDsKey] as? SetBox<Int64> ?? SetBox()
            notebookIDs.set.unionInPlace(ids)
            NSThread.currentThread().threadDictionary[notebookIDsKey] = notebookIDs
        } else {
            // Immediately notify about these modified notebooks when outside of a transaction
            notebookObservers.notify((source: .Local, notebooks: allNotebooks(ids: ids)))
        }
    }
    
    func notifySyncModifiedNotebooksWithIDs(ids: [Int64]) {
        let inTransactionKey = "txn:\(unsafeAddressOf(self))"
        guard NSThread.currentThread().threadDictionary[inTransactionKey] == nil else {
            fatalError("A sync transaction cannot be started in a local transaction")
        }
        
        let inSyncTransactionKey = "sync-txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[inSyncTransactionKey] != nil {
            let notebookIDsKey = "notebookIDs:\(unsafeAddressOf(self))"
            let notebookIDs = NSThread.currentThread().threadDictionary[notebookIDsKey] as? SetBox<Int64> ?? SetBox()
            notebookIDs.set.unionInPlace(ids)
            NSThread.currentThread().threadDictionary[notebookIDsKey] = notebookIDs
        } else {
            // Immediately notify about these modified notebooks when outside of a transaction
            notebookObservers.notify((source: .Sync, notebooks: allNotebooks(ids: ids)))
        }
    }
    
}
