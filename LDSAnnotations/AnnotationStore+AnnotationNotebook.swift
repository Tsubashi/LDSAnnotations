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
    
    static let table = Table("annotation_notebook")
    static let annotationID = Expression<Int64>("annotation_id")
    static let notebookID = Expression<Int64>("notebook_id")
    static let displayOrder = Expression<Int>("display_order")
    
    static func fromRow(_ row: Row) -> AnnotationNotebook {
        return AnnotationNotebook(annotationID: row[annotationID], notebookID: row[notebookID], displayOrder: row[displayOrder])
    }
    
}

// MARK: Public

public extension AnnotationStore {
    
    /// Adds a new annotation notebook with 'annotationID', 'notebookID' and 'displayOrder'
    @discardableResult public func addOrUpdateAnnotationNotebook(annotationID: Int64, notebookID: Int64, displayOrder: Int) throws -> AnnotationNotebook {
        return try addOrUpdateAnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder, source: .local)
    }
    
    /// Reorder annotations within a notebook
    public func reorderAnnotationIDs(_ annotationIDs: [Int64], notebookID: Int64) throws {
        try reorderAnnotationIDs(annotationIDs, notebookID: notebookID, source: .local)
    }

    /// Remove annotation from notebook and mark as trashed if it has no other related annotation objects (note, tag, link, etc)
    public func removeAnnotation(annotationID: Int64, fromNotebook notebookID: Int64) throws {
        try removeAnnotation(annotationID: annotationID, fromNotebook: notebookID, source: .local)
    }
    
    public func isAnnotation(annotationID: Int64, inNotebook notebookID: Int64) -> Bool {
        do {
            return try db.scalar(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID).filter(AnnotationNotebookTable.notebookID == notebookID).count) > 0
        } catch {
            return false
        }
    }
    
}

// MARK: Internal

extension AnnotationStore {
    
    func createAnnotationNotebookTable() throws {
        try db.run(AnnotationNotebookTable.table.create(ifNotExists: true) { builder in
            builder.column(AnnotationNotebookTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
            builder.column(AnnotationNotebookTable.notebookID, references: NotebookTable.table, NotebookTable.id)
            builder.column(AnnotationNotebookTable.displayOrder)
            builder.primaryKey(AnnotationNotebookTable.annotationID, AnnotationNotebookTable.notebookID)
        })
    }
    
    @discardableResult func addOrUpdateAnnotationNotebook(annotationID: Int64, notebookID: Int64, displayOrder: Int, source: NotificationSource) throws -> AnnotationNotebook {
        guard annotationID > 0 && notebookID > 0 else {
            throw AnnotationError.errorWithCode(.requiredFieldMissing, failureReason: "Cannot add an annotationID or notebookID that is == 0")
        }
        
        return try inTransaction(notificationSource: source) {
            try self.db.run(AnnotationNotebookTable.table.insert(or: .replace,
                AnnotationNotebookTable.annotationID <- annotationID,
                AnnotationNotebookTable.notebookID <- notebookID,
                AnnotationNotebookTable.displayOrder <- displayOrder
            ))
            
            try self.updateLastModifiedDate(notebookID: notebookID, source: source)
            try self.updateLastModifiedDate(annotationID: annotationID, source: source)
            
            return AnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder)
        }
    }
    
    public func reorderAnnotationIDs(_ annotationIDs: [Int64], notebookID: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            for (displayOrder, annotationID) in annotationIDs.enumerated() {
                try self.addOrUpdateAnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder, source: source)
            }
        }

    }
    
    func removeAnnotation(annotationID: Int64, fromNotebook notebookID: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID && AnnotationNotebookTable.notebookID == notebookID).delete())
            try self.trashAnnotationIfEmptyWithID(annotationID, source: source)
            try self.updateLastModifiedDate(notebookID: notebookID, source: source)
        }
    }
    
    func removeFromNotebooksAnnotationWithID(_ annotationID: Int64, source: NotificationSource) throws {
        try inTransaction(notificationSource: source) {
            try self.db.run(AnnotationNotebookTable.table.filter(AnnotationNotebookTable.annotationID == annotationID).delete())
        }
    }
    
}
