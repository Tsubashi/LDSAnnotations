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

// MARK: Public

public extension AnnotationStore {

    /// Returns the number of active notebooks.
    public func notebookCount() -> Int {
        return db.scalar(NotebookTable.table.filter(NotebookTable.status == .Active).count)
    }

    /// Adds a new notebook with `name`.
    public func addNotebook(name name: String, description: String? = nil) throws -> Notebook {
        return try addNotebook(uniqueID: nil, name: name, description: description, status: .Active, lastModified: nil, source: .Local)
    }
    
    public func trashNotebookWithID(id: Int64) throws {
        try trashNotebookWithID(id, source: .Local)
    }

    /// Returns the number of trashed notebooks.
    public func trashedNotebookCount() -> Int {
        return db.scalar(NotebookTable.table.filter(NotebookTable.status == .Trashed).count)
    }

    /// Saves any changes to `notebook` and updates the `lastModified`.
    public func updateNotebook(notebook: Notebook) throws -> Notebook {
        return try updateNotebook(notebook, source: .Local)
    }
    
    /// Returns a list of active notebooks, order by OrderBy.
    public func notebooks(ids ids: [Int64]? = nil, orderBy: OrderBy = .Name) -> [Notebook] {
        guard orderBy != .NumberOfAnnotations else { return notebooksOrderedByCount(ids: ids) }
        
        var query = NotebookTable.table.filter(NotebookTable.status == .Active)
        if let ids = ids {
            query = query.filter(ids.contains(NotebookTable.id))
        }
        
        switch orderBy {
        case .Name:
            query = query.order(NotebookTable.name.asc)
        case .MostRecent:
            query = query.order(NotebookTable.lastModified.desc)
        case .NumberOfAnnotations:
            break
        }
        
        do {
            return try db.prepare(query).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns the number of notebooks modified after lastModifiedAfter date with status
    public func numberOfUnsyncedNotebooks(lastModifiedAfter lastModifiedAfter: NSDate? = nil) -> Int {
        var query = NotebookTable.table
        if let lastModifiedAfter = lastModifiedAfter {
            query = query.filter(NotebookTable.lastModified > lastModifiedAfter)
        }
        return db.scalar(query.count)
    }
    
    /// Returns all notebooks with ids, after lastModifiedAfter and before lastModifiedOnOrBefore
    public func allNotebooks(ids ids: [Int64]? = nil, lastModifiedAfter: NSDate? = nil, lastModifiedOnOrBefore: NSDate? = nil) -> [Notebook] {
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
    
    /// Returns a notebook with uniqueID
    public func notebookWithUniqueID(uniqueID: String) -> Notebook? {
        return db.pluck(NotebookTable.table.filter(NotebookTable.uniqueID == uniqueID)).map { NotebookTable.fromRow($0) }
    }
    
    /// Returns a notebook with ID
    public func notebookWithID(id: Int64) -> Notebook? {
        return db.pluck(NotebookTable.table.filter(NotebookTable.id == id)).map { NotebookTable.fromRow($0) }
    }
    
    /// Returns notebooks with annotationID
    public func notebooksWithAnnotationID(annotationID: Int64) -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID), on: NotebookTable.id == AnnotationNotebookTable.notebookID).order(AnnotationNotebookTable.displayOrder.asc)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns notebook IDs by annotationID
    func notebookIDsWithAnnotationIDsIn(annotationIDs: [Int64]) -> [Int64: [Int64]] {
        do {
            let results = try db.prepare(AnnotationNotebookTable.table.select(AnnotationNotebookTable.notebookID, AnnotationNotebookTable.annotationID).filter(annotationIDs.contains(AnnotationNotebookTable.annotationID)).order(AnnotationNotebookTable.displayOrder.asc)).map { (annotationID: $0[AnnotationNotebookTable.annotationID], notebookID: $0[AnnotationNotebookTable.notebookID]) }
            
            var notebookIDsByAnnotationID = [Int64: [Int64]]()
            for result in results {
                if notebookIDsByAnnotationID[result.annotationID] != nil {
                    notebookIDsByAnnotationID[result.annotationID]?.append(result.notebookID)
                } else {
                    notebookIDsByAnnotationID[result.annotationID] = [result.notebookID]
                }
            }
            
            return notebookIDsByAnnotationID
        } catch {
            return [:]
        }
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
    func trashNotebooks(notebooks: [Notebook]) throws {
        try trashNotebooks(notebooks, source: .Local)
    }
    
    /// Deletes the `notebooks`; throws if any of the `notebooks` are not trashed or deleted.
    public func deleteNotebooks(notebooks: [Notebook]) throws {
        try deleteNotebooks(notebooks, source: .Local)
    }
    
    /// Restores the `notebooks` to active.
    public func restoreNotebooks(notebooks: [Notebook]) throws {
        try restoreNotebooks(notebooks, source: .Local)
    }
    
}

// MARK: Internal

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
    
    func addNotebook(uniqueID uniqueID: String? = nil, name: String, description: String? = nil, status: AnnotationStatus = .Active, lastModified: NSDate? = nil, source: NotificationSource) throws -> Notebook {
        guard !name.isEmpty else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a notebook without a name.")
        }
        
        let uniqueID = uniqueID ?? NSUUID().UUIDString
        let lastModified = lastModified ?? NSDate()
        
        return try inTransaction(source) {
            let id = try self.db.run(NotebookTable.table.insert(
                NotebookTable.uniqueID <- uniqueID,
                NotebookTable.name <- name,
                NotebookTable.description <- description,
                NotebookTable.status <- status,
                NotebookTable.lastModified <- lastModified
            ))
        
            try self.notifyModifiedNotebooksWithIDs([id], source: source)
        
            return Notebook(id: id, uniqueID: uniqueID, name: name, description: description, status: status, lastModified: lastModified)
        }
    }
    
    func updateNotebook(notebook: Notebook, source: NotificationSource) throws -> Notebook {
        guard notebook.name.length > 0 else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot update a notebook without a name.")
        }
        
        var modifiedNotebook = notebook
        modifiedNotebook.lastModified = NSDate()
        
        return try inTransaction(source) {
            try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                NotebookTable.uniqueID <- modifiedNotebook.uniqueID,
                NotebookTable.name <- modifiedNotebook.name,
                NotebookTable.description <- modifiedNotebook.description,
                NotebookTable.status <- modifiedNotebook.status,
                NotebookTable.lastModified <- modifiedNotebook.lastModified
            ))
            
            try self.notifyModifiedNotebooksWithIDs([notebook.id], source: source)
            
            return modifiedNotebook
        }
    }
    
    func deletedNotebooks(lastModifiedOnOrBefore lastModifiedOnOrBefore: NSDate) -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.filter(NotebookTable.lastModified <= lastModifiedOnOrBefore && NotebookTable.status == .Deleted)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active notebooks order by number of annotations in notebook descending.
    private func notebooksOrderedByCount(ids ids: [Int64]? = nil) -> [Notebook] {
        let inClause: String = {
            guard let ids = ids else { return "" }
            
            return String(format: "AND notebook._id IN (%@)", ids.map({ String($0) }).joinWithSeparator(","))
        }()
        
        let statement = "SELECT notebook.* FROM notebook LEFT JOIN (SELECT notebook_id, count(annotation_id) AS cnt FROM annotation_notebook GROUP BY notebook_id) AS counts ON notebook._id = counts.notebook_id WHERE notebook.status = '' \(inClause) ORDER BY counts.cnt DESC, notebook.name ASC"
        
        do {
            return try db.prepare(statement).flatMap { bindings in
                guard let id = bindings[0] as? Int64, uniqueID = bindings[1] as? String, name = bindings[2] as? String, lastModifiedString = bindings[5] as? String, lastModifiedDate = dateFormatter.dateFromString(lastModifiedString) else { return nil }
                
                return Notebook(id: id, uniqueID: uniqueID, name: name, description: bindings[3] as? String, status: .Active, lastModified: lastModifiedDate)
            }
        } catch {
            return []
        }
    }
    
    func updateLastModifiedDate(notebookID id: Int64, status: AnnotationStatus? = nil, source: NotificationSource) throws {
        // Don't overwrite last modified during sync
        guard source == .Local else { return }
        
        try inTransaction(source) {
            if let status = status {
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                    NotebookTable.lastModified <- NSDate(),
                    NotebookTable.status <- status
                ))
            } else {
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                    NotebookTable.lastModified <- NSDate()
                ))
            }

            try self.notifyModifiedNotebooksWithIDs([id], source: source)
        }
    }
    
    public func trashNotebookWithID(id: Int64, source: NotificationSource) throws {
        let annotationIDs = try db.prepare(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id)).map { $0[AnnotationNotebookTable.annotationID] }
        
        try inTransaction(source) {
            // Delete link between annotations and notebook
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id).delete())
            
            // Update lastmodified date and mark as trashed
            try self.updateLastModifiedDate(notebookID: id, status: .Trashed, source: source)
            
            // Mark any annotations associated with this notebook as changed (for sync)
            try annotationIDs.forEach { try self.updateLastModifiedDate(annotationID: $0, source: source) }
            
            try self.notifyModifiedNotebooksWithIDs([id], source: source)
        }
    }
    
    func deleteNotebookWithID(id: Int64, source: NotificationSource) throws {
        try inTransaction(source) {
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id).delete())
            try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).delete())
        }
    }
    
    func trashNotebooks(notebooks: [Notebook], source: NotificationSource) throws {
        try inTransaction(source) {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if notebook.status != .Active && notebook.status != .Trashed {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to trash a notebook that is not active or trashed.")
                }
                
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                    NotebookTable.status <- .Trashed,
                    NotebookTable.lastModified <- lastModified
                ))
                
                ids.append(notebook.id)
            }
            
            try self.notifyModifiedNotebooksWithIDs(ids, source: source)
        }
    }

    
    func deleteNotebooks(notebooks: [Notebook], source: NotificationSource) throws {
        try inTransaction(source) {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if notebook.status != .Trashed && notebook.status != .Deleted {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to delete a notebook that is not trashed or deleted.")
                }
                
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                    NotebookTable.status <- .Deleted,
                    NotebookTable.lastModified <- lastModified
                ))
                
                ids.append(notebook.id)
            }
            
            try self.notifyModifiedNotebooksWithIDs(ids, source: source)
        }
    }

    
    func restoreNotebooks(notebooks: [Notebook], source: NotificationSource) throws {
        try inTransaction(source) {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                    NotebookTable.status <- .Active,
                    NotebookTable.lastModified <- lastModified
                ))
                
                ids.append(notebook.id)
            }
            
            try self.notifyModifiedNotebooksWithIDs(ids, source: source)
        }
    }
    
}

// MARK: Notifications

extension AnnotationStore {
    
    func notifyModifiedNotebooksWithIDs(ids: [Int64], source: NotificationSource) throws {
        let inTransactionKey: String
        
        switch source {
        case .Local:
            inTransactionKey = inLocalTransactionKey
            guard NSThread.currentThread().threadDictionary[inSyncTransactionKey] == nil else {
                throw Error.errorWithCode(.TransactionError, failureReason: "A local transaction cannot be started in a sync transaction")
            }
        case .Sync:
            inTransactionKey = inSyncTransactionKey
            guard NSThread.currentThread().threadDictionary[inLocalTransactionKey] == nil else {
                throw Error.errorWithCode(.TransactionError, failureReason: "A sync transaction cannot be started in a local transaction")
            }
        }

        if NSThread.currentThread().threadDictionary[inTransactionKey] != nil {
            changedNotebookIDs.unionInPlace(ids)
        } else {
            // Immediately notify about these modified notebooks when outside of a transaction
            notebookObservers.notify((source: source, notebookIDs: Set(ids)))
        }
    }
    
}
