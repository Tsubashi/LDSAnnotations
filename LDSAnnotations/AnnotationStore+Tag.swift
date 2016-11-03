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
    
    static func fromRow(_ row: Row) -> Tag {
        return Tag(id: row[id], name: row[name])
    }
    
}

// MARK: Internal

public extension AnnotationStore {

    /// Adds a new tag with `name`.
    @discardableResult public func addTag(name: String, annotationID: Int64? = nil) throws -> Tag {
        return try addTag(name: name, annotationID: annotationID, source: .local)
    }
    
    /// Updates tag
    @discardableResult public func updateTag(_ tag: Tag) throws -> Tag {
        return try updateTag(tag, source: .local)
    }
    
    /// Returns a list of active tags, order by OrderBy.
    public func tags(ids: [Int64]? = nil, orderBy: OrderBy = .name) -> [Tag] {
        let inClause: String = {
            guard let ids = ids, !ids.isEmpty else { return "" }
            
            return "WHERE tag._id IN (" + ids.map { String($0) }.joined(separator: ",") + ")"
        }()
        
        let statement: String
        switch orderBy {
        case .name:
            statement = "SELECT tag.* FROM tag \(inClause) ORDER BY tag.name"
        case .mostRecent:
            statement = "SELECT DISTINCT tag.* FROM tag LEFT JOIN (SELECT annotation_tag.*, max(annotation.last_modified) AS last_modified from annotation_tag  JOIN annotation ON annotation._id = annotation_tag.annotation_id WHERE annotation.status = '' GROUP BY annotation_tag.tag_id) AS filtered_annotation_tag ON filtered_annotation_tag.tag_id = tag._id \(inClause) ORDER BY filtered_annotation_tag.last_modified DESC, tag.name ASC"
        case .numberOfAnnotations:
            statement = "SELECT DISTINCT tag.* FROM tag LEFT JOIN (SELECT annotation_tag.tag_id, COUNT(annotation_id) AS annotation_count FROM annotation_tag JOIN annotation ON annotation_tag.annotation_id = annotation._id WHERE annotation.status = '' GROUP BY tag_id) AS counts ON tag._id = counts.tag_id \(inClause) ORDER BY counts.annotation_count DESC, tag.name ASC"
        }
        
        do {
            return try db.prepare(statement).flatMap { row in
                guard let tagID = row[0] as? Int64, let tagName = row[1] as? String else { return nil }
                
                return Tag(id: tagID, name: tagName)
            }
        } catch {
            return []
        }
    }
    
    /// Selects tag with annotation ID
    public func tagsWithAnnotationID(_ annotationID: Int64) -> [Tag] {
        do {
            return try db.prepare(TagTable.table.join(AnnotationTagTable.table.filter(AnnotationTagTable.annotationID == annotationID), on: TagTable.id == AnnotationTagTable.tagID).order(TagTable.name.lowercaseString)).map { TagTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns tag IDs by annotationID
    func tagIDsWithAnnotationIDsIn(_ annotationIDs: [Int64]) -> [Int64: [Int64]] {
        do {
            
            let results = try db.prepare(AnnotationTagTable.table.select(AnnotationTagTable.tagID, AnnotationTagTable.annotationID).filter(annotationIDs.contains(AnnotationTagTable.annotationID))).map { (annotationID: $0[AnnotationTagTable.annotationID], tagID: $0[AnnotationTagTable.tagID]) }
            
            var tagIDsByAnnotationID = [Int64: [Int64]]()
            for result in results {
                if tagIDsByAnnotationID[result.annotationID] != nil {
                    tagIDsByAnnotationID[result.annotationID]?.append(result.tagID)
                } else {
                    tagIDsByAnnotationID[result.annotationID] = [result.tagID]
                }
            }
            
            return tagIDsByAnnotationID
        } catch {
            return [:]
        }
    }
    
    /// Selects the date of the most recent annotation associated with tagID
    public func dateOfMostRecentAnnotationWithTagID(_ tagID: Int64) -> Date? {
        do {
            return try db.pluck(AnnotationTable.table.select(AnnotationTable.lastModified).join(AnnotationTagTable.table.join(TagTable.table, on: AnnotationTagTable.tagID == TagTable.table[TagTable.id]), on: AnnotationTable.id == AnnotationTagTable.annotationID).filter(TagTable.table[TagTable.id] == tagID).order(AnnotationTable.lastModified.desc)).map { $0[AnnotationTable.lastModified] }
        } catch {
            return nil
        }
    }
    
    /// Returns a tag with name (case insensitive)
    public func tagWithName(_ name: String) -> Tag? {
        do {
            return try db.pluck(TagTable.table.filter(TagTable.name.lowercaseString == name.lowercased())).map { TagTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    // Returns any tags that contain strings
    public func tagsContainingString(_ string: String) -> [Tag] {
        do {
            let likeClause = String(format: "%%%@%%", string.lowercased())
            return try db.prepare(TagTable.table.filter(TagTable.name.lowercaseString.like(likeClause)).order(TagTable.name)).map { TagTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Trash tag with ID
    func trashTagWithID(_ id: Int64) throws {
        try trashTagWithID(id, source: .local)
    }

}

// MARK: Internal

extension AnnotationStore {
    
    func createTagTable() throws {
        try db.run(TagTable.table.create(ifNotExists: true) { builder in
            builder.column(TagTable.id, primaryKey: true)
            builder.column(TagTable.name, unique: true)
        })
    }
    
    @discardableResult func addTag(name: String, annotationID: Int64? = nil, source: NotificationSource) throws -> Tag {
        guard !name.isEmpty else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a tag without a name.")
        }
        
        return try inTransaction(notificationSource: source) {
            let tag: Tag
            if let existingTag = try self.db.prepare(TagTable.table.filter(TagTable.name.lowercaseString == name.lowercased()).limit(1)).map({ TagTable.fromRow($0) }).first {
                // Tag already exists with this name
                tag = existingTag
            } else {
                // Insert this new tag
                let id = try self.db.run(TagTable.table.insert(
                    TagTable.name <- name
                ))
                tag = Tag(id: id, name: name)
            }
            
            if let annotationID = annotationID {
                try self.addOrUpdateAnnotationTag(annotationID: annotationID, tagID: tag.id, source: source)
            }
            
            return tag
        }
    }
    
    @discardableResult func updateTag(_ tag: Tag, source: NotificationSource) throws -> Tag {
        guard !tag.name.isEmpty else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a tag without a name.")
        }
        
        return try inTransaction(notificationSource: source) {
            // Update an existing tag
            try self.db.run(TagTable.table.filter(TagTable.id == tag.id).update(
                TagTable.name <- tag.name
            ))
            return tag
        }
    }
    
    func tagWithID(_ id: Int64) -> Tag? {
        do {
            return try db.pluck(TagTable.table.filter(TagTable.id == id)).map { TagTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    func trashTagWithID(_ id: Int64, source: NotificationSource) throws {
        let annotationIDs = try db.prepare(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id)).map { $0[AnnotationTagTable.annotationID] }
        
        try inTransaction(notificationSource: source) {
            try self.deleteTagWithID(id, source: source)
            try annotationIDs.forEach { try self.trashAnnotationIfEmptyWithID($0, source: source) }
        }
    }
    
    func deleteTagWithID(_ id: Int64, source: NotificationSource) throws {
        let annotationIDs = try db.prepare(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id)).map { $0[AnnotationTagTable.annotationID] }
        
        try inTransaction(notificationSource: source) {
            try self.db.run(AnnotationTagTable.table.filter(AnnotationTagTable.tagID == id).delete())
            try self.db.run(TagTable.table.filter(TagTable.id == id).delete())
        
            // Mark any annotations that were associated with this tag as changed
            try annotationIDs.forEach { try self.updateLastModifiedDate(annotationID: $0, source: source) }
        }
    }
    
}
