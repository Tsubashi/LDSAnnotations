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

/// A local annotation store backed by a SQLite database.
public class AnnotationStore {
    
    private let db: Connection!
    
    private static let currentVersion = 1
    
    /// Constructs a local annotation store at `path`; if `path` is `nil` or empty, the annotation store is held in memory.
    ///
    /// Returns `nil` if a database connection to the annotation store cannot be opened.
    public init?(path: String? = nil) {
        db = try? Connection(path ?? "")
        if db == nil {
            return nil
        }
        
        if databaseVersion < self.dynamicType.currentVersion {
            upgradeDatabaseFromVersion(databaseVersion)
        }
    }
    
    var databaseVersion: Int {
        get {
            return Int(db.scalar("PRAGMA user_version") as? Int64 ?? 0)
        }
        set {
            do {
                try db.run("PRAGMA user_version = \(newValue)")
            } catch {}
        }
    }
    
    private func upgradeDatabaseFromVersion(fromVersion: Int) {
        if fromVersion < 1 {
            do {
                try db.transaction {
                    try self.db.run(NotebookTable.table.create(ifNotExists: true) { builder in
                        builder.column(NotebookTable.id, primaryKey: true)
                        builder.column(NotebookTable.uniqueID)
                        builder.column(NotebookTable.name)
                        builder.column(NotebookTable.description)
                        builder.column(NotebookTable.status)
                        builder.column(NotebookTable.lastModified)
                    })
                    
                    self.databaseVersion = 1
                }
            } catch {}
        }
    }
    
    /// Makes multiple queries or modifications in a single transaction.
    ///
    /// This method is reentrant.
    public func inTransaction(closure: () throws -> Void) throws {
        let key = "txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[key] != nil {
            try closure()
        } else {
            NSThread.currentThread().threadDictionary[key] = true
            defer { NSThread.currentThread().threadDictionary[key] = false }
            try db.transaction(block: closure)
        }
    }
    
}

private class NotebookTable {
    
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

extension AnnotationStore {
    
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
        guard let notebook = addOrUpdateNotebook(Notebook(id: nil, uniqueID: NSUUID().UUIDString, name: name, description: nil, status: .Active, lastModified: NSDate())) else {
            throw Error.errorWithCode(.Unknown, failureReason: "Failed to add notebook")
        }
        
        return notebook
    }
    
    /// Saves any changes to `notebook` and updates the `lastModified`.
    public func updateNotebook(notebook: Notebook) throws -> Notebook {
        var modifiedNotebook = notebook
        modifiedNotebook.lastModified = NSDate()
        
        if addOrUpdateNotebook(modifiedNotebook) == nil {
            throw Error.errorWithCode(.Unknown, failureReason: "Failed to update notebook")
        }
        
        return modifiedNotebook
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
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.mapFilter { $0.id }) {
                if notebook.status != .Active && notebook.status != .Trashed {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to trash a notebook that is not active or trashed.")
                }
                
                if let id = notebook.id {
                    try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                        NotebookTable.status <- .Trashed,
                        NotebookTable.lastModified <- lastModified
                    ))
                }
            }
        }
    }
    
    /// Deletes the `notebooks`; throws if any of the `notebooks` are not trashed or deleted.
    public func deleteNotebooks(notebooks: [Notebook]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.mapFilter { $0.id }) {
                if notebook.status != .Trashed && notebook.status != .Deleted {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to delete a notebook that is not trashed or deleted.")
                }
                
                if let id = notebook.id {
                    try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                        NotebookTable.status <- .Deleted,
                        NotebookTable.lastModified <- lastModified
                    ))
                }
            }
        }
    }
    
}

extension AnnotationStore {
    
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
                return notebook
            } else {
                let id = try db.run(NotebookTable.table.insert(
                    NotebookTable.uniqueID <- notebook.uniqueID,
                    NotebookTable.name <- notebook.name,
                    NotebookTable.description <- notebook.description,
                    NotebookTable.status <- notebook.status,
                    NotebookTable.lastModified <- notebook.lastModified
                ))
                return Notebook(id: id, uniqueID: notebook.uniqueID, name: notebook.name, description: notebook.description, status: notebook.status, lastModified: notebook.lastModified)
            }
        } catch {
            return nil
        }
    }
    
    func deleteNotebookWithID(id: Int64) {
        do {
            try db.run(NotebookTable.table.filter(NotebookTable.id == id).delete())
        } catch {}
    }
    
}
