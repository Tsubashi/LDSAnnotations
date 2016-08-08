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
    
    static func fromRow(row: Row) -> Bookmark {
        return Bookmark(id: row[id],
            name: row[name],
            paragraphAID: row[paragraphAID],
            displayOrder: row[displayOrder],
            annotationID: row[annotationID],
            offset: row[offset])
    }
    
}

// MARK: AnnotationStore

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
    
    /// Returns a bookmark, and creates related annotation object
    public func addBookmark(name name: String?, paragraphAID: String?, displayOrder: Int, docID: String, docVersion: Int, iso639_3Code: String, source: String, device: String) throws -> Bookmark {
        // First, create an annotation for this bookmark
        let annotation = try addAnnotation(iso639_3Code: iso639_3Code, docID: docID, docVersion: docVersion, source: source, device: device)
        
        // Increment display order of bookmarks that come after this one
        try db.run(BookmarkTable.table.filter(BookmarkTable.displayOrder >= displayOrder).update(BookmarkTable.displayOrder += 1))
        
        return try addBookmark(name: name, paragraphAID: paragraphAID, displayOrder: displayOrder, annotationID: annotation.id)
    }
    
    /// Returns a bookmark after adding or updating it
    func addBookmark(name name: String?, paragraphAID: String?, displayOrder: Int?, annotationID: Int64, offset: Int = Bookmark.Offset) throws -> Bookmark {
        guard annotationID != 0 else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a bookmark without an annotation ID.")
        }
        
        let id = try db.run(BookmarkTable.table.insert(
            BookmarkTable.name <- name,
            BookmarkTable.paragraphAID <- paragraphAID,
            BookmarkTable.displayOrder <- displayOrder,
            BookmarkTable.annotationID <- annotationID,
            BookmarkTable.offset <- offset
        ))
        
        return Bookmark(id: id, name: name, paragraphAID: paragraphAID, displayOrder: displayOrder, annotationID: annotationID, offset: offset)
    }
    
    public func updateBookmark(bookmark: Bookmark, docID: String? = nil) throws -> Bookmark {
        guard bookmark.annotationID != 0 else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a bookmark without an annotation ID.")
        }
        
        if let docID = docID, var annotation = annotationWithID(bookmark.annotationID) where annotation.docID != docID {
            // Bookmark was moved to a new docID, so update the annotation
            annotation.docID = docID
            try updateAnnotation(annotation)
        }
        
        try db.run(BookmarkTable.table.filter(BookmarkTable.id == bookmark.id).update(
            BookmarkTable.name <- bookmark.name,
            BookmarkTable.paragraphAID <- bookmark.paragraphAID,
            BookmarkTable.displayOrder <- bookmark.displayOrder,
            BookmarkTable.annotationID <- bookmark.annotationID,
            BookmarkTable.offset <- bookmark.offset
        ))
        
        // Mark associated annotation as having been updated
        try updateLastModifiedDate(annotationID: bookmark.annotationID)
        
        return bookmark
    }
    
    /// Returns a bookmarks with docID, and/or paragraphAID
    public func bookmarks(docID docID: String? = nil, paragraphAID: String? = nil) -> [Bookmark] {
        do {
            var query = BookmarkTable.table.select(BookmarkTable.table[*]).join(AnnotationTable.table.select(AnnotationTable.id, AnnotationTable.status, AnnotationTable.docID), on: BookmarkTable.annotationID == AnnotationTable.table[AnnotationTable.id]).filter(AnnotationTable.status == .Active)
            
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
    public func reorderBookmarks(bookmarks: [Bookmark]) throws {
        try inTransaction {
            for (displayOrder, var bookmark) in bookmarks.enumerate() where bookmark.displayOrder != displayOrder {
                bookmark.displayOrder = displayOrder
                try self.updateBookmark(bookmark)
            }
        }
    }
    
    public func bookmarkWithID(id: Int64) -> Bookmark? {
        return db.pluck(BookmarkTable.table.filter(BookmarkTable.id == id)).map { BookmarkTable.fromRow($0) }
    }
   
    public func bookmarkWithAnnotationID(annotationID: Int64) -> Bookmark? {
        return db.pluck(BookmarkTable.table.filter(BookmarkTable.annotationID == annotationID)).map { BookmarkTable.fromRow($0) }
    }
    
    public func trashBookmarkWithID(id: Int64) throws {
        guard let annotationID = db.pluck(BookmarkTable.table.select(BookmarkTable.id, BookmarkTable.annotationID).filter(BookmarkTable.id == id)).map({ $0[BookmarkTable.annotationID] }) else { return }
        
        try deleteBookmarkWithID(id)
        
        try trashAnnotationIfEmptyWithID(annotationID)
    }
    
    public func deleteBookmarkWithID(id: Int64) throws {
        try db.run(BookmarkTable.table.filter(BookmarkTable.id == id).delete())
    }
    
    func deleteBookmarksWithAnnotationID(annotationID: Int64) throws {
        try db.run(BookmarkTable.table.filter(BookmarkTable.annotationID == annotationID).delete())
    }
    
}
