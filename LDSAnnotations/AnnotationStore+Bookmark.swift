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
        })
    }
    
    public func addOrUpdateBookmark(bookmark: Bookmark) throws -> Bookmark? {
        guard bookmark.annotationID != 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add a bookmark without an annotation ID.")
        }
        
        do {
            if let id = bookmark.id {
                try db.run(BookmarkTable.table.filter(BookmarkTable.id == id).update(
                    BookmarkTable.name <- bookmark.name,
                    BookmarkTable.paragraphAID <- bookmark.paragraphAID,
                    BookmarkTable.displayOrder <- bookmark.displayOrder,
                    BookmarkTable.annotationID <- bookmark.annotationID,
                    BookmarkTable.offset <- bookmark.offset
                ))
                return bookmark
            } else {
                let id = try db.run(BookmarkTable.table.insert(
                    BookmarkTable.name <- bookmark.name,
                    BookmarkTable.paragraphAID <- bookmark.paragraphAID,
                    BookmarkTable.displayOrder <- bookmark.displayOrder,
                    BookmarkTable.annotationID <- bookmark.annotationID,
                    BookmarkTable.offset <- bookmark.offset
                ))
                return Bookmark(id: id, name: bookmark.name, paragraphAID: bookmark.paragraphAID, displayOrder: bookmark.displayOrder, annotationID: bookmark.annotationID, offset: bookmark.offset)
            }
        } catch {
            return nil
        }
    }
    
    public func bookmarkWithID(id: Int64) -> Bookmark? {
        return db.pluck(BookmarkTable.table.filter(BookmarkTable.id == id)).map { BookmarkTable.fromRow($0) }
    }
    
    public func deleteBookmarkWithID(id: Int64) {
        do {
            try db.run(BookmarkTable.table.filter(BookmarkTable.id == id).delete())
        } catch {}
    }
    
}
