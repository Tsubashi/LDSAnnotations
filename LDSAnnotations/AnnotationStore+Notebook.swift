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
    static let lastModified = Expression<Date>("last_modified")
    
    static func fromRow(_ row: Row) -> Notebook {
        return Notebook(id: row[id], uniqueID: row[uniqueID], name: row[name], description: row[description], status: row.get(status), lastModified: row[lastModified])
    }
    
}

// MARK: Public

public extension AnnotationStore {

    /// Returns the number of active notebooks.
    public func notebookCount() -> Int {
        return (try? db.scalar(NotebookTable.table.filter(NotebookTable.status == .active).count)) ?? 0
    }

    /// Adds a new notebook with `name`.
    @discardableResult public func addNotebook(name: String, description: String? = nil) throws -> Notebook {
        return try addNotebook(uniqueID: nil, name: name, description: description, status: .active, lastModified: nil, source: .local)
    }
    
    public func trashNotebookWithID(_ id: Int64) throws {
        try trashNotebookWithID(id, source: .local)
    }

    /// Returns the number of trashed notebooks.
    public func trashedNotebookCount() -> Int {
        return (try? db.scalar(NotebookTable.table.filter(NotebookTable.status == .trashed).count)) ?? 0
    }

    /// Saves any changes to `notebook` and updates the `lastModified`.
    @discardableResult public func updateNotebook(_ notebook: Notebook) throws -> Notebook {
        return try updateNotebook(notebook, source: .local)
    }
    
    /// Returns a list of active notebooks, order by OrderBy.
    public func notebooks(ids: [Int64]? = nil, orderBy: OrderBy = .name) -> [Notebook] {
        guard orderBy != .numberOfAnnotations else { return notebooksOrderedByCount(ids: ids) }
        
        var query = NotebookTable.table.filter(NotebookTable.status == .active)
        if let ids = ids {
            query = query.filter(ids.contains(NotebookTable.id))
        }
        
        switch orderBy {
        case .name:
            query = query.order(NotebookTable.name.asc)
        case .mostRecent:
            query = query.order(NotebookTable.lastModified.desc)
        case .numberOfAnnotations:
            break
        }
        
        do {
            return try db.prepare(query).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns the number of notebooks modified after lastModifiedAfter date with status
    public func numberOfUnsyncedNotebooks(lastModifiedAfter: Date? = nil) -> Int {
        var query = NotebookTable.table
        if let lastModifiedAfter = lastModifiedAfter {
            query = query.filter(NotebookTable.lastModified > lastModifiedAfter)
        }
        return (try? db.scalar(query.count)) ?? 0
    }
    
    /// Returns all notebooks with ids, after lastModifiedAfter and before lastModifiedOnOrBefore
    public func allNotebooks(ids: [Int64]? = nil, lastModifiedAfter: Date? = nil, lastModifiedOnOrBefore: Date? = nil) -> [Notebook] {
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
    public func notebookWithUniqueID(_ uniqueID: String) -> Notebook? {
        do {
            return try db.pluck(NotebookTable.table.filter(NotebookTable.uniqueID == uniqueID)).map { NotebookTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns a notebook with ID
    public func notebookWithID(_ id: Int64) -> Notebook? {
        do {
            return try db.pluck(NotebookTable.table.filter(NotebookTable.id == id)).map { NotebookTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns notebooks with annotationID
    public func notebooksWithAnnotationID(_ annotationID: Int64) -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID), on: NotebookTable.id == AnnotationNotebookTable.notebookID).order(AnnotationNotebookTable.displayOrder.asc)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns notebook IDs by annotationID
    func notebookIDsWithAnnotationIDsIn(_ annotationIDs: [Int64]) -> [Int64: [Int64]] {
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
            return try db.prepare(NotebookTable.table.filter(NotebookTable.status == .trashed)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }

    /// Trashes the `notebooks`; throws if any of the `notebooks` are not active or trashed.
    func trashNotebooks(_ notebooks: [Notebook]) throws {
        try trashNotebooks(notebooks, source: .local)
    }
    
    /// Deletes the `notebooks`; throws if any of the `notebooks` are not trashed or deleted.
    public func deleteNotebooks(_ notebooks: [Notebook]) throws {
        try deleteNotebooks(notebooks, source: .local)
    }
    
    /// Restores the `notebooks` to active.
    public func restoreNotebooks(_ notebooks: [Notebook]) throws {
        try restoreNotebooks(notebooks, source: .local)
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
    
    @discardableResult func addNotebook(uniqueID: String? = nil, name: String, description: String? = nil, status: AnnotationStatus = .active, lastModified: Date? = nil, source: NotificationSource) throws -> Notebook {
        guard !name.isEmpty else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a notebook without a name.")
        }
        
        let uniqueID = uniqueID ?? UUID().uuidString
        let lastModified = lastModified ?? Date()
        
        return try inTransaction(notificationSource: source) {
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
    
    @discardableResult func updateNotebook(_ notebook: Notebook, source: NotificationSource) throws -> Notebook {
        guard notebook.name.length > 0 else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot update a notebook without a name.")
        }
        
        var modifiedNotebook = notebook
        modifiedNotebook.lastModified = Date()
        
        return try inTransaction(notificationSource: source) {
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
    
    func deletedNotebooks(lastModifiedOnOrBefore: Date) -> [Notebook] {
        do {
            return try db.prepare(NotebookTable.table.filter(NotebookTable.lastModified <= lastModifiedOnOrBefore && NotebookTable.status == .deleted)).map { NotebookTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active notebooks order by number of annotations in notebook descending.
    fileprivate func notebooksOrderedByCount(ids: [Int64]? = nil) -> [Notebook] {
        let inClause: String = {
            guard let ids = ids else { return "" }
            
            return String(format: "AND notebook._id IN (%@)", ids.map({ String($0) }).joined(separator: ","))
        }()
        
        let statement = "SELECT notebook.* FROM notebook LEFT JOIN (SELECT notebook_id, count(annotation_id) AS cnt FROM annotation_notebook GROUP BY notebook_id) AS counts ON notebook._id = counts.notebook_id WHERE notebook.status = '' \(inClause) ORDER BY counts.cnt DESC, notebook.name ASC"
        
        do {
            return try db.prepare(statement).flatMap { bindings in
                guard let id = bindings[0] as? Int64, let uniqueID = bindings[1] as? String, let name = bindings[2] as? String, let lastModifiedString = bindings[5] as? String, let lastModifiedDate = dateFormatter.date(from: lastModifiedString) else { return nil }
                
                return Notebook(id: id, uniqueID: uniqueID, name: name, description: bindings[3] as? String, status: .active, lastModified: lastModifiedDate)
            }
        } catch {
            return []
        }
    }
    
    func updateLastModifiedDate(notebookID id: Int64, status: AnnotationStatus? = nil, source: NotificationSource) throws {
        // Don't overwrite last modified during sync
        guard source == .local else { return }
        
        try inTransaction(notificationSource: source) {
            if let status = status {
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                    NotebookTable.lastModified <- Date(),
                    NotebookTable.status <- status
                ))
            } else {
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).update(
                    NotebookTable.lastModified <- Date()
                ))
            }

            try self.notifyModifiedNotebooksWithIDs([id], source: source)
        }
    }
    
    public func trashNotebookWithID(_ id: Int64, source: NotificationSource) throws {
        let annotationIDs = try db.prepare(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id)).map { $0[AnnotationNotebookTable.annotationID] }
        
        try inTransaction(notificationSource: source) {
            // Delete link between annotations and notebook
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id).delete())
            
            // Update lastmodified date and mark as trashed
            try self.updateLastModifiedDate(notebookID: id, status: .trashed, source: source)
            
            // Mark any annotations associated with this notebook as changed (for sync)
            try annotationIDs.forEach { try self.updateLastModifiedDate(annotationID: $0, source: source) }
            
            try self.notifyModifiedNotebooksWithIDs([id], source: source)
        }
    }
    
    func deleteNotebookWithID(_ id: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id).delete())
            try self.db.run(NotebookTable.table.filter(NotebookTable.id == id).delete())
        }
    }
    
    func trashNotebooks(_ notebooks: [Notebook], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let lastModified = Date()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if notebook.status != .active && notebook.status != .trashed {
                    throw AnnotationError.errorWithCode(.unknown, failureReason: "Attempted to trash a notebook that is not active or trashed.")
                }
                
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                    NotebookTable.status <- .trashed,
                    NotebookTable.lastModified <- lastModified
                ))
                
                ids.append(notebook.id)
            }
            
            try self.notifyModifiedNotebooksWithIDs(ids, source: source)
        }
    }

    
    func deleteNotebooks(_ notebooks: [Notebook], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let lastModified = Date()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                if notebook.status != .trashed && notebook.status != .deleted {
                    throw AnnotationError.errorWithCode(.unknown, failureReason: "Attempted to delete a notebook that is not trashed or deleted.")
                }
                
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                    NotebookTable.status <- .deleted,
                    NotebookTable.lastModified <- lastModified
                ))
                
                ids.append(notebook.id)
            }
            
            try self.notifyModifiedNotebooksWithIDs(ids, source: source)
        }
    }

    
    func restoreNotebooks(_ notebooks: [Notebook], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let lastModified = Date()
            
            var ids = [Int64]()
            
            // Fetch the current status of the notebooks
            for notebook in self.allNotebooks(ids: notebooks.flatMap { $0.id }) {
                try self.db.run(NotebookTable.table.filter(NotebookTable.id == notebook.id).update(
                    NotebookTable.status <- .active,
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
    
    func notifyModifiedNotebooksWithIDs(_ ids: [Int64], source: NotificationSource) throws {
        let inTransactionKey: String
        
        switch source {
        case .local:
            inTransactionKey = inLocalTransactionKey
            guard Thread.current.threadDictionary[inSyncTransactionKey] == nil else {
                throw AnnotationError.errorWithCode(.transactionError, failureReason: "A local transaction cannot be started in a sync transaction")
            }
        case .sync:
            inTransactionKey = inSyncTransactionKey
            guard Thread.current.threadDictionary[inLocalTransactionKey] == nil else {
                throw AnnotationError.errorWithCode(.transactionError, failureReason: "A sync transaction cannot be started in a local transaction")
            }
        }

        if Thread.current.threadDictionary[inTransactionKey] != nil {
            changedNotebookIDs.formUnion(ids)
        } else {
            // Immediately notify about these modified notebooks when outside of a transaction
            notebookObservers.notify((source: source, notebookIDs: Set(ids)))
        }
    }
    
}
