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

// MARK: LinkTable

class LinkTable {
    
    static let table = Table("link")
    static let id = Expression<Int64>("_id")
    static let name = Expression<String>("name")
    static let docID = Expression<String>("doc_id")
    static let docVersion = Expression<Int>("doc_version")
    static let paragraphAIDs = Expression<String>("paragraph_aids")
    static let annotationID = Expression<Int64>("annotation_id")
    
    static func fromRow(_ row: Row) -> Link {
        return Link(id: row[id],
            name: row[name],
            docID: row[docID],
            docVersion: row[docVersion],
            paragraphAIDs: row[paragraphAIDs].components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }),
            annotationID: row[annotationID])
    }
    
    static func fromNamespacedRow(_ row: Row) -> Link {
        return Link(
            id: row[LinkTable.table[id]],
            name: row[LinkTable.table[name]],
            docID: row[LinkTable.table[docID]],
            docVersion: row[LinkTable.table[docVersion]],
            paragraphAIDs: row[LinkTable.table[paragraphAIDs]].components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }),
            annotationID: row[LinkTable.table[annotationID]]
        )
    }
    
}

// MARK: Public

public extension AnnotationStore {
    
    /// Creates a link and adds it to annotation with ID
    @discardableResult public func addLink(name: String, toDocID: String, toDocVersion: Int, toParagraphAIDs: [String], annotationID: Int64) throws -> Link {
        return try addLink(name: name, docID: toDocID, docVersion: toDocVersion, paragraphAIDs: toParagraphAIDs, annotationID: annotationID, source: .local)
    }

    /// Creates a link and adds related annotation and highlights
    @discardableResult public func addLink(name: String, toDocID: String, toDocVersion: Int, toParagraphAIDs: [String], fromDocID: String, fromDocVersion: Int, fromParagraphRanges: [ParagraphRange], colorName: String, style: HighlightStyle, appSource: String, device: String) throws -> Link {
        let source: NotificationSource = .local
        return try inTransaction(notificationSource: source) {
            // Create annotation and highlights for this link
            let highlights = try self.addHighlights(docID: fromDocID, docVersion: fromDocVersion, paragraphRanges: fromParagraphRanges, colorName: colorName, style: style, appSource: appSource, device: device, source: source)
            
            guard let annotationID = highlights.first?.annotationID else { throw AnnotationError.errorWithCode(.saveHighlightFailed, failureReason: "Failed to create highlights") }
            
            return try self.addLink(name: name, docID: toDocID, docVersion: toDocVersion, paragraphAIDs: toParagraphAIDs, annotationID: annotationID, source: source)
        }
    }
    
    /// Updates link
    @discardableResult public func updateLink(_ link: Link) throws -> Link {
        return try updateLink(link, source: .local)
    }
    
    /// Returns list of links with annotation ID
    public func linksWithAnnotationID(_ annotationID: Int64) -> [Link] {
        do {
            return try db.prepare(LinkTable.table.filter(LinkTable.annotationID == annotationID)).map { LinkTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns list of links with annotation IDs
    public func linksWithAnnotationIDsIn(_ annotationIDs: [Int64]) -> [Link] {
        do {
            return try db.prepare(LinkTable.table.filter(annotationIDs.contains(LinkTable.annotationID))).map { LinkTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Return link with ID, then marks annotation as trashed if is has no other related annotation objects
    public func trashLinkWithID(_ id: Int64) throws {
        try trashLinkWithID(id, source: .local)
    }

}

// MARK: Internal

extension AnnotationStore {
    
    func createLinkTable() throws {
        try db.run(LinkTable.table.create(ifNotExists: true) { builder in
            builder.column(LinkTable.id, primaryKey: true)
            builder.column(LinkTable.name)
            builder.column(LinkTable.docID)
            builder.column(LinkTable.docVersion)
            builder.column(LinkTable.paragraphAIDs)
            builder.column(LinkTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
        })
    }

    @discardableResult func addLink(name: String, docID: String, docVersion: Int, paragraphAIDs: [String], annotationID: Int64, source: NotificationSource) throws -> Link {
        // TODO: Swift 3 compiler was complaining when these were all together...
        let firstCondition = !name.isEmpty && !docID.isEmpty && docVersion > 0
        let secondCondition = !paragraphAIDs.isEmpty && annotationID != 0
        guard firstCondition && secondCondition else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a highlight without a paragraphAID and an annotation ID.")
        }
        
        return try inTransaction(notificationSource: source) {
            let id = try self.db.run(LinkTable.table.insert(
                LinkTable.name <- name,
                LinkTable.docID <- docID,
                LinkTable.docVersion <- docVersion,
                LinkTable.paragraphAIDs <- paragraphAIDs.joined(separator: ","),
                LinkTable.annotationID <- annotationID
            ))
            
            // Mark associated annotation as having been updated
            try self.updateLastModifiedDate(annotationID: annotationID, source: source)
            
            return Link(id: id, name: name, docID: docID, docVersion: docVersion, paragraphAIDs: paragraphAIDs, annotationID: annotationID)
        }
    }
    
    @discardableResult func updateLink(_ link: Link, source: NotificationSource) throws -> Link {
        // TODO: Swift 3 compiler was complaining when these were all together...
        let firstCondition = !link.name.isEmpty && !link.docID.isEmpty && link.docVersion > 0
        let secondCondition = !link.paragraphAIDs.isEmpty && link.annotationID != 0
        guard firstCondition && secondCondition else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add a highlight without a paragraphAID and an annotation ID.")
        }
        
        return try inTransaction(notificationSource: source) {
            try self.db.run(LinkTable.table.filter(LinkTable.id == link.id).update(
                LinkTable.name <- link.name,
                LinkTable.docID <- link.docID,
                LinkTable.docVersion <- link.docVersion,
                LinkTable.paragraphAIDs <- link.paragraphAIDs.joined(separator: ","),
                LinkTable.annotationID <- link.annotationID
            ))
            
            // Mark associated annotation as having been updated
            try self.updateLastModifiedDate(annotationID: link.annotationID, source: source)
            
            return link
        }
    }
    
    func linkWithID(_ id: Int64) -> Link? {
        do {
            return try db.pluck(LinkTable.table.filter(LinkTable.id == id)).map { LinkTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    func deleteLinkWithID(_ id: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(LinkTable.table.filter(LinkTable.id == id).delete())
        }
    }
    
    func deleteLinksWithAnnotationID(_ annotationID: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(LinkTable.table.filter(LinkTable.annotationID == annotationID).delete())
        }
    }
    
    func trashLinkWithID(_ id: Int64, source: NotificationSource) throws {
        guard let annotationID = try db.pluck(LinkTable.table.select(LinkTable.id, LinkTable.annotationID).filter(LinkTable.id == id)).map({ $0[LinkTable.annotationID] }) else { return }
        
        try inTransaction(notificationSource: source) {
            try self.deleteLinkWithID(id, source: source)
            try self.trashAnnotationIfEmptyWithID(annotationID, source: source)
        }
    }
    
}
