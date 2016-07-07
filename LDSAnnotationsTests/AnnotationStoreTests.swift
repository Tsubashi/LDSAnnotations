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

// swiftlint:disable force_unwrapping

class AnnotationStoreTests: XCTestCase {

    private let alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
    
    func testAddAndUpdateNotebook() {
        let annotationStore = AnnotationStore()!
        
        let addExpectation = expectationWithDescription("Notebook added")
        let addObserver = annotationStore.notebookObservers.add { source, notebooks in
            if source == .Local && notebooks.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        var notebook = try! annotationStore.addNotebook(name: "Test Notebook")
        annotationStore.notebookObservers.remove(addObserver)
        
        let updateExpectation = expectationWithDescription("Notebook updated")
        let updateObserver = annotationStore.notebookObservers.add { source, notebooks in
            if source == .Local && notebooks.count == 1 {
                updateExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        notebook.name = "Renamed Notebook"
        try! annotationStore.updateNotebook(notebook)
        annotationStore.notebookObservers.remove(updateObserver)
        
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testAddNote() {
        let annotationStore = AnnotationStore()!
        let noteToAdd = Note(id: nil, title: nil, content: "", annotationID: 1)
        try! annotationStore.addOrUpdateNote(noteToAdd)
        let expected = Note(id: 1, title: nil, content: "", annotationID: 1)
        let actual = annotationStore.noteWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testAddBookmark() {
        let annotationStore = AnnotationStore()!
        let bookmarkToAdd = Bookmark(id: nil, name: "Test", paragraphAID: nil, displayOrder: 5, annotationID: 1, offset: 0)
        try! annotationStore.addOrUpdateBookmark(bookmarkToAdd)
        let expected = Bookmark(id: 1, name: "Test", paragraphAID: nil, displayOrder: 5, annotationID: 1, offset: 0)
        let actual = annotationStore.bookmarkWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testAddLink() {
        let annotationStore = AnnotationStore()!
        let linkToAdd = Link(id: nil, name: "Link", docID: "DocID", docVersion: 1, paragraphAIDs: ["ParagraphID"], annotationID: 1)
        try! annotationStore.addOrUpdateLink(linkToAdd)
        let expected = Link(id: 1, name: "Link", docID: "DocID", docVersion: 1, paragraphAIDs: ["ParagraphID"], annotationID: 1)
        let actual = annotationStore.linkWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testTagsOrderedByName() {
        let annotationStore = AnnotationStore(path: "")!
        
        var tags = [Tag]()
        var annotations = [Annotation]()
        var date = NSDate()
        
        for i in 0..<alphabet.count {
            for j in i..<alphabet.count {
                let tag = try! annotationStore.addOrUpdateTag(Tag(id: nil, name: alphabet[i]))
                tags.append(tag)
                
                let annotation = try! annotationStore.addOrUpdateAnnotation(Annotation(id: nil, uniqueID: "\(i)_\(j)", iso639_3Code: "eng", docID: alphabet[i], docVersion: 1, type: .Journal, status: .Active, created: nil, lastModified: date, source: nil, device: nil))
                annotations.append(annotation)
                
                try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id!, tagID: tag.id!)
            }
            
            date = date.dateByAddingTimeInterval(1)
        }
        
        let byName = annotationStore.tags(orderBy: .Name)
        XCTAssertEqual(byName.map { $0.name }, alphabet)
        
        let byNameWithIDs = annotationStore.tags(ids: [5, 10, 15], orderBy: .Name)
        XCTAssertEqual(byNameWithIDs.map { $0.name }, ["e", "j", "o"])

        let actualMostRecent = annotationStore.tags(orderBy: .MostRecent).map { $0.name }
        XCTAssert(actualMostRecent == Array(alphabet.reverse()), "Most recent tags ordered incorrectly")

        let actualMostRecentWithIDs = annotationStore.tags(ids: [5, 10, 15], orderBy: .MostRecent).map { $0.name }
        XCTAssert(actualMostRecentWithIDs == ["o", "j", "e"], "Most recent tags with ids ordered incorrectly")

        let byNumberOfAnnotations = annotationStore.tags(orderBy: .NumberOfAnnotations).map { $0.name }
        XCTAssertEqual(byNumberOfAnnotations, alphabet, "Tags ordered by number of annotations is ordered incorrectly")
        
        let byNumberOfAnnotationsWithIDs = annotationStore.tags(ids: [5, 10, 15], orderBy: .NumberOfAnnotations).map { $0.name }
        XCTAssertEqual(byNumberOfAnnotationsWithIDs, ["e", "j", "o"], "Tags ordered by number of annotations is ordered incorrectly")
    }
    
    func testNotebooksOrderBy() {
        let annotationStore = AnnotationStore()!
        
        var date = NSDate()
        var notebooks = [Notebook]()
        for i in 0..<alphabet.count {
            let notebook = Notebook(id: nil, uniqueID: "\(i)", name: alphabet[i], description: nil, status: .Active, lastModified: date)
            notebooks.append(annotationStore.addOrUpdateNotebook(notebook)!)
            date = date.dateByAddingTimeInterval(1)
        }
        
        var annotations = [Annotation]()
        
        for i in 0..<alphabet.count {
            let annotation = Annotation(id: nil, uniqueID: "\(i)", iso639_3Code: "eng", docID: alphabet[i], docVersion: 1, type: .Journal, status: .Active, created: nil, lastModified: NSDate(), source: nil, device: nil)
            annotations.append(try! annotationStore.addOrUpdateAnnotation(annotation))
        }
        
        for i in 1...alphabet.count {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 5, displayOrder: i)
        }
        
        for i in 1...Int(alphabet.count / 2) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 10, displayOrder: i)
        }
        
        for i in 1...Int(alphabet.count / 3) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 15, displayOrder: i)
        }
        
        for i in 1...Int(alphabet.count / 5) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 20, displayOrder: i)
        }
        
        let byName = annotationStore.notebooks(orderBy: .Name)
        XCTAssertEqual(byName.map { $0.name }, alphabet)
        
        let byNameWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .Name)
        XCTAssertEqual(byNameWithIDs.map { $0.name }, ["e", "j", "o"])
        
        let actualMostRecent = annotationStore.notebooks(orderBy: .MostRecent).map { $0.name }
        XCTAssert(actualMostRecent == Array(alphabet.reverse()), "Most recent notebooks ordered incorrectly")
        
        let actualMostRecentWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .MostRecent).map { $0.name }
        XCTAssert(actualMostRecentWithIDs == ["o", "j", "e"], "Most recent notebooks with ids ordered incorrectly")
        
        let byNumberOfAnnotations = annotationStore.notebooks(orderBy: .NumberOfAnnotations).map { $0.name }
        let expected = ["e", "j", "o", "t", "a", "b", "c", "d", "f", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "u", "v", "w", "x", "y", "z"]
        XCTAssertEqual(byNumberOfAnnotations, expected, "Notebooks ordered by number of annotations is ordered incorrectly")
        
        let byNumberOfAnnotationsWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .NumberOfAnnotations).map { $0.name }
        XCTAssertEqual(byNumberOfAnnotationsWithIDs, ["e", "j", "o"], "Notebooks ordered by number of annotations is ordered incorrectly")
    }
    
    func testAnnotationWithID() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        
        XCTAssertEqual(annotation.uniqueID, annotationStore.annotationWithID(annotation.id!)!.uniqueID, "Annotations should be the same")
    }
    
    func testCreateAndTrashTags() {
        let annotationStore = AnnotationStore()!

        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        
        let tags = ["sally", "sells", "seashells", "by", "the", "seashore"].map { try! annotationStore.addTag(name: $0) }
        
        for tag in tags {
            try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id!, tagID: tag.id!)
        }
        
        XCTAssertEqual(tags.map({ $0.id! }), annotationStore.tagsWithAnnotationID(annotation.id!).map({ $0.id! }), "Loaded tags should equal inserted tags")
        
        // Verify tags are trashed correctly
        for tag in tags {
            // Verify annotation hasn't been marked as trashed yet because its not empty
            XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Active)
            
            try! annotationStore.trashTagWithID(tag.id!)

            // Verify tag has been deleted
            XCTAssertNil(annotationStore.tagWithName(tag.name))
            
            // Verify no annotations are associated with tag
            XCTAssertTrue(annotationStore.annotationsWithTagID(tag.id!).isEmpty)
        }

        // Verify annotation has been marked at .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Trashed)
    }
    
    func testCreateAndTrashLinks() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        
        let links = [
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link1", docID: "1", docVersion: 1, paragraphAIDs: ["1"], annotationID: annotation.id!)),
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link2", docID: "2", docVersion: 1, paragraphAIDs: ["1", "2"], annotationID: annotation.id!)),
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link3", docID: "3", docVersion: 1, paragraphAIDs: ["1", "2", "3"], annotationID: annotation.id!)),
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link4", docID: "4", docVersion: 1, paragraphAIDs: ["1", "2", "3", "4"], annotationID: annotation.id!))
        ]

        XCTAssertEqual(links.map({ $0.id! }), annotationStore.linksWithAnnotationID(annotation.id!).map({ $0.id! }), "Loaded links should match what was inserted")

        // Verify links are trashed correctly
        for link in links {
            // Verify annotation hasn't been marked as trashed yet because its not empty
            XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Active)
            
            try! annotationStore.trashLinkWithID(link.id!)
            
            // Verify tag has been deleted
            XCTAssertNil(annotationStore.linkWithID(link.id!))
            
            // Verify no annotations are associated with tag
            XCTAssertNil(annotationStore.annotationWithLinkID(link.id!))
        }
        
        // Verify annotation has been marked at .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Trashed)
    }
    
    func testCreateAndTrashBookmark() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark1", paragraphAID: nil, displayOrder: 1, annotationID: annotation.id!)
        
        XCTAssertEqual(bookmark.id!, annotationStore.bookmarkWithAnnotationID(annotation.id!)!.id!, "Loaded bookmark should match what was inserted")
        
        // Verify bookmark is trashed correctly
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Active)
        
        try! annotationStore.trashBookmarkWithID(bookmark.id!)
        
        // Verify tag has been deleted
        XCTAssertNil(annotationStore.bookmarkWithID(bookmark.id!))
        
        // Verify no annotations are associated with tag
        XCTAssertNil(annotationStore.annotationWithBookmarkID(bookmark.id!))
        
        // Verify annotation has been marked at .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Trashed)
    }
    
    func testCreateAndTrashNote() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        
        let note = try! annotationStore.addNote("Title", content: "Content", annotationID: annotation.id!)
        
        XCTAssertEqual(note.id!, annotationStore.noteWithAnnotationID(annotation.id!)!.id!, "Loaded note should match what was inserted")
        
        // Verify note is trashed correctly
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Active)
        
        try! annotationStore.trashNoteWithID(note.id!)
        
        // Verify tag has been deleted
        XCTAssertNil(annotationStore.noteWithID(note.id!))
        
        // Verify no annotations are associated with tag
        XCTAssertNil(annotationStore.annotationWithNoteID(note.id!))
        
        // Verify annotation has been marked at .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id!)?.status == .Trashed)
    }
    
    func testTagsContainingString() {
        let annotationStore = AnnotationStore()!
        
        ["sally", "sells", "seashells", "by", "the", "seashore"].forEach { try! annotationStore.addTag(name: $0) }
        
        XCTAssertEqual(annotationStore.tagsContainingString("sea").map({ $0.name }), ["seashells", "seashore"].sort(), "Tags containing string missing tags")
    }
    
    func testInsertingDuplicateTags() {
        let annotationStore = AnnotationStore()!
        
        let names = ["sally", "sells", "seashells", "by", "the", "seashore"].sort()
        for name in names {
            try! annotationStore.addTag(name: name)
            try! annotationStore.addTag(name: name.capitalizedStringWithLocale(nil))
            try! annotationStore.addTag(name: name.uppercaseString)
            try! annotationStore.addTag(name: name)
        }
       
        XCTAssertEqual(names, annotationStore.tags().map({ $0.name }), "Duplicate tags loaded from the database")
    }
    
    func testAnnotationWithBookmarkID() {
        let annotationStore = AnnotationStore()!
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark", paragraphAID: nil, displayOrder: 1, annotationID: annotation.id!)

        XCTAssertEqual(annotation.id!, annotationStore.annotationWithBookmarkID(bookmark.id!)!.id!, "Annotation did not load correctly from database")
    }
    
    func testAnnotationWithNoteID() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        
        let note = try! annotationStore.addNote("Title", content: "Content", annotationID: annotation.id!)
        
        XCTAssertEqual(annotation.id!, annotationStore.annotationWithNoteID(note.id!)!.id!, "Annotation did not load correctly from database")
    }
    
    func testAnnotationWithLinkID() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        let links = [
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link1", docID: "1", docVersion: 1, paragraphAIDs: ["1"], annotationID: annotation.id!)),
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link2", docID: "2", docVersion: 1, paragraphAIDs: ["1", "2"], annotationID: annotation.id!)),
        ]
        
        for link in links {
            // Verify annotationloads correctly
            XCTAssertEqual(annotation.id!, annotationStore.annotationWithLinkID(link.id!)!.id!, "Annotation did not load correctly from database")
        }
        
        let annotation2 = try! annotationStore.addAnnotation("eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        let links2 = [
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link3", docID: "3", docVersion: 1, paragraphAIDs: ["1", "2", "3"], annotationID: annotation2.id!)),
            try! annotationStore.addOrUpdateLink(Link(id: nil, name: "Link4", docID: "4", docVersion: 1, paragraphAIDs: ["1", "2", "3", "4"], annotationID: annotation2.id!))
        ]
        
        for link in links2 {
            // Verify annotationloads correctly
            XCTAssertEqual(annotation2.id!, annotationStore.annotationWithLinkID(link.id!)!.id!, "Annotation did not load correctly from database")
        }
    }
    
}

extension String {
    
    subscript (i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        let start = startIndex.advancedBy(r.startIndex)
        let end = start.advancedBy(r.endIndex - r.startIndex)
        return self[Range(start ..< end)]
    }
    
}
