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

// MARK: AnnotationTagTable

class AnnotationTagTable {
    
    static let table = Table("annotation_tag")
    static let annotationID = Expression<Int64>("annotation_id")
    static let tagID = Expression<Int64>("tag_id")
    
    static func fromRow(row: Row) -> AnnotationTag {
        return AnnotationTag(annotationID: row[annotationID], tagID: row[tagID])
    }
    
}

// MARK: AnnotationStore

extension AnnotationStore {
    
    func createAnnotationTagTable() throws {
        try db.run(AnnotationTagTable.table.create(ifNotExists: true) { builder in
            builder.column(AnnotationTagTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
            builder.column(AnnotationTagTable.tagID)
            builder.foreignKey(AnnotationTagTable.tagID, references: TagTable.table, TagTable.id)
            builder.primaryKey(AnnotationTagTable.annotationID, AnnotationTagTable.tagID)
        })
    }
    
    /// Adds a new annotation tag with 'annotationID' and 'tagID'.
    public func addOrUpdateAnnotationTag(annotationID annotationID: Int64, tagID: Int64) throws -> AnnotationTag {
        guard annotationID > 0 && tagID > 0 else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add an annotationID or tagID that is == 0")
        }
        
        try db.run(AnnotationTagTable.table.insert(or: .Replace,
            AnnotationTagTable.annotationID <- annotationID,
            AnnotationTagTable.tagID <- tagID
        ))
        
        return AnnotationTag(annotationID: annotationID, tagID: tagID)
    }
    
    // Removes tag from annotation, then marks annotation as trashed if that was the only related annotation object
    public func trashTag(tagID tagID: Int64, fromAnnotation annotationID: Int64) throws {
        try db.run(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID && AnnotationTagTable.tagID == tagID).delete())
        try trashAnnotationIfEmptyWithID(annotationID)
    }
    
    func deleteTag(tagID tagID: Int64, fromAnnotation annotationID: Int64) throws {
        try db.run(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID && AnnotationTagTable.tagID == tagID).delete())
    }
    
    func removeFromTagsAnnotationWithID(annotationID: Int64) throws {
        try db.run(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID).delete())
    }
    
}
