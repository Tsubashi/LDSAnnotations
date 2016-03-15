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
    
    
    public func addOrUpdateLink(link: Link) throws -> Link? {
        guard !link.name.isEmpty && !link.docID.isEmpty && link.docVersion > 0 && !link.paragraphAIDs.isEmpty && link.annotationID != 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add a highlight without a paragraphAID and an annotation ID.")
        }
        
        do {
            if let id = link.id {
                try db.run(HighlightTable.table.filter(HighlightTable.id == id).update(
                    LinkTable.name <- link.name,
                    LinkTable.docID <- link.docID,
                    LinkTable.docVersion <- link.docVersion,
                    LinkTable.paragraphAIDs <- link.paragraphAIDs.joinWithSeparator(","),
                    LinkTable.annotationID <- link.annotationID
                ))
                return link
            } else {
                let id = try db.run(HighlightTable.table.insert(
                    LinkTable.name <- link.name,
                    LinkTable.docID <- link.docID,
                    LinkTable.docVersion <- link.docVersion,
                    LinkTable.paragraphAIDs <- link.paragraphAIDs.joinWithSeparator(","),
                    LinkTable.annotationID <- link.annotationID
                ))
                return Link(id: id, name: link.name, docID: link.docID, docVersion: link.docVersion, paragraphAIDs: link.paragraphAIDs, annotationID: link.annotationID)
            }
        } catch {
            return nil
        }
    }
    
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
    
    func deleteLinkWithID(id: Int64) {
        do {
            try db.run(LinkTable.table.filter(LinkTable.id == id).delete())
        } catch {}
    }
    
}
