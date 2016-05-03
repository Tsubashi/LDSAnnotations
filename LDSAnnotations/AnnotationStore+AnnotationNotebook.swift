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

// MARK: AnnotationNotebookTable

class AnnotationNotebookTable {
    
    static let table = Table("annotation_folder")
    static let annotationID = Expression<Int64>("annotation_id")
    static let notebookID = Expression<Int64>("notebook_id")
    static let displayOrder = Expression<Int>("display_order")
    
    static func fromRow(row: Row) -> AnnotationNotebook {
        return AnnotationNotebook(annotationID: row[annotationID], notebookID: row[notebookID], displayOrder: row[displayOrder])
    }
    
}

// MARK: AnnotationStore

extension AnnotationStore {
    
    func createAnnotationNotebookTable() throws {
        try db.run(AnnotationNotebookTable.table.create(ifNotExists: true) { builder in
            builder.column(AnnotationNotebookTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
            builder.column(AnnotationNotebookTable.notebookID, references: NotebookTable.table, NotebookTable.id)
            builder.column(AnnotationNotebookTable.displayOrder)
            builder.primaryKey(AnnotationNotebookTable.annotationID, AnnotationNotebookTable.notebookID)
        })
    }
    
    /// Adds a new annotation notebook with 'annotationID', 'notebookID' and 'displayOrder'
    public func addOrUpdateAnnotationNotebook(annotationID annotationID: Int64, notebookID: Int64, displayOrder: Int) throws -> AnnotationNotebook? {
        guard annotationID > 0 && notebookID > 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add an annotationID or notebookID that is == 0")
        }
        
        do {
            try db.run(AnnotationNotebookTable.table.insert(or: .Replace,
                AnnotationNotebookTable.annotationID <- annotationID,
                AnnotationNotebookTable.notebookID <- notebookID,
                AnnotationNotebookTable.displayOrder <- displayOrder
            ))
            
            return AnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder)
        } catch {
            return nil
        }
    }
    
    func deleteAnnotationNotebook(annotationID: Int64, notebookID: Int64) {
        do {
            try db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID && AnnotationNotebookTable.notebookID == notebookID).delete())
        } catch {}
    }
    
}
