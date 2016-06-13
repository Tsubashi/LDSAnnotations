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
            builder.column(TagTable.name, unique: true)
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
                
            } else if let tag = db.pluck(TagTable.table.filter(TagTable.name.lowercaseString == tag.name.lowercaseString)).map({ TagTable.fromRow($0) }) {
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
    
    public func tags(ids ids: [Int64]? = nil, orderBy: OrderBy = .Name) -> [Tag] {
        var inClause: String = {
            guard let ids = ids else { return "" }
            
            return "AND tag._id IN (" + ids.map { String($0) }.joinWithSeparator(",") + ")"
        }()
        
        let statement: String
        switch orderBy {
        case .Name:
            statement = "SELECT DISTINCT tag.* FROM tag JOIN annotation_tag ON annotation_tag.tag_id = tag._id JOIN annotation ON annotation._id = annotation_tag.annotation_id WHERE annotation.status = '' \(inClause) ORDER BY tag.name"
        case .MostRecent:
            statement = "SELECT DISTINCT tag.* FROM tag JOIN annotation_tag ON annotation_tag.tag_id = tag._id JOIN annotation ON annotation._id = annotation_tag.annotation_id WHERE annotation.status = '' \(inClause) ORDER BY annotation.last_modified DESC, tag.name ASC"
        case .NumberOfAnnotations:
            inClause = inClause.stringByReplacingOccurrencesOfString("AND ", withString: "WHERE ")
            statement = "SELECT DISTINCT tag.* FROM tag JOIN (SELECT annotation_tag.tag_id, COUNT(annotation_id) AS annotation_count FROM annotation_tag JOIN annotation ON annotation_tag.annotation_id = annotation._id WHERE annotation.status = '' GROUP BY tag_id) AS counts ON tag._id = counts.tag_id \(inClause) ORDER BY counts.annotation_count DESC, tag.name ASC"
        }
        
        do {
            return try db.prepare(statement).flatMap { row in
                guard let tagID = row[0] as? Int64, tagName = row[1] as? String else { return nil }
                
                return Tag(id: tagID, name: tagName)
            }
        } catch {
            return []
        }
    }
    
    public func tagsWithAnnotationID(annotationID: Int64) -> [Tag] {
        do {
            return try db.prepare(TagTable.table.join(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID), on: TagTable.id == AnnotationTagTable.tagID)).map { TagTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func dateOfMostRecentAnnotationWithTagID(tagID: Int64) -> NSDate? {
        return db.pluck(AnnotationTable.table.select(AnnotationTable.lastModified).join(AnnotationTagTable.table.join(TagTable.table.select(TagTable.id).filter(TagTable.id == tagID), on: AnnotationTagTable.tagID == TagTable.id), on: AnnotationTable.id == AnnotationTagTable.annotationID).order(AnnotationTable.lastModified.desc)).map { $0[AnnotationTable.lastModified] }
    }
    
    func tagWithID(id: Int64) -> Tag? {
        return db.pluck(TagTable.table.filter(TagTable.id == id)).map { TagTable.fromRow($0) }
    }
    
    public func deleteTagWithID(id: Int64) {
        do {
            try db.run(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id).delete())
            try db.run(TagTable.table.filter(TagTable.id == id).delete())
        } catch {}
    }
    
}
