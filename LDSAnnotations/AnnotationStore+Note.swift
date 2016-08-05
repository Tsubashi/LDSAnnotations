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
    
    /// Adds note and links it to annotation
    public func addNote(title title: String?, content: String, annotationID: Int64) throws -> Note {
        return try addOrUpdateNote(Note(id: nil, title: title, content: content, annotationID: annotationID))
    }
    
    /// Adds note and related annotation, and associates it to notebook
    public func addNote(title title: String?, content: String, source: String, device: String, notebookID: Int64) throws -> Note {
        let annotation = try addAnnotation(iso639_3Code: "eng", docID: nil, docVersion: nil, source: source, device: device)
        
        let note = try addOrUpdateNote(Note(id: nil, title: title, content: content, annotationID: annotation.id))
        
        let displayOrder = numberOfAnnotations(notebookID: notebookID)
        try addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebookID, displayOrder: displayOrder)
        
        return note
    }
    
    /// Adds note, related annotation & highlights
    public func addNote(title: String?, content: String, docID: String, docVersion: Int, paragraphRanges: [ParagraphRange], colorName: String, style: HighlightStyle, iso639_3Code: String, source:
        String, device: String) throws -> Note {
        let highlights = try addHighlights(docID: docID, docVersion: docVersion, paragraphRanges: paragraphRanges, colorName: colorName, style: style, iso639_3Code: iso639_3Code, source: source, device: device)
        
        guard let annotationID = highlights.first?.annotationID else { throw Error.errorWithCode(.SaveHighlightFailed, failureReason: "Failed to create highlights") }
        
        return try addOrUpdateNote(Note(id: nil, title: title, content: content, annotationID: annotationID))
    }
    
    /// Adds a new note with `content`.
    public func addOrUpdateNote(note: Note) throws -> Note {
        guard note.annotationID != 0 || ((note.title == nil || note.title?.isEmpty == true) && note.content.isEmpty) else {
            throw Error.errorWithCode(.RequiredFieldMissing, failureReason: "Cannot add a note without content and an annotation ID.")
        }
        
        if let id = note.id {
            try db.run(NoteTable.table.filter(NoteTable.id == id).update(
                NoteTable.title <- note.title,
                NoteTable.content <- note.content,
                NoteTable.annotationID <- note.annotationID
            ))
            
            // Mark associated annotation as having been updated
            try updateLastModifiedDate(annotationID: note.annotationID)
            
            return note
        } else {
            let id = try db.run(NoteTable.table.insert(
                NoteTable.title <- note.title,
                NoteTable.content <- note.content,
                NoteTable.annotationID <- note.annotationID
            ))
            
            return Note(id: id, title: note.title, content: note.content, annotationID: note.annotationID)
        }
    }
    
    /// Returns note with ID
    public func noteWithID(id: Int64) -> Note? {
        return db.pluck(NoteTable.table.filter(NoteTable.id == id)).map { NoteTable.fromRow($0) }
    }

    /// Returns note with annotationID
    public func noteWithAnnotationID(annotationID: Int64) -> Note? {
        return db.pluck(NoteTable.table.filter(NoteTable.annotationID == annotationID)).map { NoteTable.fromRow($0) }
    }
    
    /// Deletes note with id, and then trashes associated annotation if it has no other related annotation objects
    public func trashNoteWithID(id: Int64) throws {
        guard let annotationID = db.pluck(NoteTable.table.select(NoteTable.id, NoteTable.annotationID).filter(NoteTable.id == id)).map({ $0[NoteTable.annotationID] }) else { return }

        try deleteNoteWithID(id)
        
        try trashAnnotationIfEmptyWithID(annotationID)
    }
    
    func deleteNoteWithID(id: Int64) throws {
        try db.run(NoteTable.table.filter(NoteTable.id == id).delete())
    }
    
    func deleteNotesWithAnnotationID(annotationID: Int64) throws {
        try db.run(NoteTable.table.filter(NoteTable.annotationID == annotationID).delete())
    }
    
}
