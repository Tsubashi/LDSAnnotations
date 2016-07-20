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
    public func addTag(name name: String, annotationID: Int64? = nil) throws -> Tag {
        let tag = try addOrUpdateTag(Tag(name: name))
        
        if let annotationID = annotationID, tagID = tag.id {
            try addOrUpdateAnnotationTag(annotationID: annotationID, tagID: tagID)
        }
        
        return tag
    }
    
    /// Adds or updates tag
    public func addOrUpdateTag(tag: Tag) throws -> Tag {
        guard !tag.name.isEmpty else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a tag without a name.")
        }
        
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
    }
    
    /// Returns a list of active tags, order by OrderBy.
    public func tags(ids ids: [Int64]? = nil, orderBy: OrderBy = .Name) -> [Tag] {
        let inClause: String = {
            guard let ids = ids where !ids.isEmpty else { return "" }
            
            return "WHERE tag._id IN (" + ids.map { String($0) }.joinWithSeparator(",") + ")"
        }()
        
        let statement: String
        switch orderBy {
        case .Name:
            statement = "SELECT tag.* FROM tag \(inClause) ORDER BY tag.name"
        case .MostRecent:
            statement = "SELECT DISTINCT tag.* FROM tag LEFT JOIN (SELECT annotation_tag.*, max(annotation.last_modified) AS last_modified from annotation_tag  JOIN annotation ON annotation._id = annotation_tag.annotation_id WHERE annotation.status = '' GROUP BY annotation_tag.tag_id) AS filtered_annotation_tag ON filtered_annotation_tag.tag_id = tag._id \(inClause) ORDER BY filtered_annotation_tag.last_modified DESC, tag.name ASC"
        case .NumberOfAnnotations:
            statement = "SELECT DISTINCT tag.* FROM tag LEFT JOIN (SELECT annotation_tag.tag_id, COUNT(annotation_id) AS annotation_count FROM annotation_tag JOIN annotation ON annotation_tag.annotation_id = annotation._id WHERE annotation.status = '' GROUP BY tag_id) AS counts ON tag._id = counts.tag_id \(inClause) ORDER BY counts.annotation_count DESC, tag.name ASC"
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
    
    /// Selects tag with annotation ID
    public func tagsWithAnnotationID(annotationID: Int64) -> [Tag] {
        do {
            return try db.prepare(TagTable.table.join(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID), on: TagTable.id == AnnotationTagTable.tagID).order(TagTable.name.lowercaseString)).map { TagTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Selects the date of the most recent annotation associated with tagID
    public func dateOfMostRecentAnnotationWithTagID(tagID: Int64) -> NSDate? {
        return db.pluck(AnnotationTable.table.select(AnnotationTable.lastModified).join(AnnotationTagTable.table.join(TagTable.table.select(TagTable.id).filter(TagTable.id == tagID), on: AnnotationTagTable.tagID == TagTable.id), on: AnnotationTable.id == AnnotationTagTable.annotationID).order(AnnotationTable.lastModified.desc)).map { $0[AnnotationTable.lastModified] }
    }
    
    /// Returns a tag with name (case insensitive)
    public func tagWithName(name: String) -> Tag? {
        return db.pluck(TagTable.table.filter(TagTable.name.lowercaseString == name.lowercaseString)).map { TagTable.fromRow($0) }
    }
    
    public func tagsContainingString(string: String) -> [Tag] {
        do {
            let likeClause = String(format: "%%%@%%", string.lowercaseString)
            return try db.prepare(TagTable.table.filter(TagTable.name.lowercaseString.like(likeClause)).order(TagTable.name)).map { TagTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func tagWithID(id: Int64) -> Tag? {
        return db.pluck(TagTable.table.filter(TagTable.id == id)).map { TagTable.fromRow($0) }
    }
    
    func trashTagWithID(id: Int64) throws {
        let annotationIDs = try db.prepare(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id)).map { $0[AnnotationTagTable.annotationID] }
        
        try deleteTagWithID(id)
        
        try annotationIDs.forEach { try trashAnnotationIfEmptyWithID($0) }
    }
    
    /// Deletes tag and annotation tags with ID
    public func deleteTagWithID(id: Int64) throws {
        let annotationIDs = try db.prepare(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id)).map { $0[AnnotationTagTable.annotationID] }
        
        try db.run(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id).delete())
        try db.run(TagTable.table.filter(TagTable.id == id).delete())
        
        // Mark any annotations that were associated with this tag as changed
        try annotationIDs.forEach { try updateLastModifiedDate(annotationID: $0) }
    }
    
}
