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

// MARK: HighlightTable

class HighlightTable {
    
    static let table = Table("highlight")
    static let id = Expression<Int64>("_id")
    static let paragraphAID = Expression<String>("paragraph_aid")
    static let offsetStart = Expression<Int>("offset_start")
    static let offsetEnd = Expression<Int?>("offset_end")
    static let colorName = Expression<String>("color")
    static let style = Expression<HighlightStyle?>("style")
    static let annotationID = Expression<Int64>("annotation_id")
    
    static func fromRow(row: Row) -> Highlight {
        return Highlight(id: row[id],
            paragraphRange: ParagraphRange(paragraphAID: row[paragraphAID], startWordOffset: row[offsetStart], endWordOffset: row[offsetEnd]),
            colorName: row[colorName],
            style: row.get(style),
            annotationID: row[annotationID])
    }
    
}

// MARK: Public

extension AnnotationStore {
    
    /// Returns list of highlights, and creates related annotation
    public func addHighlights(docID docID: String, docVersion: Int, paragraphRanges: [ParagraphRange], colorName: String, style: HighlightStyle, appSource: String, device: String) throws -> [Highlight] {
        return try addHighlights(docID: docID, docVersion: docVersion, paragraphRanges: paragraphRanges, colorName: colorName, style: style, appSource: appSource, device: device, source: .Local)
    }
    
    /// Update highlight
    public func updateHighlight(highlight: Highlight) throws -> Highlight {
        return try updateHighlight(highlight, source: .Local)
    }
    
    /// Returns list of highlights with annotationID
    public func highlightsWithAnnotationID(annotationID: Int64) -> [Highlight] {
        do {
            return try db.prepare(HighlightTable.table.filter(HighlightTable.annotationID == annotationID)).map { HighlightTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    /// Returns list of highlights with annotationIDs
    public func highlightsWithAnnotationIDsIn(annotationIDs: [Int64]) -> [Highlight] {
        do {
            return try db.prepare(HighlightTable.table.filter(annotationIDs.contains(HighlightTable.annotationID))).map { HighlightTable.fromRow($0) }
        } catch {
            return []
        }
    }

    /// Trash highlight with ID
    public func trashHighlightWithID(id: Int64) throws {
        return try trashAnnotationWithID(id, source: .Local)
    }
    
}

// MARK: Internal

extension AnnotationStore {
    
    func createHighlightTable() throws {
        try db.run(HighlightTable.table.create(ifNotExists: true) { builder in
            builder.column(HighlightTable.id, primaryKey: true)
            builder.column(HighlightTable.paragraphAID)
            builder.column(HighlightTable.offsetStart)
            builder.column(HighlightTable.offsetEnd)
            builder.column(HighlightTable.colorName)
            builder.column(HighlightTable.style)
            builder.column(HighlightTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
        })
    }
    
    func addHighlights(docID docID: String, docVersion: Int, paragraphRanges: [ParagraphRange], colorName: String, style: HighlightStyle, appSource: String, device: String, source: NotificationSource) throws -> [Highlight] {
        return try inTransaction(source) {
            // First create an annotation for these highlights
            let annotation = try self.addAnnotation(docID: docID, docVersion: docVersion, appSource: appSource, device: device, source: source)
            
            var highlights = [Highlight]()
            for paragraphRange in paragraphRanges {
                let highlight = try self.addHighlight(paragraphRange: paragraphRange, colorName: colorName, style: style, annotationID: annotation.id, source: source)
                highlights.append(highlight)
            }
            return highlights
        }
    }
    
    func addHighlight(paragraphRange paragraphRange: ParagraphRange, colorName: String, style: HighlightStyle, annotationID: Int64, source: NotificationSource) throws -> Highlight {
        return try inTransaction(source) {
            let id = try self.db.run(HighlightTable.table.insert(
                HighlightTable.paragraphAID <- paragraphRange.paragraphAID,
                HighlightTable.offsetStart <- paragraphRange.startWordOffset,
                HighlightTable.offsetEnd <- paragraphRange.endWordOffset,
                HighlightTable.colorName <- colorName,
                HighlightTable.style <- style,
                HighlightTable.annotationID <- annotationID
            ))
            
            // Mark associated annotation as having been updated
            try self.updateLastModifiedDate(annotationID: annotationID, source: source)
            
            return Highlight(id: id, paragraphRange: paragraphRange, colorName: colorName, style: style, annotationID: annotationID)
        }
    }
    
    func updateHighlight(highlight: Highlight, source: NotificationSource) throws -> Highlight {
        guard highlight.annotationID != 0 else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a highlight without a paragraphAID and an annotation ID.")
        }
        
        return try inTransaction(source) {
            try self.db.run(HighlightTable.table.filter(HighlightTable.id == highlight.id).update(
                HighlightTable.paragraphAID <- highlight.paragraphRange.paragraphAID,
                HighlightTable.offsetStart <- highlight.paragraphRange.startWordOffset,
                HighlightTable.offsetEnd <- highlight.paragraphRange.endWordOffset,
                HighlightTable.colorName <- highlight.colorName,
                HighlightTable.style <- highlight.style,
                HighlightTable.annotationID <- highlight.annotationID
            ))
            
            // Mark associated annotation as having been updated
            try self.updateLastModifiedDate(annotationID: highlight.annotationID, source: source)
            
            return highlight
        }
    }
    
    func highlightWithID(id: Int64) -> Highlight? {
        do {
            return try db.prepare(HighlightTable.table.filter(HighlightTable.id == id)).map { HighlightTable.fromRow($0) }.first
        } catch {
            return nil
        }
    }
    
    func deleteHighlightWithID(id: Int64, source: NotificationSource) throws {
        try inTransaction(source) {
            try self.db.run(HighlightTable.table.filter(HighlightTable.id == id).delete())
        }
    }
    
    func deleteHighlightsWithAnnotationID(annotationID: Int64, source: NotificationSource) throws {
        try inTransaction(source) {
            try self.db.run(HighlightTable.table.filter(HighlightTable.annotationID == annotationID).delete())
        }
    }
    
    func trashHighlightWithID(id: Int64, source: NotificationSource) throws {
        let annotationID = highlightWithID(id)?.annotationID
        
        try inTransaction(source) {
            try self.deleteHighlightWithID(id, source: source)
            
            if let annotationID = annotationID {
                try self.trashAnnotationIfEmptyWithID(annotationID, source: source)
            }
        }
    }
    
}
