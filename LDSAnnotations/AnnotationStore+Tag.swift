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

// MARK: TagTable

class TagTable {
    
    static let table = Table("tag")
    static let id = Expression<Int64>("_id")
    static let name = Expression<String>("name")
    
    static func fromRow(row: Row) -> Tag {
        return Tag(id: row[id], name: row[name])
    }
    
}

// MARK: AnnotationStore

extension AnnotationStore {
    
    func createTagTable() throws {
        try db.run(TagTable.table.create(ifNotExists: true) { builder in
            builder.column(TagTable.id, primaryKey: true)
            builder.column(TagTable.name)
        })
    }
    
    /// Adds a new tag with `name`.
    public func addOrUpdateTag(tag: Tag) throws -> Tag? {
        guard !tag.name.isEmpty else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add a tag without a name.")
        }
        
        do {
            if let id = tag.id {
                // Update an existing tag
                try db.run(TagTable.table.filter(TagTable.id == id).update(
                    TagTable.name <- tag.name
                ))
                return tag
                
            } else if db.pluck(TagTable.table.filter(TagTable.name.lowercaseString == tag.name.lowercaseString)) != nil {
                // Tag already exists with this name
                return tag
                
            } else {
                // Insert this new tag
                let id = try db.run(TagTable.table.insert(
                    TagTable.name <- tag.name
                ))
                return Tag(id: id, name: tag.name)
            }
        } catch {
            return nil
        }
    }
    
    public func tagsWithAnnotationID(annotationID: Int64) -> [Tag] {
        do {
            return try db.prepare(TagTable.table.join(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID), on: TagTable.id == AnnotationTagTable.tagID)).map { TagTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func tagWithID(id: Int64) -> Tag? {
        return db.pluck(TagTable.table.filter(TagTable.id == id)).map { TagTable.fromRow($0) }
    }
    
    func deleteTagWithID(id: Int64) {
        do {
            try db.run(TagTable.table.filter(TagTable.id == id).delete())
        } catch {}
    }
    
}
