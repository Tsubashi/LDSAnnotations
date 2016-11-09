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

// MARK: BookmarkTable

class BookmarkTable {
    
    static let table = Table("bookmark")
    static let id = Expression<Int64>("_id")
    static let name = Expression<String?>("name")
    static let paragraphAID = Expression<String?>("paragraph_aid")
    static let displayOrder = Expression<Int?>("display_order")
    static let annotationID = Expression<Int64>("annotation_id")
    static let offset = Expression<Int>("offset")
    
    static func fromRow(_ row: Row) -> Bookmark {
        return Bookmark(id: row[id],
            name: row[name],
            paragraphAID: row[paragraphAID],
            displayOrder: row[displayOrder],
            annotationID: row[annotationID],
            offset: row[offset])
    }
    
}

// MARK: Public

public extension AnnotationStore {

    /// Returns a bookmark, and creates related annotation object
    @discardableResult public func addBookmark(name: String?, paragraphAID: String?, displayOrder: Int, docID: String, docVersion: Int, appSource: String, device: String) throws -> Bookmark {
        return try addBookmark(name: name, paragraphAID: paragraphAID, displayOrder: displayOrder, docID: docID, docVersion: docVersion, appSource: appSource, device: device, source: .local)
    }
    
    /// Returns a bookmark after updating it
    @discardableResult public func updateBookmark(_ bookmark: Bookmark, docID: String? = nil) throws -> Bookmark {
        return try updateBookmark(bookmark, docID: docID, source: .local)
    }
    
    /// Returns a bookmarks with docID, and/or paragraphAID
    public func bookmarks(docID: String? = nil, paragraphAID: String? = nil) -> [Bookmark] {
        do {
            var query = BookmarkTable.table.select(BookmarkTable.table[*]).join(AnnotationTable.table.select(AnnotationTable.id, AnnotationTable.status, AnnotationTable.docID), on: BookmarkTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(AnnotationTable.status == .active).order(BookmarkTable.displayOrder ?? Int.max)
            
            if let docID = docID {
                query = query.filter(AnnotationTable.docID == docID)
            }
            
            if let paragraphAID = paragraphAID {
                query = query.filter(BookmarkTable.paragraphAID == paragraphAID)
            }
            
            return try db.prepare(query).map { BookmarkTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Reorders bookmarks in order passed in
    public func reorderBookmarks(_ bookmarks: [Bookmark]) throws {
        try reorderBookmarks(bookmarks, source: .local)
    }
    
    /// Returns bookmark with ID
    public func bookmarkWithID(_ id: Int64) -> Bookmark? {
        do {
            return try db.pluck(BookmarkTable.table.filter(BookmarkTable.id == id)).map { BookmarkTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns bookmark with annotation ID
    public func bookmarkWithAnnotationID(_ annotationID: Int64) -> Bookmark? {
        do {
            return try db.pluck(BookmarkTable.table.filter(BookmarkTable.annotationID == annotationID)).map { BookmarkTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    /// Returns bookmarks with annotationIDs
    public func bookmarksWithAnnotationIDsIn(_ annotationIDs: [Int64]) -> [Bookmark] {
        do {
            return try db.prepare(BookmarkTable.table.filter(annotationIDs.contains(BookmarkTable.annotationID))).map { BookmarkTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Trashes bookmark with ID
    public func trashBookmarkWithID(_ id: Int64) throws {
        try trashBookmarkWithID(id, source: .local)
    }
    
}

// MARK: Internal

extension AnnotationStore {
    
    func createBookmarkTable() throws {
        try db.run(BookmarkTable.table.create(ifNotExists: true) { builder in
            builder.column(BookmarkTable.id, primaryKey: true)
            builder.column(BookmarkTable.name)
            builder.column(BookmarkTable.paragraphAID)
            builder.column(BookmarkTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
            builder.column(BookmarkTable.offset)
            builder.column(BookmarkTable.displayOrder)
        })
    }
    
    @discardableResult func addBookmark(name: String?, paragraphAID: String?, displayOrder: Int, docID: String, docVersion: Int, appSource: String, device: String, source: NotificationSource) throws -> Bookmark {
        return try inTransaction(notificationSource: source) {
            // First, create an annotation for this bookmark
            let annotation = try self.addAnnotation(docID: docID, docVersion: docVersion, appSource: appSource, device: device, source: source)
            
            let query = BookmarkTable.table.filter(BookmarkTable.displayOrder >= displayOrder)
            
            let annotationIDs = try self.db.prepare(query).map { $0[BookmarkTable.annotationID] }
            
            // Increment display order of bookmarks that come after this one
            try self.db.run(query.update(BookmarkTable.displayOrder += 1))
            
            // Mark all the annotations that were updated as changed
            try annotationIDs.forEach { try self.updateLastModifiedDate(annotationID: $0, source: source) }
            
            return try self.addBookmark(name: name, paragraphAID: paragraphAID, displayOrder: displayOrder, annotationID: annotation.id, offset: Bookmark.Offset, source: source)
        }
    }
    
    @discardableResult func addBookmark(name: String?, paragraphAID: String?, displayOrder: Int?, annotationID: Int64, offset: Int, source: NotificationSource) throws -> Bookmark {
        guard annotationID != 0 else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a bookmark without an annotation ID.")
        }
        
        return try inTransaction(notificationSource: source) {
            let id = try self.db.run(BookmarkTable.table.insert(
                BookmarkTable.name <- name,
                BookmarkTable.paragraphAID <- paragraphAID,
                BookmarkTable.displayOrder <- displayOrder,
                BookmarkTable.annotationID <- annotationID,
                BookmarkTable.offset <- offset
            ))
            
            try self.updateLastModifiedDate(annotationID: annotationID, source: source)
            
            return Bookmark(id: id, name: name, paragraphAID: paragraphAID, displayOrder: displayOrder, annotationID: annotationID, offset: offset)
        }
    }
    
    @discardableResult func updateBookmark(_ bookmark: Bookmark, docID: String? = nil, source: NotificationSource) throws -> Bookmark {
        guard bookmark.annotationID != 0 else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a bookmark without an annotation ID.")
        }
        
        return try inTransaction(notificationSource: source) {
            if let docID = docID, var annotation = self.annotationWithID(bookmark.annotationID), annotation.docID != docID {
                // Bookmark was moved to a new docID, so update the annotation
                annotation.docID = docID
                try self.updateAnnotation(annotation, source: source)
            }
            
            try self.db.run(BookmarkTable.table.filter(BookmarkTable.id == bookmark.id).update(
                BookmarkTable.name <- bookmark.name,
                BookmarkTable.paragraphAID <- bookmark.paragraphAID,
                BookmarkTable.displayOrder <- bookmark.displayOrder,
                BookmarkTable.annotationID <- bookmark.annotationID,
                BookmarkTable.offset <- bookmark.offset
            ))
            
            // Mark associated annotation as having been updated
            try self.updateLastModifiedDate(annotationID: bookmark.annotationID, source: source)
            
            return bookmark
        }
    }
    
    func reorderBookmarks(_ bookmarks: [Bookmark], source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            for (displayOrder, var bookmark) in bookmarks.enumerated() where bookmark.displayOrder != displayOrder {
                bookmark.displayOrder = displayOrder
                try self.updateBookmark(bookmark, source: source)
            }
        }
    }
    
    func trashBookmarkWithID(_ id: Int64, source: NotificationSource) throws {
        guard let annotationID = try db.pluck(BookmarkTable.table.select(BookmarkTable.id, BookmarkTable.annotationID).filter(BookmarkTable.id == id)).map({ $0[BookmarkTable.annotationID] }) else { return }
        
        try inTransaction(notificationSource: source) {
            try self.deleteBookmarkWithID(id, source: source)
            try self.trashAnnotationIfEmptyWithID(annotationID, source: source)
        }
    }
    
    func deleteBookmarkWithID(_ id: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(BookmarkTable.table.filter(BookmarkTable.id == id).delete())
        }
    }
    
    func deleteBookmarksWithAnnotationID(_ annotationID: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(BookmarkTable.table.filter(BookmarkTable.annotationID == annotationID).delete())
        }
    }
    
}
