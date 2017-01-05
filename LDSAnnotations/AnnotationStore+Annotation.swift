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
    static let created = Expression<Date?>("created")
    static let lastModified = Expression<Date>("last_modified")
    static let appSource = Expression<String?>("source")
    static let device = Expression<String?>("device")
    
    static func fromRow(_ row: Row) -> Annotation {
        return Annotation(id: row[id],
            uniqueID: row[uniqueID],
            docID: row[docID],
            docVersion: row[docVersion],
            status: row.get(status),
            created: row[created],
            lastModified: row[lastModified],
            appSource: row[appSource],
            device: row[device]
        )
    }
    
}


// MARK: Public

public extension AnnotationStore {
    
    /// Mark annotation as trashed if there are no more related annotation objects
    public func trashAnnotationIfEmpty(withID id: Int64) throws {
        return try trashAnnotationIfEmptyWithID(id, source: .local)
    }
    
    /// Returns the number of active annotations.
    public func annotationCount() -> Int {
        return (try? db.scalar(AnnotationTable.table.filter(AnnotationTable.status == .active).count)) ?? 0
    }
    
    /// Returns the number of trashed annotations.
    public func trashedAnnotationCount() -> Int {
        return (try? db.scalar(AnnotationTable.table.filter(AnnotationTable.status == .trashed).count)) ?? 0
    }
    
    /// Returns an unordered list of trashed annotations.
    public func trashedAnnotations() -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(AnnotationTable.status == .trashed)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Trashes the `annotations`; throws if any of the `annotations` are not active or trashed.
    public func trashAnnotations(_ annotations: [Annotation]) throws {
        try trashAnnotations(annotations, source: .local)
    }
    
    /// Returns a list of active annotations ordered by last modified.
    public func annotations(docID: String? = nil, paragraphAIDs: [String]? = nil) -> [Annotation] {
        var query = AnnotationTable.table.select(distinct: AnnotationTable.table[*]).filter(AnnotationTable.status == .active).order(AnnotationTable.lastModified.desc)
        
        if let docID = docID {
            query = query.filter(AnnotationTable.docID == docID)
        }
        
        if let paragraphAIDs = paragraphAIDs, !paragraphAIDs.isEmpty {
            query = query.join(HighlightTable.table, on: HighlightTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(paragraphAIDs.contains(HighlightTable.paragraphAID))
        }
        
        do {
            return try db.prepare(query).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns all annotation IDs associated with the given docIDs
    public func annotationIDsWithDocIDsIn(_ docIDs: [String]) -> [Int64] {
        do {
            return try db.prepare(AnnotationTable.table.select(AnnotationTable.id).filter(docIDs.contains(AnnotationTable.docID)).filter(AnnotationTable.status == .active)).map { $0[AnnotationTable.id] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs associated with notebookID, ordered by display order
    public func annotationIDsForNotebookWithID(_ notebookID: Int64) -> [Int64] {
        do {
            return try db.prepare(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == notebookID && AnnotationTable.status == .active).join(AnnotationTable.table, on: AnnotationTable.id == AnnotationNotebookTable.annotationID).order(AnnotationNotebookTable.displayOrder)).map { $0[AnnotationNotebookTable.annotationID] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs associated with tagID, ordered by last modified descending
    public func annotationIDsForTagWithID(_ tagID: Int64) -> [Int64] {
        do {
            return try db.prepare(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == tagID && AnnotationTable.status == .active).join(AnnotationTable.table, on: AnnotationTagTable.annotationID == AnnotationTable.id).order(AnnotationTable.lastModified.desc)).map { $0[AnnotationTagTable.annotationID] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs for active annotations associated with tagID, ordered by last modified descending
    public func annotationIDs(limit: Int? = nil) -> [Int64] {
        do {
            var query = AnnotationTable.table.select(AnnotationTable.id).filter(AnnotationTable.status == .active).order(AnnotationTable.lastModified)
            if let limit = limit {
                query = query.limit(limit)
            }
            return try db.prepare(query).map { $0[AnnotationTable.id] }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotation IDs for active annotations associated with tagID, ordered by last modified descending
    public func annotationIDsWithLastModified() -> [(Int64, Date)] {
        do {
            let query = AnnotationTable.table.select(AnnotationTable.id, AnnotationTable.lastModified).filter(AnnotationTable.status == .active).order(AnnotationTable.lastModified)
            return try db.prepare(query).map { ($0[AnnotationTable.id], $0[AnnotationTable.lastModified]) }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotations that are linked to the docID
    public func annotationsLinkedToDocID(_ docID: String) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.select(AnnotationTable.table[*]).join(LinkTable.table.filter(LinkTable.table[LinkTable.docID] == docID), on: LinkTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(AnnotationTable.status == .active).order(AnnotationTable.lastModified)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a list of active annotations in notebookID, ordered by display order
    public func annotationsWithNotebookID(_ id: Int64) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(AnnotationTable.status == .active).join(AnnotationNotebookTable.table, on: AnnotationTable.id == AnnotationNotebookTable.annotationID).filter(AnnotationNotebookTable.notebookID == id).order(AnnotationNotebookTable.displayOrder.asc)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns a the number of active annotations in notebook with ID
    public func numberOfAnnotations(notebookID: Int64? = nil) -> Int {
        var query = AnnotationTable.table.filter(AnnotationTable.status == .active)
        if let notebookID = notebookID {
            query = query.join(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.notebookID == notebookID), on: AnnotationTable.id == AnnotationNotebookTable.annotationID)
        }
        return (try? db.scalar(query.count)) ?? 0
    }
    
    /// Returns a the number of unsynced annotations since date
    public func numberOfUnsyncedAnnotations(lastModifiedAfter: Date? = nil) -> Int {
        var query = AnnotationTable.table
        if let lastModifiedAfter = lastModifiedAfter {
            query = query.filter(AnnotationTable.lastModified > lastModifiedAfter)
        }
        return (try? db.scalar(query.count)) ?? 0
    }
    
    /// Returns a list of active annotations with tagID, ordered by last modified descending
    public func annotationsWithTagID(_ id: Int64) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.join(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id), on: AnnotationTable.id == AnnotationTagTable.annotationID).order(AnnotationTable.lastModified.desc)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns the annotation for bookmark with ID
    public func annotationWithBookmarkID(_ id: Int64) -> Annotation? {
        do {
            return try db.pluck(AnnotationTable.table.select(AnnotationTable.table[*]).join(BookmarkTable.table.select(BookmarkTable.id, BookmarkTable.annotationID), on: BookmarkTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(BookmarkTable.table[BookmarkTable.id] == id)).map { AnnotationTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns the annotation for note with ID
    public func annotationWithNoteID(_ noteID: Int64) -> Annotation? {
        do {
            return try db.pluck(AnnotationTable.table.select(AnnotationTable.table[*]).join(NoteTable.table.select(NoteTable.id, NoteTable.annotationID).filter(NoteTable.table[NoteTable.id] == noteID), on: NoteTable.annotationID == AnnotationTable.table[AnnotationTable.id])).map { AnnotationTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns the annotation for link with ID
    public func annotationWithLinkID(_ linkID: Int64) -> Annotation? {
        do {
            return try db.pluck(AnnotationTable.table.select(AnnotationTable.table[*]).join(LinkTable.table.select(LinkTable.id, LinkTable.annotationID).filter(LinkTable.table[LinkTable.id] == linkID), on: LinkTable.annotationID == AnnotationTable.table[AnnotationTable.id])).map { AnnotationTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns a the number of active annotations with tag ID
    public func numberOfAnnotationsWithTagID(_ tagID: Int64) -> Int {
        return (try? db.scalar(AnnotationTable.table.select(AnnotationTable.table[*]).filter(AnnotationTable.status == .active).join(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == tagID), on: AnnotationTable.id == AnnotationTagTable.annotationID).count)) ?? 0
    }
    
    /// Creates a duplicate annotation, and duplicates all related annotation objects except for notebooks
    public func duplicateAnnotation(_ annotation: Annotation, appSource: String, device: String) throws -> Annotation {
        let source: NotificationSource = .local
        
        return try inTransaction(notificationSource: source) {
            let duplicateAnnotation = try self.addAnnotation(docID: annotation.docID, docVersion: annotation.docVersion, appSource: appSource, device: device, source: source)
            
            for highlight in self.highlightsWithAnnotationID(annotation.id) {
                try self.addHighlight(paragraphRange: highlight.paragraphRange, colorName: highlight.colorName, style: highlight.style, annotationID: duplicateAnnotation.id, source: source)
            }
            
            for link in self.linksWithAnnotationID(annotation.id) {
                try self.addLink(name: link.name, docID: link.docID, docVersion: link.docVersion, paragraphAIDs: link.paragraphAIDs, annotationID: duplicateAnnotation.id, source: source)
            }
            
            if let note = self.noteWithAnnotationID(annotation.id) {
                try self.addNote(title: note.title, content: note.content, annotationID: duplicateAnnotation.id, source: source)
            }
            
            if let bookmark = self.bookmarkWithAnnotationID(annotation.id) {
                try self.addBookmark(name: bookmark.name, paragraphAID: bookmark.paragraphAID, displayOrder: bookmark.displayOrder, annotationID: duplicateAnnotation.id, offset: bookmark.offset, source: source)
            }
            
            for tagID in self.tagsWithAnnotationID(annotation.id).flatMap({ $0.id }) {
                try self.addOrUpdateAnnotationTag(annotationID: duplicateAnnotation.id, tagID: tagID, source: source)
            }
            
            return duplicateAnnotation
        }
    }
    
    /// Mark annotation as trashed, and delete any related annotation objects
    public func trashAnnotationWithID(_ id: Int64) throws {
        try trashAnnotationWithID(id, source: .local)
    }
    
    /// Returns annotation with uniqueID
    public func annotationWithUniqueID(_ uniqueID: String) -> Annotation? {
        return (try? db.pluck(AnnotationTable.table.filter(AnnotationTable.uniqueID == uniqueID)).map { AnnotationTable.fromRow($0) }) ?? nil
    }
    
    /// Returns annotations with uniqueIDs
    public func annotationsWithUniqueIDsIn(_ uniqueIDs: [String]) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(uniqueIDs.contains(AnnotationTable.uniqueID))).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns annotation with ID
    public func annotationWithID(_ id: Int64) -> Annotation? {
        return (try? db.pluck(AnnotationTable.table.filter(AnnotationTable.id == id)).map { AnnotationTable.fromRow($0) }) ?? nil
    }
    
    /// Deletes the `annotations`; throws if any of the `annotations` are not trashed or deleted.
    public func deleteAnnotations(_ annotations: [Annotation]) throws {
        try deleteAnnotations(annotations, source: .local)
    }
    
    /// Restores the `annotations` to active.
    public func restoreAnnotations(_ annotations: [Annotation]) throws {
        try restoreAnnotations(annotations, source: .local)
    }
    
    /// Returns all annotations with IDs after lastModifiedAfter, and before lastModifiedOnOrBefore
    public func allAnnotations(ids: [Int64]? = nil, lastModifiedAfter: Date? = nil, lastModifiedOnOrBefore: Date? = nil) -> [Annotation] {
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
    
}

// MARK: Internal

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
            builder.column(AnnotationTable.appSource)
            builder.column(AnnotationTable.device)
        })
    }

    /// Adds a new annotation.
    func addAnnotation(uniqueID: String? = nil, docID: String?, docVersion: Int?, status: AnnotationStatus = .active, created: Date? = nil, lastModified: Date? = nil, appSource: String, device: String, source: NotificationSource) throws -> Annotation {
        let uniqueID = uniqueID ?? UUID().uuidString
        let created = created ?? Date()
        let lastModified = lastModified ?? created
        
        return try inTransaction(notificationSource: source) {
            let id = try self.db.run(AnnotationTable.table.insert(
                AnnotationTable.uniqueID <- uniqueID,
                AnnotationTable.docID <- docID,
                AnnotationTable.docVersion <- docVersion,
                AnnotationTable.status <- status,
                AnnotationTable.created <- created,
                AnnotationTable.lastModified <- lastModified,
                AnnotationTable.appSource <- appSource,
                AnnotationTable.device <- device
            ))
            
            // Sync notifies once at the end
            if case .local = source {
                try self.notifyModifiedAnnotationsWithIDs([id], source: source)
            }
            
            return Annotation(id: id, uniqueID: uniqueID, docID: docID, docVersion: docVersion, status: .active, created: created, lastModified: lastModified, appSource: appSource, device: device)
        }
    }
    
    /// Saves any changes to `annotation` and updates the `lastModified`.
    @discardableResult func updateAnnotation(_ annotation: Annotation, source: NotificationSource) throws -> Annotation {
        
        return try inTransaction(notificationSource: source) {
            try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                AnnotationTable.uniqueID <- annotation.uniqueID,
                AnnotationTable.docID <- annotation.docID,
                AnnotationTable.docVersion <- annotation.docVersion,
                AnnotationTable.status <- annotation.status,
                AnnotationTable.lastModified <- annotation.lastModified,
                AnnotationTable.appSource <- annotation.appSource,
                AnnotationTable.device <- annotation.device
            ))
            
            // Sync notifies once at the end
            if case .local = source {
                try self.notifyModifiedAnnotationsWithIDs([annotation.id], source: source)
            }
            
            return annotation
        }
    }
    
    func updateLastModifiedDate(annotationID: Int64, status: AnnotationStatus? = nil, source: NotificationSource) throws {
        // Don't overwrite last modified during sync
        guard source == .local else { return }
        
        try inTransaction(notificationSource: source) {
            if let status = status {
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotationID).update(
                    AnnotationTable.lastModified <- Date(),
                    AnnotationTable.status <- status
                ))
            } else {
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotationID).update(
                    AnnotationTable.lastModified <- Date()
                ))
            }

            try self.notifyModifiedAnnotationsWithIDs([annotationID], source: source)
        }
    }
    
    func trashAnnotations(_ annotations: [Annotation], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let lastModified = Date()
            
            var ids = [Int64]()
            
            // Fetch the current status of the annotations
            for annotation in self.allAnnotations(ids: annotations.flatMap { $0.id }) {
                if annotation.status == .deleted {
                    throw AnnotationError.errorWithCode(.unknown, failureReason: "Attempted to trash a annotation that is not active and not trashed (i.e. deleted).")
                }
                
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                    AnnotationTable.status <- .trashed,
                    AnnotationTable.lastModified <- lastModified
                ))
                
                ids.append(annotation.id)
            }
            
            try self.notifyModifiedAnnotationsWithIDs(ids, source: source)
        }
    }
    
    func deletedAnnotations(lastModifiedOnOrBefore: Date) -> [Annotation] {
        do {
            return try db.prepare(AnnotationTable.table.filter(AnnotationTable.status == .deleted && AnnotationTable.lastModified <= lastModifiedOnOrBefore)).map { AnnotationTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func trashAnnotationWithID(_ id: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.deleteHighlightsWithAnnotationID(id, source: source)
            try self.deleteNotesWithAnnotationID(id, source: source)
            try self.deleteLinksWithAnnotationID(id, source: source)
            try self.deleteBookmarksWithAnnotationID(id, source: source)
            try self.removeFromNotebooksAnnotationWithID(id, source: source)
            try self.removeFromTagsAnnotationWithID(id, source: source)
            try self.updateLastModifiedDate(annotationID: id, status: .trashed, source: source)
        }
    }
    
    func trashAnnotationIfEmptyWithID(_ id: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let statement = "SELECT COUNT(annotation_id) FROM highlight WHERE annotation_id = @annotationID AND style != @style UNION ALL SELECT COUNT(annotation_id) FROM link WHERE annotation_id = @annotationID UNION ALL SELECT COUNT(annotation_id) FROM annotation_tag WHERE annotation_id = @annotationID UNION ALL SELECT COUNT(annotation_id) FROM bookmark WHERE annotation_id = @annotationID UNION ALL SELECT COUNT(annotation_id) FROM note WHERE annotation_id = @annotationID;"
            let bindings: [String: Binding?] = ["@annotationID": id, "@style": HighlightStyle.clear.rawValue]
            let notEmpty = try self.db.prepare(statement, bindings).flatMap { row in
                return row[0] as? Int64
            }.any { $0 > 0 }

            try self.updateLastModifiedDate(annotationID: id, status: notEmpty ? nil : .trashed, source: source)
        }
    }
    
    func deleteAnnotationWithID(_ id: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(NoteTable.table.filter(NoteTable.annotationID == id).delete())
            try self.db.run(BookmarkTable.table.filter(BookmarkTable.annotationID == id).delete())
            try self.db.run(LinkTable.table.filter(LinkTable.annotationID == id).delete())
            try self.db.run(HighlightTable.table.filter(HighlightTable.annotationID == id).delete())
            try self.db.run(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == id).delete())
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == id).delete())
            try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == id).delete())
        }
    }
    
    func deleteAnnotations(_ annotations: [Annotation], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let lastModified = Date()
            
            var ids = [Int64]()
            
            // Fetch the current status of the annotations
            for annotation in self.allAnnotations(ids: annotations.flatMap { $0.id }) {
                if annotation.status == .active {
                    throw AnnotationError.errorWithCode(.unknown, failureReason: "Attempted to delete a annotation that is not trashed and not deleted.")
                }
                
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                    AnnotationTable.status <- .deleted,
                    AnnotationTable.lastModified <- lastModified
                ))
                
                ids.append(annotation.id)
            }
            
            try self.notifyModifiedAnnotationsWithIDs(ids, source: source)
        }
    }
    
    func restoreAnnotations(_ annotations: [Annotation], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            let lastModified = Date()
            
            var ids = [Int64]()
            
            // Fetch the current status of the annotations
            for annotation in self.allAnnotations(ids: annotations.flatMap { $0.id }) {
                try self.db.run(AnnotationTable.table.filter(AnnotationTable.id == annotation.id).update(
                    AnnotationTable.status <- .active,
                    AnnotationTable.lastModified <- lastModified
                ))
                
                ids.append(annotation.id)
            }
            
            try self.notifyModifiedAnnotationsWithIDs(ids, source: source)
        }
    }
    
}

// MARK: Notifications

extension AnnotationStore {
    
    func notifyModifiedAnnotationsWithIDs(_ ids: [Int64], source: NotificationSource) throws {
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
            changedAnnotationIDs.formUnion(ids)
        } else if !ids.isEmpty {
            // Immediately notify about these modified annotations when outside of a transaction
            annotationObservers.notify((source: source, annotationIDs: Set(ids)))
        }
    }
    
}
