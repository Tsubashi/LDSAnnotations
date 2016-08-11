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
    static let docID = Expression<String?>("doc_id")
    static let docVersion = Expression<Int?>("doc_version")
    static let status = Expression<AnnotationStatus>("status")
    static let created = Expression<NSDate?>("created")
    static let lastModified = Expression<NSDate>("last_modified")
    static let source = Expression<String?>("source")
    static let device = Expression<String?>("device")
    
    static func fromRow(row: Row) -> Annotation {
        return Annotation(id: row[id],
            uniqueID: row[uniqueID],
            docID: row[docID],
            docVersion: row[docVersion],
            status: row.get(status),
            created: row[created],
            lastModified: row[lastModified],
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
            builder.column(AnnotationTable.docID)
            builder.column(AnnotationTable.docVersion)
            builder.column(AnnotationTable.status)
            builder.column(AnnotationTable.created)
            builder.column(AnnotationTable.lastModified)
            builder.column(AnnotationTable.source)
            builder.column(AnnotationTable.device)
        })
    }

    /// Returns the number of active annotations.
    public func annotationCount() -> Int {
        return db.scalar(AnnotationTable.table.filter(AnnotationTable.status == .Active).count)
    }
    
    /// Adds a new annotation.
    func addAnnotation(uniqueID uniqueID: String? = nil, docID: String?, docVersion: Int?, status: AnnotationStatus = .Active, created: NSDate? = nil, lastModified: NSDate? = nil, source: String, device: String, inSync: Bool = false) throws -> Annotation {
        let uniqueID = uniqueID ?? NSUUID().UUIDString
        let created = created ?? NSDate()
        let lastModified = lastModified ?? created
        
        let id = try db.run(AnnotationTable.table.insert(
            AnnotationTable.uniqueID <- uniqueID,
            AnnotationTable.docID <- docID,
            AnnotationTable.docVersion <- docVersion,
            AnnotationTable.status <- status,
            AnnotationTable.created <- created,
            AnnotationTable.lastModified <- lastModified,
            AnnotationTable.source <- source,
            AnnotationTable.device <- device
        ))
        
        if inSync {
            notifySyncModifiedAnnotationsWithIDs([id])
        } else {
            notifyModifiedAnnotationsWithIDs([id])
        }
        
        return Annotation(id: id, uniqueID: uniqueID, docID: docID, docVersion: docVersion, status: .Active, created: created, lastModified: lastModified, source: source, device: device)
    }
    
    /// Saves any changes to `annotation` and updates the `lastModified`.
    func updateAnnotation(annotation: Annotation, inSync: Bool = false) throws -> Annotation {
        var modifiedAnnotation = annotation
        modifiedAnnotation.lastModified = NSDate()
        
        try db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
            AnnotationTable.uniqueID <- modifiedAnnotation.uniqueID,
            AnnotationTable.docID <- modifiedAnnotation.docID,
            AnnotationTable.docVersion <- modifiedAnnotation.docVersion,
            AnnotationTable.status <- modifiedAnnotation.status,
            AnnotationTable.lastModified <- modifiedAnnotation.lastModified,
            AnnotationTable.source <- modifiedAnnotation.source,
            AnnotationTable.device <- modifiedAnnotation.device
        ))
        
        if inSync {
            notifySyncModifiedAnnotationsWithIDs([annotation.id])
        } else {
            notifyModifiedAnnotationsWithIDs([annotation.id])
        }
        
        return modifiedAnnotation
    }
    
    func updateLastModifiedDate(annotationID annotationID: Int64, status: AnnotationStatus? = nil) throws {
        if let status = status {
            try db.run(AnnotationTable.table.filter(AnnotationTable.id == annotationID).update(
                AnnotationTable.lastModified <- NSDate(),
                AnnotationTable.status <- status
            ))
        } else {
            try db.run(AnnotationTable.table.filter(AnnotationTable.id == annotationID).update(
                AnnotationTable.lastModified <- NSDate()
            ))
        }
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
                if annotation.status == .Deleted {
                    throw Error.errorWithCode(.Unknown, failureReason: "Attempted to trash a annotation that is not active and not trashed (i.e. deleted).")
                }
                
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                    AnnotationTable.status <- .Trashed,
                    AnnotationTable.lastModified <- lastModified
                ))
                
                ids.append(annotation.id)
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
                
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                    AnnotationTable.status <- .Deleted,
                    AnnotationTable.lastModified <- lastModified
                ))
                
                ids.append(annotation.id)
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
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                    AnnotationTable.status <- .Active,
                    AnnotationTable.lastModified <- lastModified
                ))
                
                ids.append(annotation.id)
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
    
    public func annotationWithUniqueID(uniqueID: String) -> Annotation? {
        return db.pluck(AnnotationTable.table.filter(AnnotationTable.uniqueID == uniqueID)).map { AnnotationTable.fromRow($0) }
    }
    
    public func annotationWithID(id: Int64) -> Annotation? {
        return db.pluck(AnnotationTable.table.filter(AnnotationTable.id == id)).map { AnnotationTable.fromRow($0) }
    }
    
    /// Returns a list of active annotations ordered by last modified.
    public func annotations(docID docID: String? = nil, paragraphAIDs: [String]? = nil) -> [Annotation] {
        var query = AnnotationTable.table.select(distinct: AnnotationTable.table[*]).filter(AnnotationTable.status == .Active).order(AnnotationTable.lastModified.desc)
        
        if let docID = docID {
            query = query.filter(AnnotationTable.docID == docID)
        }
        
        if let paragraphAIDs = paragraphAIDs where !paragraphAIDs.isEmpty {
            query = query.join(HighlightTable.table, on: HighlightTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(paragraphAIDs.contains(HighlightTable.paragraphAID))
        }
        
        do {
            return try db.prepare(query).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs associated with notebookID, ordered by display order
    public func annotationIDsForNotebookWithID(notebookID: Int64) -> [Int64] {
        do {
            return try db.prepare(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == notebookID && AnnotationTable.status == .Active).join(AnnotationTable.table, on: AnnotationTable.id == AnnotationNotebookTable.annotationID).order(AnnotationNotebookTable.displayOrder)).map { $0[AnnotationNotebookTable.annotationID] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs associated with tagID, ordered by last modified descending
    public func annotationIDsForTagWithID(tagID: Int64) -> [Int64] {
        do {
            return try db.prepare(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == tagID && AnnotationTable.status == .Active).join(AnnotationTable.table, on: AnnotationTagTable.annotationID == AnnotationTable.id).order(AnnotationTable.lastModified.desc)).map { $0[AnnotationTagTable.annotationID] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs for active annotations associated with tagID, ordered by last modified descending
    public func annotationIDs(limit limit: Int? = nil) -> [Int64] {
        do {
            var query = AnnotationTable.table.select(AnnotationTable.id, AnnotationTable.status, AnnotationTable.lastModified).filter(AnnotationTable.status == .Active).order(AnnotationTable.lastModified)
            if let limit = limit {
                query = query.limit(limit)
            }
            return try db.prepare(query).map { $0[AnnotationTable.id] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotations that are linked to the docID
    public func annotationsLinkedToDocID(docID: String) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.select(AnnotationTable.table[*]).join(LinkTable.table.filter(LinkTable.table[LinkTable.docID] == docID), on: LinkTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(AnnotationTable.status == .Active).order(AnnotationTable.lastModified)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotations in notebookID, ordered by display order
    public func annotationsWithNotebookID(id: Int64) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == id && AnnotationTable.status == .Active), on: AnnotationTable.id == AnnotationNotebookTable.annotationID).order(AnnotationNotebookTable.displayOrder.asc)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a the number of active annotations in notebook with ID
    public func numberOfAnnotations(notebookID notebookID: Int64? = nil) -> Int {
        var query = AnnotationTable.table.filter(AnnotationTable.status == .Active)
        if let notebookID = notebookID {
            query = query.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == notebookID), on: AnnotationTable.id == AnnotationNotebookTable.annotationID)
        }
        return db.scalar(query.count)
    }

    /// Returns a the number of unsynced annotations since date
    public func numberOfUnsyncedAnnotations(lastModifiedAfter lastModifiedAfter: NSDate? = nil) -> Int {
        var query = AnnotationTable.table
        if let lastModifiedAfter = lastModifiedAfter {
            query = query.filter(AnnotationTable.lastModified > lastModifiedAfter)
        }
        return db.scalar(query.count)
    }

    /// Returns a list of active annotations with tagID, ordered by last modified descending
    public func annotationsWithTagID(id: Int64) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.join(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id), on: AnnotationTable.id == AnnotationTagTable.annotationID).order(AnnotationTable.lastModified.desc)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns the annotation for bookmark with ID
    public func annotationWithBookmarkID(id: Int64) -> Annotation? {
        return db.pluck(AnnotationTable.table.select(AnnotationTable.table[*]).join(BookmarkTable.table.select(BookmarkTable.id, BookmarkTable.annotationID), on: BookmarkTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(BookmarkTable.table[BookmarkTable.id] == id)).map { AnnotationTable.fromRow($0) }
    }
    
    /// Returns the annotation for note with ID
    public func annotationWithNoteID(noteID: Int64) -> Annotation? {
        return db.pluck(AnnotationTable.table.select(AnnotationTable.table[*]).join(NoteTable.table.select(NoteTable.id, NoteTable.annotationID).filter(NoteTable.table[NoteTable.id] == noteID), on: NoteTable.annotationID == AnnotationTable.table[AnnotationTable.id])).map { AnnotationTable.fromRow($0) }
    }
    
    /// Returns the annotation for link with ID
    public func annotationWithLinkID(linkID: Int64) -> Annotation? {
        return db.pluck(AnnotationTable.table.select(AnnotationTable.table[*]).join(LinkTable.table.select(LinkTable.id, LinkTable.annotationID).filter(LinkTable.table[LinkTable.id] == linkID), on: LinkTable.annotationID == AnnotationTable.table[AnnotationTable.id])).map { AnnotationTable.fromRow($0) }
    }
    
    /// Returns a the number of active annotations with tag ID
    public func numberOfAnnotationsWithTagID(tagID: Int64) -> Int {
        return db.scalar(AnnotationTable.table.select(AnnotationTable.table[*]).filter(AnnotationTable.status == .Active).join(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == tagID), on: AnnotationTable.id == AnnotationTagTable.annotationID).count)
    }
    
    // Mark annotation as trashed, and delete any related annotation objects
    public func trashAnnotationWithID(id: Int64) throws {
        // In transaction so it will rollback if this fails
        try inTransaction {
            try self.updateLastModifiedDate(annotationID: id, status: .Trashed)
            try self.deleteHighlightsWithAnnotationID(id)
            try self.deleteNotesWithAnnotationID(id)
            try self.deleteLinksWithAnnotationID(id)
            try self.deleteBookmarksWithAnnotationID(id)
            try self.removeFromNotebooksAnnotationWithID(id)
            try self.removeFromTagsAnnotationWithID(id)
        }
    }
    
    /// Mark annotation as trashed if there are no more related annotation objects
    public func trashAnnotationIfEmptyWithID(id: Int64) throws {
        let notEmpty = [
            db.scalar(HighlightTable.table.filter(HighlightTable.annotationID == id).count),
            db.scalar(LinkTable.table.filter(LinkTable.annotationID == id).count),
            db.scalar(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == id).count),
            db.scalar(BookmarkTable.table.filter(BookmarkTable.annotationID == id).count),
            db.scalar(NoteTable.table.filter(NoteTable.annotationID == id).count)
        ].any { $0 > 0 }
        
        try updateLastModifiedDate(annotationID: id, status: notEmpty ? nil : .Trashed )
        
        notifyModifiedAnnotationsWithIDs([id])
    }
    
    func deleteAnnotationWithID(id: Int64) throws {
        // Don't put this in a transaction, becuause it currently only called from within an existing transaction
        try self.db.run(NoteTable.table.filter(NoteTable.annotationID == id).delete())
        try self.db.run(BookmarkTable.table.filter(BookmarkTable.annotationID == id).delete())
        try self.db.run(LinkTable.table.filter(LinkTable.annotationID == id).delete())
        try self.db.run(HighlightTable.table.filter(HighlightTable.annotationID == id).delete())
        try self.db.run(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == id).delete())
        try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == id).delete())
        try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == id).delete())
    }
    
    /// Creates a duplicate annotation, and duplicates all related annotation objects except for notebooks
    public func duplicateAnnotation(annotation: Annotation, source: String, device: String) throws -> Annotation {
        let duplicateAnnotation = try addAnnotation(docID: annotation.docID, docVersion: annotation.docVersion, source: source, device: device)
        
        for highlight in highlightsWithAnnotationID(annotation.id) {
            try addHighlight(paragraphRange: highlight.paragraphRange, colorName: highlight.colorName, style: highlight.style, annotationID: duplicateAnnotation.id)
        }
        
        for link in linksWithAnnotationID(annotation.id) {
            try addLink(name: link.name, docID: link.docID, docVersion: link.docVersion, paragraphAIDs: link.paragraphAIDs, annotationID: duplicateAnnotation.id)
        }
        
        if let note = noteWithAnnotationID(annotation.id) {
            try addNote(title: note.title, content: note.content, annotationID: duplicateAnnotation.id)
        }
        
        if let bookmark = bookmarkWithAnnotationID(annotation.id) {
            try addBookmark(name: bookmark.name, paragraphAID: bookmark.paragraphAID, displayOrder: bookmark.displayOrder, annotationID: duplicateAnnotation.id)
        }
        
        for tagID in tagsWithAnnotationID(annotation.id).flatMap({ $0.id }) {
            try addOrUpdateAnnotationTag(annotationID: duplicateAnnotation.id, tagID: tagID)
        }
        
        return duplicateAnnotation
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
            let annotationIDsKey = "annotationIDs:\(unsafeAddressOf(self))"
            let annotationIDs = NSThread.currentThread().threadDictionary[annotationIDsKey] as? SetBox<Int64> ?? SetBox()
            annotationIDs.set.unionInPlace(ids)
            NSThread.currentThread().threadDictionary[annotationIDsKey] = annotationIDs
        } else if !ids.isEmpty {
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
            let annotationIDsKey = "annotationIDs:\(unsafeAddressOf(self))"
            let annotationIDs = NSThread.currentThread().threadDictionary[annotationIDsKey] as? SetBox<Int64> ?? SetBox()
            annotationIDs.set.unionInPlace(ids)
            NSThread.currentThread().threadDictionary[annotationIDsKey] = annotationIDs
        } else if !ids.isEmpty {
            // Immediately notify about these modified annotations when outside of a transaction
            annotationObservers.notify((source: .Sync, annotations: allAnnotations(ids: ids)))
        }
    }

}
