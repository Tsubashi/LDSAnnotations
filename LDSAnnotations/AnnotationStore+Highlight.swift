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
    static let offsetStart = Expression<Int?>("offset_start")
    static let offsetEnd = Expression<Int?>("offset_end")
    static let colorName = Expression<String>("color")
    static let style = Expression<HighlightStyle?>("style")
    static let annotationID = Expression<Int64>("annotation_id")
    
    static func fromRow(row: Row) -> Highlight {
        return Highlight(id: row[id],
            paragraphAID: row[paragraphAID],
            offsetStart: row[offsetStart],
            offsetEnd: row[offsetEnd],
            colorName: row[colorName],
            style: row.get(style),
            annotationID: row[annotationID])
    }
    
}

// MARK: AnnotationStore

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
    
    public func addOrUpdateHighlight(highlight: Highlight) throws -> Highlight? {
        guard !highlight.paragraphAID.isEmpty && highlight.annotationID != 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add a highlight without a paragraphAID and an annotation ID.")
        }
        
        do {
            if let id = highlight.id {
                try db.run(HighlightTable.table.filter(HighlightTable.id == id).update(
                    HighlightTable.paragraphAID <- highlight.paragraphAID,
                    HighlightTable.offsetStart <- highlight.offsetStart,
                    HighlightTable.offsetEnd <- highlight.offsetEnd,
                    HighlightTable.colorName <- highlight.colorName,
                    HighlightTable.style <- highlight.style,
                    HighlightTable.annotationID <- highlight.annotationID
                ))
                
                return highlight
            } else {
                let id = try db.run(HighlightTable.table.insert(
                    HighlightTable.paragraphAID <- highlight.paragraphAID,
                    HighlightTable.offsetStart <- highlight.offsetStart,
                    HighlightTable.offsetEnd <- highlight.offsetEnd,
                    HighlightTable.colorName <- highlight.colorName,
                    HighlightTable.style <- highlight.style,
                    HighlightTable.annotationID <- highlight.annotationID
                ))
                
                return Highlight(id: id, paragraphAID: highlight.paragraphAID, offsetStart: highlight.offsetStart, offsetEnd: highlight.offsetEnd, colorName: highlight.colorName, style: highlight.style, annotationID: highlight.annotationID)
            }
        } catch {
            return nil
        }
    }
    
    public func highlightsWithAnnotationID(annotationID: Int64) -> [Highlight] {
        do {
            return try db.prepare(HighlightTable.table.filter(HighlightTable.annotationID == annotationID)).map { HighlightTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func highlightWithID(id: Int64) -> Highlight? {
        return db.pluck(HighlightTable.table.filter(HighlightTable.id == id)).map { HighlightTable.fromRow($0) }
    }
    
    func deleteHighlightWithID(id: Int64) {
        do {
            try db.run(HighlightTable.table.filter(HighlightTable.id == id).delete())
        } catch {}
    }
    
}
