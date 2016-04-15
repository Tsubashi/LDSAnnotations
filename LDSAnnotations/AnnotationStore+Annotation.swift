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

class AnnotationTable {
    
    static let table = Table("annotation")
    static let id = Expression<Int64>("_id")
    static let uniqueID = Expression<String>("unique_id")
    static let iso639_3Code = Expression<String>("iso639_3")
    static let docID = Expression<String>("doc_id")
    static let docVersion = Expression<Int>("doc_version")
    static let type = Expression<AnnotationType>("type")
    static let status = Expression<AnnotationStatus>("status")
    static let created = Expression<NSDate?>("created")
    static let lastModified = Expression<NSDate>("last_modified")
    static let noteID = Expression<Int64?>("note_id")
    static let bookmarkID = Expression<Int64?>("bookmark_id")
    static let source = Expression<String?>("source")
    static let device = Expression<String?>("device")
    
    static func fromRow(row: Row) -> Annotation {
        return Annotation(id: row[id],
            uniqueID: row[uniqueID],
            iso639_3Code: row[iso639_3Code],
            docID: row[docID],
            docVersion: row[docVersion],
            type: row.get(type),
            status: row.get(status),
            created: row[created],
            lastModified: row[lastModified],
            noteID: row[noteID],
            bookmarkID: row[bookmarkID],
            source: row[source],
            device: row[device]
        )
    }
    
}

extension AnnotationStore {
    
    func createAnnotationTable() throws {
        try self.db.run(AnnotationTable.table.create(ifNotExists: true) { builder in
            builder.column(AnnotationTable.id, primaryKey: true)
            builder.column(AnnotationTable.uniqueID)
            builder.column(AnnotationTable.iso639_3Code)
            builder.column(AnnotationTable.docID)
            builder.column(AnnotationTable.docVersion)
            builder.column(AnnotationTable.type)
            builder.column(AnnotationTable.status)
            builder.column(AnnotationTable.created)
            builder.column(AnnotationTable.lastModified)
            builder.column(AnnotationTable.noteID, references: NoteTable.table, NoteTable.id)
            builder.column(AnnotationTable.bookmarkID, references: BookmarkTable.table, BookmarkTable.id)
            builder.column(AnnotationTable.source)
            builder.column(AnnotationTable.device)
        })
    }

    /// Returns the number of active annotations.
    public func annotationCount() -> Int {
        return db.scalar(AnnotationTable.table.filter(AnnotationTable.status == .Active).count)
    }
    
    /// Returns an unordered list of active annotations.
    public func annotations() -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(AnnotationTable.status == .Active)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Adds a new annotation.
    public func addAnnotation(iso639_3Code: String, docID: String, docVersion: Int, type: AnnotationType, source: String) throws -> Annotation {
        guard !iso639_3Code.isEmpty && !docID.isEmpty && docVersion > 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add an annotation without an iso code, doc ID and doc version.")
        }
        
        let annotation = Annotation(id: nil, uniqueID: NSUUID().UUIDString, iso639_3Code: iso639_3Code, docID: docID, docVersion: docVersion, type: type, status: .Active, created: NSDate(), lastModified: NSDate(), noteID: nil, bookmarkID: nil, source: source, device: "iphone")
        
        let id = try db.run(AnnotationTable.table.insert(
            AnnotationTable.uniqueID <- annotation.uniqueID,
            AnnotationTable.iso639_3Code <- annotation.iso639_3Code,
            AnnotationTable.docID <- annotation.docID,
            AnnotationTable.docVersion <- annotation.docVersion,
            AnnotationTable.type <- annotation.type,
            AnnotationTable.status <- annotation.status,
            AnnotationTable.created <- annotation.created,
            AnnotationTable.lastModified <- annotation.lastModified,
            AnnotationTable.source <- annotation.source,
            AnnotationTable.device <- annotation.device
        ))
        
        notifyModifiedAnnotationsWithIDs([id])
        
        var modifiedAnnotation = annotation
        modifiedAnnotation.id = id
        return modifiedAnnotation
    }
    
    /// Saves any changes to `annotation` and updates the `lastModified`.
    public func updateAnnotation(annotation: Annotation) throws -> Annotation {
        guard !annotation.iso639_3Code.isEmpty && !annotation.docID.isEmpty && annotation.docVersion > 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add an annotation without an iso code, doc ID and doc version.")
        }
        
        var modifiedAnnotation = annotation
        modifiedAnnotation.lastModified = NSDate()
        
        guard let id = annotation.id else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot update a annotation without an ID.")
        }
        
        try db.run(AnnotationTable.table.filter(AnnotationTable.id == id).update(
            AnnotationTable.uniqueID <- modifiedAnnotation.uniqueID,
            AnnotationTable.iso639_3Code <- modifiedAnnotation.iso639_3Code,
            AnnotationTable.docID <- modifiedAnnotation.docID,
            AnnotationTable.docVersion <- modifiedAnnotation.docVersion,
            AnnotationTable.type <- modifiedAnnotation.type,
            AnnotationTable.status <- modifiedAnnotation.status,
            AnnotationTable.lastModified <- modifiedAnnotation.lastModified,
            AnnotationTable.noteID <- modifiedAnnotation.noteID,
            AnnotationTable.bookmarkID <- modifiedAnnotation.bookmarkID,
            AnnotationTable.source <- modifiedAnnotation.source,
            AnnotationTable.device <- modifiedAnnotation.device
        ))
        
        notifyModifiedAnnotationsWithIDs([id])
        
        return modifiedAnnotation
    }
    
    /// Returns the number of trashed annotations.
    public func trashedAnnotationCount() -> Int {
        return db.scalar(AnnotationTable.table.filter(AnnotationTable.status == .Trashed).count)
    }
    
    /// Returns an unordered list of trashed annotations.
    public func trashedAnnotations() -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(AnnotationTable.status == .Trashed)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Trashes the `annotations`; throws if any of the `annotations` are not active or trashed.
    public func trashAnnotations(annotations: [Annotation]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the annotations
            for annotation in self.allAnnotations(ids: annotations.flatMap { $0.id }) {
                if annotation.status != .Active && annotation.status != .Trashed {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to trash a annotation that is not active and not trashed (i.e. deleted).")
                }
                
                if let id = annotation.id {
                    try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == id).update(
                        AnnotationTable.status <- .Trashed,
                        AnnotationTable.lastModified <- lastModified
                    ))
                    
                    ids.append(id)
                }
            }
            
            self.notifyModifiedAnnotationsWithIDs(ids)
        }
    }
    
    /// Deletes the `annotations`; throws if any of the `annotations` are not trashed or deleted.
    public func deleteAnnotations(annotations: [Annotation]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the annotations
            for annotation in self.allAnnotations(ids: annotations.flatMap { $0.id }) {
                if annotation.status == .Active {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to delete a annotation that is not trashed and not deleted.")
                }
                
                if let id = annotation.id {
                    try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == id).update(
                        AnnotationTable.status <- .Deleted,
                        AnnotationTable.lastModified <- lastModified
                    ))
                    
                    ids.append(id)
                }
            }
            
            self.notifyModifiedAnnotationsWithIDs(ids)
        }
    }
    
    /// Restores the `annotations` to active.
    public func restoreAnnotations(annotations: [Annotation]) throws {
        try inTransaction {
            let lastModified = NSDate()
            
            var ids = [Int64]()
            
            // Fetch the current status of the annotations
            for annotation in self.allAnnotations(ids: annotations.flatMap { $0.id }) {
                if let id = annotation.id {
                    try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == id).update(
                        AnnotationTable.status <- .Active,
                        AnnotationTable.lastModified <- lastModified
                    ))
                    
                    ids.append(id)
                }
            }
            
            self.notifyModifiedAnnotationsWithIDs(ids)
        }
    }
    
    func allAnnotations(ids ids: [Int64]? = nil, lastModifiedAfter: NSDate? = nil, lastModifiedOnOrBefore: NSDate? = nil) -> [Annotation] {
        do {
            var query = AnnotationTable.table
            if let ids = ids {
                query = query.filter(ids.contains(AnnotationTable.id))
            }
            if let lastModifiedAfter = lastModifiedAfter {
                query = query.filter(AnnotationTable.lastModified > lastModifiedAfter)
            }
            if let lastModifiedOnOrBefore = lastModifiedOnOrBefore {
                query = query.filter(AnnotationTable.lastModified <= lastModifiedOnOrBefore)
            }
            return try db.prepare(query).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func deletedAnnotations(lastModifiedOnOrBefore lastModifiedOnOrBefore: NSDate) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(AnnotationTable.status == .Deleted && AnnotationTable.lastModified <= lastModifiedOnOrBefore)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func annotationWithUniqueID(uniqueID: String) -> Annotation? {
        return db.pluck(AnnotationTable.table.filter(AnnotationTable.uniqueID == uniqueID)).map { AnnotationTable.fromRow($0) }
    }
    
    func addOrUpdateAnnotation(annotation: Annotation) -> Annotation? {
        do {
            if let id = annotation.id {
                try db.run(AnnotationTable.table.filter(AnnotationTable.id == id).update(
                    AnnotationTable.uniqueID <- annotation.uniqueID,
                    AnnotationTable.iso639_3Code <- annotation.iso639_3Code,
                    AnnotationTable.docID <- annotation.docID,
                    AnnotationTable.docVersion <- annotation.docVersion,
                    AnnotationTable.type <- annotation.type,
                    AnnotationTable.status <- annotation.status,
                    AnnotationTable.created <- annotation.created,
                    AnnotationTable.lastModified <- annotation.lastModified,
                    AnnotationTable.noteID <- annotation.noteID,
                    AnnotationTable.bookmarkID <- annotation.bookmarkID,
                    AnnotationTable.source <- annotation.source,
                    AnnotationTable.device <- annotation.device
                ))
                
                notifySyncModifiedAnnotationsWithIDs([id])
                
                return annotation
            } else {
                let id = try db.run(AnnotationTable.table.insert(
                    AnnotationTable.uniqueID <- annotation.uniqueID,
                    AnnotationTable.iso639_3Code <- annotation.iso639_3Code,
                    AnnotationTable.docID <- annotation.docID,
                    AnnotationTable.docVersion <- annotation.docVersion,
                    AnnotationTable.type <- annotation.type,
                    AnnotationTable.status <- annotation.status,
                    AnnotationTable.lastModified <- annotation.lastModified,
                    AnnotationTable.source <- annotation.source,
                    AnnotationTable.device <- annotation.device
                ))
                
                notifySyncModifiedAnnotationsWithIDs([id])
                
                return Annotation(id: id, uniqueID: annotation.uniqueID, iso639_3Code: annotation.iso639_3Code, docID: annotation.docID, docVersion: annotation.docVersion, type: annotation.type, status: annotation.status, created: annotation.created, lastModified: annotation.lastModified, noteID: annotation.noteID, bookmarkID: annotation.bookmarkID, source: annotation.source, device: annotation.device)
            }
        } catch {
            return nil
        }
    }
    
    public func annotationsWithNotebookID(notebookID: Int64) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == notebookID), on: AnnotationTable.id == AnnotationNotebookTable.annotationID).order(AnnotationNotebookTable.displayOrder.asc)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func deleteAnnotationWithID(id: Int64) {
        do {
            try db.run(AnnotationTable.table.filter(AnnotationTable.id == id).delete())
            notifySyncModifiedAnnotationsWithIDs([id])
        } catch {}
    }
    
}

// MARK: Notifications

extension AnnotationStore {
    
    func notifyModifiedAnnotationsWithIDs(ids: [Int64]) {
        let inSyncTransactionKey = "sync-txn:\(unsafeAddressOf(self))"
        guard NSThread.currentThread().threadDictionary[inSyncTransactionKey] == nil else {
            fatalError("A local transaction cannot be started in a sync transaction")
        }
        
        let inTransactionKey = "txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[inTransactionKey] != nil {
            let annotationIDsKey = "ids:\(unsafeAddressOf(self))"
            let annotationIDs = NSThread.currentThread().threadDictionary[annotationIDsKey] as? SetBox<Int64> ?? SetBox()
            annotationIDs.set.unionInPlace(ids)
            NSThread.currentThread().threadDictionary[annotationIDsKey] = annotationIDs
        } else {
            // Immediately notify about these modified annotations when outside of a transaction
            annotationObservers.notify((source: .Local, annotations: allAnnotations(ids: ids)))
        }
    }
    
    func notifySyncModifiedAnnotationsWithIDs(ids: [Int64]) {
        let inTransactionKey = "txn:\(unsafeAddressOf(self))"
        guard NSThread.currentThread().threadDictionary[inTransactionKey] == nil else {
            fatalError("A sync transaction cannot be started in a local transaction")
        }
        
        let inSyncTransactionKey = "sync-txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[inSyncTransactionKey] != nil {
            let annotationIDsKey = "ids:\(unsafeAddressOf(self))"
            let annotationIDs = NSThread.currentThread().threadDictionary[annotationIDsKey] as? SetBox<Int64> ?? SetBox()
            annotationIDs.set.unionInPlace(ids)
            NSThread.currentThread().threadDictionary[annotationIDsKey] = annotationIDs
        } else {
            // Immediately notify about these modified annotations when outside of a transaction
            annotationObservers.notify((source: .Sync, annotations: allAnnotations(ids: ids)))
        }
    }

}
