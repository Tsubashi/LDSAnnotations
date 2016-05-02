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

// MARK: NoteTable

class NoteTable {
    
    static let table = Table("note")
    static let id = Expression<Int64>("_id")
    static let title = Expression<String?>("title")
    static let content = Expression<String>("content")
    static let annotationID = Expression<Int64>("annotation_id")

    static func fromRow(row: Row) -> Note {
        return Note(id: row[id], title: row[title], content: row[content], annotationID: row[annotationID])
    }
    
}

// MARK: AnnotationStore

extension AnnotationStore {
    
    func createNoteTable() throws {
        try db.run(NoteTable.table.create(ifNotExists: true) { builder in
            builder.column(NoteTable.id, primaryKey: true)
            builder.column(NoteTable.title)
            builder.column(NoteTable.content)
            builder.column(NoteTable.annotationID, references: AnnotationTable.table, AnnotationTable.id)
        })
    }
    
    /// Adds a new note with `content`.
    public func addOrUpdateNote(note: Note) throws -> Note? {
        guard note.annotationID != 0 else {
            throw Error.errorWithCode(.Unknown, failureReason: "Cannot add a note without content and an annotation ID.")
        }
        
        do {
            if let id = note.id {
                try db.run(NoteTable.table.filter(NoteTable.id == id).update(
                    NoteTable.title <- note.title,
                    NoteTable.content <- note.content,
                    NoteTable.annotationID <- note.annotationID
                ))
                return note
            } else {
                let id = try db.run(NoteTable.table.insert(
                    NoteTable.title <- note.title,
                    NoteTable.content <- note.content,
                    NoteTable.annotationID <- note.annotationID
                ))
                return Note(id: id, title: note.title, content: note.content, annotationID: note.annotationID)
            }
        } catch {
            return nil
        }
    }
    
    public func noteWithID(id: Int64) -> Note? {
        return db.pluck(NoteTable.table.filter(NoteTable.id == id)).map { NoteTable.fromRow($0) }
    }
    
    func deleteNoteWithID(id: Int64) {
        do {
            try db.run(NoteTable.table.filter(NoteTable.id == id).delete())
        } catch {}
    }
    
}
