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
    
    static func fromRow(row: Row) -> Link {
        return Link(id: row[id],
            name: row[name],
            docID: row[docID],
            docVersion: row[docVersion],
            paragraphAIDs: row[paragraphAIDs].componentsSeparatedByString(",").map({ $0.stringByTrimmingCharactersInSet(.whitespaceCharacterSet()) }),
            annotationID: row[annotationID])
    }
    
}

// MARK: AnnotationStore

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
    
    /// Creates a link and adds it to annotation with ID
    public func addLink(name name: String, toDocID: String, toDocVersion: Int, toParagraphAIDs: [String], annotationID: Int64) throws -> Link {
        return try addOrUpdateLink(Link(id: nil, name: name, docID: toDocID, docVersion: toDocVersion, paragraphAIDs: toParagraphAIDs, annotationID: annotationID))
    }
    
    /// Creates a link and adds related annotation and highlights
    public func addLink(name name: String, toDocID: String, toDocVersion: Int, toParagraphAIDs: [String], fromDocID: String, fromDocVersion: Int, fromParagraphRanges: [ParagraphRange], colorName: String, style: HighlightStyle, iso639_3Code: String, source:
        String, device: String) throws -> Link {
        // Create annotation and highlights for this link
        let highlights = try addHighlights(docID: fromDocID, docVersion: fromDocVersion, paragraphRanges: fromParagraphRanges, colorName: colorName, style: style, iso639_3Code: iso639_3Code, source: source, device: device)
        
        guard let annotationID = highlights.first?.annotationID else { throw Error.errorWithCode(.SaveHighlightFailed, failureReason: "Failed to create highlights") }
        
        return try addOrUpdateLink(Link(id: nil, name: name, docID: toDocID, docVersion: toDocVersion, paragraphAIDs: toParagraphAIDs, annotationID: annotationID))
    }
    
    /// Adds or updates link
    public func addOrUpdateLink(link: Link) throws -> Link {
        guard !link.name.isEmpty && !link.docID.isEmpty && link.docVersion > 0 && !link.paragraphAIDs.isEmpty && link.annotationID != 0 else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a highlight without a paragraphAID and an annotation ID.")
        }
        
        if let id = link.id {
            try db.run(LinkTable.table.filter(LinkTable.id == id).update(
                LinkTable.name <- link.name,
                LinkTable.docID <- link.docID,
                LinkTable.docVersion <- link.docVersion,
                LinkTable.paragraphAIDs <- link.paragraphAIDs.joinWithSeparator(","),
                LinkTable.annotationID <- link.annotationID
            ))
            
            // Mark associated annotation as having been updated
            try updateLastModifiedDate(annotationID: link.annotationID)
            
            return link
        } else {
            let id = try db.run(LinkTable.table.insert(
                LinkTable.name <- link.name,
                LinkTable.docID <- link.docID,
                LinkTable.docVersion <- link.docVersion,
                LinkTable.paragraphAIDs <- link.paragraphAIDs.joinWithSeparator(","),
                LinkTable.annotationID <- link.annotationID
            ))
            
            return Link(id: id, name: link.name, docID: link.docID, docVersion: link.docVersion, paragraphAIDs: link.paragraphAIDs, annotationID: link.annotationID)
        }
    }
    
    /// Returns list of links with annotation ID
    public func linksWithAnnotationID(annotationID: Int64) -> [Link] {
        do {
            return try db.prepare(LinkTable.table.filter(LinkTable.annotationID == annotationID)).map { LinkTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func linkWithID(id: Int64) -> Link? {
        return db.pluck(LinkTable.table.filter(LinkTable.id == id)).map { LinkTable.fromRow($0) }
    }
    
    /// Reash link with ID, then marks annotation as trashed if is has no other related annotation objects
    public func trashLinkWithID(id: Int64) throws {
        guard let annotationID = db.pluck(LinkTable.table.select(LinkTable.id, LinkTable.annotationID).filter(LinkTable.id == id)).map({ $0[LinkTable.annotationID] }) else { return }
        
        try deleteLinkWithID(id)
        
        try trashAnnotationIfEmptyWithID(annotationID)
    }
    
    func deleteLinkWithID(id: Int64) throws {
        try db.run(LinkTable.table.filter(LinkTable.id == id).delete())
    }
    
    func deleteLinksWithAnnotationID(annotationID: Int64) throws {
        try db.run(LinkTable.table.filter(LinkTable.annotationID == annotationID).delete())
    }
    
}
