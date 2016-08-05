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

import XCTest
@testable import LDSAnnotations

class SyncAnnotationsTests: XCTestCase {

    func testNoteChange() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)

        var note = try! annotationStore1.addNote("BeforeTitle", content: "BeforeContent", docID: "1", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "1")], colorName: "yellow", style: .Highlight, iso639_3Code: "eng", source: "Test", device: "iphone")
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Make changes to note
        note.title = "AfterTitle"
        note.content = "AfterContent"
        try! annotationStore1.addOrUpdateNote(note)
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncBookmarkReorder() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        let bookmarks = [
            try! annotationStore1.addBookmark(name: "Bookmark1", paragraphAID: "1", displayOrder: 0, docID: "1", docVersion: 1, iso639_3Code: "eng", source: "Test", device: "iphone"),
            try! annotationStore1.addBookmark(name: "Bookmark2", paragraphAID: "2", displayOrder: 1, docID: "1", docVersion: 1, iso639_3Code: "eng", source: "Test", device: "iphone"),
            try! annotationStore1.addBookmark(name: "Bookmark3", paragraphAID: "3", displayOrder: 2, docID: "1", docVersion: 1, iso639_3Code: "eng", source: "Test", device: "iphone"),
            try! annotationStore1.addBookmark(name: "Bookmark4", paragraphAID: "4", displayOrder: 3, docID: "1", docVersion: 1, iso639_3Code: "eng", source: "Test", device: "iphone"),
            try! annotationStore1.addBookmark(name: "Bookmark5", paragraphAID: "5", displayOrder: 4, docID: "1", docVersion: 1, iso639_3Code: "eng", source: "Test", device: "iphone")
        ]
    
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)

        let shuffledBookmarks = bookmarks.shuffle()
        try! annotationStore1.reorderBookmarks(shuffledBookmarks)
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncAnnotationWithHighlights() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add an annotation to one annotation store
        let highlights = try! annotationStore1.addHighlights(docID: "1", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "2"), ParagraphRange(paragraphAID: "3")], colorName: "yellow", style: .Highlight, iso639_3Code: "eng", source: "Test", device: "iphone")
        let highlight1 = highlights.first!
        let highlight2 = highlights.last!
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)

        // Delete a highlight, sync the change
        try! annotationStore1.trashHighlightWithID(highlight1.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the highlight was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)

        // Delete a highlight, sync the change
        try! annotationStore1.trashHighlightWithID(highlight2.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the highlight was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncAnnotationWithLinks() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add an annotation to one annotation store
        let link1 = try! annotationStore1.addLink(name: "Link1", toDocID: "1", toDocVersion: 1, toParagraphAIDs: ["2"], fromDocID: "2", fromDocVersion: 1, fromParagraphRanges: [ParagraphRange(paragraphAID: "1")], colorName: "yellow", style: .Highlight, iso639_3Code: "eng", source: "Test", device: "iphone")
        let link2 = try! annotationStore1.addLink(name: "Link2", toDocID: "1", toDocVersion: 1, toParagraphAIDs: ["3"], annotationID: link1.annotationID)
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete a link, sync the change
        try! annotationStore1.trashLinkWithID(link1.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the link was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete a link, sync the change
        try! annotationStore1.trashLinkWithID(link2.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the link was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncAnnotationWithTags() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add an annotation to one annotation store
        let annotationID = try! annotationStore1.addHighlights(docID: "1", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "1")], colorName: "yellow", style: .Highlight, iso639_3Code: "eng", source: "Test", device: "iphone").first!.annotationID
        let tag1 = try! annotationStore1.addTag(name: "Tag1", annotationID: annotationID)
        let tag2 = try! annotationStore1.addTag(name: "Tag2", annotationID: annotationID)
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete a tag, sync the change
        try! annotationStore1.trashTagWithID(tag1.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the tag was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete a tag, sync the change
        try! annotationStore1.trashTagWithID(tag2.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the tag was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncReorderAnnotationsInNotebook() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        let notebook = try! annotationStore1.addNotebook(name: "Notebook")
        
        let note1 = try! annotationStore1.addNote(title: "Title1", content: "Content1", source: "Test", device: "iphone", notebookID: notebook.id!)
        let annotation1 = annotationStore1.annotationWithID(note1.annotationID)!
        
        let note2 = try! annotationStore1.addNote(title: "Title2", content: "Content2", source: "Test", device: "iphone", notebookID: notebook.id!)
        let annotation2 = annotationStore1.annotationWithID(note2.annotationID)!

        let note3 = try! annotationStore1.addNote(title: "Title3", content: "Content3", source: "Test", device: "iphone", notebookID: notebook.id!)
        let annotation3 = annotationStore1.annotationWithID(note3.annotationID)!

        let note4 = try! annotationStore1.addNote(title: "Title4", content: "Content4", source: "Test", device: "iphone", notebookID: notebook.id!)
        let annotation4 = annotationStore1.annotationWithID(note4.annotationID)!

        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        let shuffledAnnotationIDs = [annotation1.id, annotation2.id, annotation3.id, annotation4.id].shuffle()
        try! annotationStore1.reorderAnnotationIDs(shuffledAnnotationIDs, notebookID: notebook.id!)
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")

        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncAnnotationWithNotebooks() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add an annotation to one annotation store
        let notebook = try! annotationStore1.addNotebook(name: "Notebook1")
        let note1 = try! annotationStore1.addNote(title: "NoteTitle1", content: "NoteContent1", source: "Test", device: "iphone", notebookID: notebook.id!)
        
        let note2 = try! annotationStore1.addNote(title: "NoteTitle2", content: "NoteContent2", source: "Test", device: "iphone", notebookID: notebook.id!)
        let annotation2 = annotationStore1.annotationWithID(note2.annotationID)!
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)

        // Delete a note, sync the change
        try! annotationStore1.trashNoteWithID(note1.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the notebook was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)

        // Delete an annotation, sync the change
        try! annotationStore1.trashAnnotationWithID(annotation2.id)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the notebook was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete a notebook, sync the change
        try! annotationStore1.trashNoteWithID(notebook.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the notebook was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncAnnotationWithNote() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add an annotation to one annotation store
        let note = try! annotationStore1.addNote("NoteTitle", content: "NoteContent", docID: "1", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "1")], colorName: "yellow", style: .Highlight, iso639_3Code: "eng", source: "Test", device: "iphone")
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete a highlight, sync the change
        try! annotationStore1.trashNoteWithID(note.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the highlight was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }
    
    func testSyncAnnotationWithBookmark() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetAnnotations(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetAnnotations(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add an annotation to one annotation store
        let bookmark = try! annotationStore1.addBookmark(name: "BookmarkName", paragraphAID: "1", displayOrder: 1, docID: "1", docVersion: 1, iso639_3Code: "eng", source: "Test", device: "iphone")
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync annotations")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the changes
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
        
        // Delete bookmark and sync the change
        try! annotationStore1.trashBookmarkWithID(bookmark.id!)
        
        sync(annotationStore1, session: session1, token: &token1, description: "Sync changes")
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Get sync changes")
        
        // Verify the bookmark was removed
        verifyEqual(annotationStore1: annotationStore1, annotationStore2: annotationStore2)
    }

    func verifyEqual(annotationStore1 annotationStore1: AnnotationStore, annotationStore2: AnnotationStore) {
        let annotations1 = annotationStore1.annotations().filter { $0.status == .Active }
        let annotations2 = annotationStore2.annotations().filter { $0.status == .Active }
        XCTAssertEqual(annotations1.count, annotations2.count)
        
        let annotationHighlights1 = annotations1.map { (uniqueID: $0.uniqueID, highlights: annotationStore1.highlightsWithAnnotationID($0.id)) }
        let annotationHighlights2 = annotations2.map { (uniqueID: $0.uniqueID, highlights: annotationStore2.highlightsWithAnnotationID($0.id)) }
        XCTAssertEqual(annotationHighlights1.count, annotationHighlights2.count)
        
        let annotationLinks1 = annotations1.map { (uniqueID: $0.uniqueID, links: annotationStore1.linksWithAnnotationID($0.id)) }
        let annotationLinks2 = annotations2.map { (uniqueID: $0.uniqueID, links: annotationStore2.linksWithAnnotationID($0.id)) }
        XCTAssertEqual(annotationLinks1.count, annotationLinks2.count)
        
        let annotationTags1 = annotations1.map { (uniqueID: $0.uniqueID, tags: annotationStore1.tagsWithAnnotationID($0.id)) }
        let annotationTags2 = annotations2.map { (uniqueID: $0.uniqueID, tags: annotationStore2.tagsWithAnnotationID($0.id)) }
        XCTAssertEqual(annotationTags1.count, annotationTags2.count)
        
        let annotationNotebooks1 = annotations1.map { (uniqueID: $0.uniqueID, notebooks: annotationStore1.notebooksWithAnnotationID($0.id)) }
        let annotationNotebooks2 = annotations2.map { (uniqueID: $0.uniqueID, notebooks: annotationStore2.notebooksWithAnnotationID($0.id)) }
        XCTAssertEqual(annotationNotebooks1.count, annotationNotebooks2.count)
        
        let annotationNotes1 = annotations1.map { (uniqueID: $0.uniqueID, note: annotationStore1.noteWithAnnotationID($0.id)) }
        let annotationNotes2 = annotations2.map { (uniqueID: $0.uniqueID, note: annotationStore2.noteWithAnnotationID($0.id)) }
        XCTAssertEqual(annotationNotes1.count, annotationNotes2.count)
        
        let annotationBookmarks1 = annotations1.map { (uniqueID: $0.uniqueID, bookmark: annotationStore1.bookmarkWithAnnotationID($0.id)) }
        let annotationBookmarks2 = annotations2.map { (uniqueID: $0.uniqueID, bookmark: annotationStore2.bookmarkWithAnnotationID($0.id)) }
        XCTAssertEqual(annotationBookmarks1.count, annotationBookmarks2.count)
        
        let notebooks1 = annotationStore1.notebooks().filter { $0.status == .Active }
        let notebooks2 = annotationStore1.notebooks().filter { $0.status == .Active }
        XCTAssertEqual(notebooks1.count, notebooks2.count)
        
        let notebookAnnotations1 = notebooks1.map { (uniqueID: $0.uniqueID, annotations: annotationStore1.annotationsWithNotebookID($0.id!)) }
        let notebookAnnotations2 = notebooks2.map { (uniqueID: $0.uniqueID, annotations: annotationStore2.annotationsWithNotebookID($0.id!)) }
        
        for (uniqueID, highlights1) in annotationHighlights1 {
            guard let highlights2 = annotationHighlights2.find({ $0.uniqueID == uniqueID }).map({ $0.highlights }) else {
                // No highlights2 found, assert that highlights1 is empty
                XCTAssertTrue(highlights1.isEmpty)
                continue
            }
            XCTAssertEqual(highlights1.count, highlights2.count)
            
            XCTAssertEqual(Set(highlights1.map({ HighlightShell(paragraphRange: $0.paragraphRange, colorName: $0.colorName, style: $0.style) })), Set(highlights2.map({ HighlightShell(paragraphRange: $0.paragraphRange, colorName: $0.colorName, style: $0.style) })))
        }
        
        for (uniqueID, links1) in annotationLinks1 {
            guard let links2 = annotationLinks2.find({ $0.uniqueID == uniqueID }).map({ $0.links }) else {
                // No links2 found, assert that links1 is empty
                XCTAssertTrue(links1.isEmpty)
                continue
            }
            XCTAssertEqual(links1.count, links2.count)
            
            XCTAssertEqual(Set(links1.map({ LinkShell(name: $0.name, docID: $0.docID, docVersion: $0.docVersion, paragraphAIDs: $0.paragraphAIDs) })), Set(links2.map({ LinkShell(name: $0.name, docID: $0.docID, docVersion: $0.docVersion, paragraphAIDs: $0.paragraphAIDs) })))
        }
        
        for (uniqueID, tags1) in annotationTags1 {
            guard let tags2 = annotationTags2.find({ $0.uniqueID == uniqueID }).map({ $0.tags }) else {
                // No tags2 found, assert that tags1 is empty
                XCTAssertTrue(tags1.isEmpty)
                continue
            }
            XCTAssertEqual(tags1.count, tags2.count)
            
            XCTAssertEqual(Set(tags1.map({ $0.name })), Set(tags2.map({$0.name })))
        }
        
        for (uniqueID, notebooks1) in annotationNotebooks1 {
            guard let notebooks2 = annotationNotebooks2.find({ $0.uniqueID == uniqueID }).map({ $0.notebooks }) else {
                // No notebooks2 found, assert that notebooks1 is empty
                XCTAssertTrue(notebooks1.isEmpty)
                continue
            }
            XCTAssertEqual(notebooks1.count, notebooks2.count)
            
            XCTAssertEqual(Set(notebooks1.map({ NotebookShell(name: $0.name, status: $0.status, uniqueID: $0.uniqueID, description: $0.description) })), Set(notebooks2.map({ NotebookShell(name: $0.name, status: $0.status, uniqueID: $0.uniqueID, description: $0.description) })))
        }
        
        for (uniqueID, note1) in annotationNotes1 {
            guard let note2 = annotationNotes2.find({ $0.uniqueID == uniqueID}).map({ $0.note }) else {
                XCTAssertNil(note1)
                continue
            }
            XCTAssertEqual(note1.map({ NoteShell(title: $0.title, content: $0.content)}), note2.map({ NoteShell(title: $0.title, content: $0.content)}))
        }
        
        for (uniqueID, bookmark1) in annotationBookmarks1 {
            guard let bookmark2 = annotationBookmarks2.find({ $0.uniqueID == uniqueID}).map({ $0.bookmark }) else {
                XCTAssertNil(bookmark1)
                continue
            }
            XCTAssertEqual(bookmark1.map({ BookmarkShell(name: $0.name, paragraphAID: $0.paragraphAID, displayOrder: $0.displayOrder) }), bookmark2.map({ BookmarkShell(name: $0.name, paragraphAID: $0.paragraphAID, displayOrder: $0.displayOrder) }))
        }
        
        for (uniqueID, annotations1) in notebookAnnotations1 {
            guard let annotations2 = notebookAnnotations2.find({ $0.uniqueID == uniqueID }).map({ $0.annotations }) else {
                // No annotations2 found, assert that annotations1 is empty
                XCTAssertTrue(annotations1.isEmpty)
                continue
            }
            XCTAssertEqual(annotations1.count, annotations2.count)
            
            // Don't use a Set here because we're testing the order as well
            XCTAssertEqual(annotations1.map({ $0.uniqueID }), annotations2.map({ $0.uniqueID }))
        }
    }
    
}

private struct HighlightShell: Equatable, Hashable {
    var paragraphRange: ParagraphRange
    var colorName: String
    var style: HighlightStyle
    var hashValue: Int { return paragraphRange.hashValue ^ colorName.hashValue ^ style.rawValue.hashValue }
}

private func == (lhs: HighlightShell, rhs: HighlightShell) -> Bool {
    return lhs.paragraphRange == rhs.paragraphRange && lhs.colorName == rhs.colorName && lhs.style == rhs.style
}

private struct NoteShell: Equatable, Hashable {
    var title: String?
    var content: String
    var hashValue: Int { return (title ?? "").hashValue ^ content.hashValue }
}

private func == (lhs: NoteShell, rhs: NoteShell) -> Bool {
    return lhs.title == rhs.title && lhs.content == rhs.content
}

private struct BookmarkShell: Equatable, Hashable {
    var name: String?
    var paragraphAID: String?
    var displayOrder: Int?
    var hashValue: Int { return (name ?? "").hashValue ^ (paragraphAID ?? "").hashValue ^ (displayOrder ?? 0).hashValue }
}

private func == (lhs: BookmarkShell, rhs: BookmarkShell) -> Bool {
    return lhs.name == rhs.name && lhs.paragraphAID == rhs.paragraphAID && lhs.displayOrder == rhs.displayOrder
}

private struct LinkShell: Equatable, Hashable {
    var name: String
    var docID: String
    var docVersion: Int
    var paragraphAIDs: [String]
    var hashValue: Int { return name.hashValue ^ docID.hashValue ^ docVersion.hashValue ^ paragraphAIDs.sort().joinWithSeparator(",").hashValue }
}

private func == (lhs: LinkShell, rhs: LinkShell) -> Bool {
    return lhs.name == rhs.name && lhs.docID == rhs.docID && lhs.docVersion == rhs.docVersion && lhs.paragraphAIDs.sort().joinWithSeparator(",") == rhs.paragraphAIDs.sort().joinWithSeparator(",")
}

private struct NotebookShell: Equatable, Hashable {
    var name: String
    var status: AnnotationStatus
    var uniqueID: String
    var description: String?
    var hashValue: Int { return name.hashValue ^ status.rawValue.hashValue ^ uniqueID.hashValue ^ (description ?? "").hashValue }
}

private func == (lhs: NotebookShell, rhs: NotebookShell) -> Bool {
    return lhs.name == rhs.name && lhs.status == rhs.status && lhs.uniqueID == rhs.uniqueID && lhs.description == rhs.description
}

