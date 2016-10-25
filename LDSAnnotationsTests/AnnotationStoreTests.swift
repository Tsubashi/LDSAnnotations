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
    
    func testAddNote() {
        let annotationStore = AnnotationStore()!
        let expected = try! annotationStore.addNote(title: nil, content: "", annotationID: 1, source: .Local)
        let actual = annotationStore.noteWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testAddBookmark() {
        let annotationStore = AnnotationStore()!
        try! annotationStore.addBookmark(name: "Test", paragraphAID: nil, displayOrder: 5, annotationID: 1, offset: 0, source: .Local)
        let expected = Bookmark(id: 1, name: "Test", paragraphAID: nil, displayOrder: 5, annotationID: 1, offset: 0)
        let actual = annotationStore.bookmarkWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testAddLink() {
        let annotationStore = AnnotationStore()!
        try! annotationStore.addLink(name: "Link", docID: "DocID", docVersion: 1, paragraphAIDs: ["ParagraphID"], annotationID: 1, source: .Local)
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
                let tag = try! annotationStore.addTag(name: alphabet[i], source: .Local)
                tags.append(tag)
                
                let annotation = try! annotationStore.addAnnotation(uniqueID: "\(i)_\(j)", docID: alphabet[i], docVersion: 1, lastModified: date, appSource: "Test", device: "iphone", source: .Local)
                annotations.append(annotation)
                
                try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id, tagID: tag.id, source: .Local)
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
            notebooks.append(try! annotationStore.addNotebook(uniqueID: "\(i)", name: alphabet[i], description: nil, status: .Active, lastModified: date, source: .Local))
            date = date.dateByAddingTimeInterval(1)
        }
        
        var annotations = [Annotation]()
        
        for i in 0..<alphabet.count {
            annotations.append(try! annotationStore.addAnnotation(uniqueID: "\(i)", docID: alphabet[i], docVersion: 1, status: .Active, created: nil, lastModified: NSDate(), appSource: "Test", device: "iphone", source: .Local))
        }
        
        for i in 1...alphabet.count {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 5, displayOrder: i, source: .Local)
        }
        
        for i in 1...Int(alphabet.count / 2) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 10, displayOrder: i, source: .Local)
        }
        
        for i in 1...Int(alphabet.count / 3) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 15, displayOrder: i, source: .Local)
        }
        
        for i in 1...Int(alphabet.count / 5) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 20, displayOrder: i, source: .Local)
        }
        
        let byName = annotationStore.notebooks(orderBy: .Name)
        XCTAssertEqual(byName.map { $0.name }, alphabet)
        
        let byNameWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .Name)
        XCTAssertEqual(byNameWithIDs.map { $0.name }, ["e", "j", "o"])
        
        let actualMostRecent = annotationStore.notebooks(orderBy: .MostRecent).map { $0.name }
        XCTAssertEqual(actualMostRecent, ["z", "y", "x", "w", "v", "u", "s", "r", "q", "p", "n", "m", "l", "k", "i", "h", "g", "f", "d", "c", "b", "t", "o", "j", "e", "a"], "Most recent notebooks ordered incorrectly")
        
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
        
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        
        XCTAssertEqual(annotation.uniqueID, annotationStore.annotationWithID(annotation.id)!.uniqueID, "Annotations should be the same")
    }
    
    func testCreateAndTrashTags() {
        let annotationStore = AnnotationStore()!

        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        
        let tags = ["sally", "sells", "seashells", "by", "the", "seashore"].map { try! annotationStore.addTag(name: $0) }
        
        for tag in tags {
            try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id, tagID: tag.id)
        }
        
        XCTAssertEqual(tags.sort({ $0.name < $1.name }).map({ $0.id }), annotationStore.tagsWithAnnotationID(annotation.id).map({ $0.id }), "Loaded tags should equal inserted tags")
        
        // Verify tags are trashed correctly
        for tag in tags {
            // Verify annotation hasn't been marked as trashed yet because its not empty
            XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Active)
            
            try! annotationStore.trashTagWithID(tag.id, source: .Local)

            // Verify tag has been deleted
            XCTAssertNil(annotationStore.tagWithName(tag.name))
            
            // Verify no annotations are associated with tag
            XCTAssertTrue(annotationStore.annotationsWithTagID(tag.id).isEmpty)
        }

        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Trashed)
    }
    
    func testCreateAndTrashLinks() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        
        let links = [
            try! annotationStore.addLink(name: "Link1", docID: "13859831", docVersion: 1, paragraphAIDs: ["1"], annotationID: annotation.id, source: .Local),
            try! annotationStore.addLink(name: "Link2", docID: "20056230", docVersion: 1, paragraphAIDs: ["1", "2"], annotationID: annotation.id, source: .Local),
            try! annotationStore.addLink(name: "Link3", docID: "20056129", docVersion: 1, paragraphAIDs: ["1", "2", "3"], annotationID: annotation.id, source: .Local),
            try! annotationStore.addLink(name: "Link4", docID: "20056278", docVersion: 1, paragraphAIDs: ["1", "2", "3", "4"], annotationID: annotation.id, source: .Local)
        ]

        XCTAssertEqual(links.map({ $0.id }), annotationStore.linksWithAnnotationID(annotation.id).map({ $0.id }), "Loaded links should match what was inserted")

        // Verify links are trashed correctly
        for link in links {
            // Verify annotation hasn't been marked as trashed yet because its not empty
            XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Active)
            
            try! annotationStore.trashLinkWithID(link.id)
            
            // Verify tag has been deleted
            XCTAssertNil(annotationStore.linkWithID(link.id))
            
            // Verify no annotations are associated with tag
            XCTAssertNil(annotationStore.annotationWithLinkID(link.id))
        }
        
        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Trashed)
    }
    
    func testCreateAndTrashBookmark() {
        let annotationStore = AnnotationStore()!
        
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark1", paragraphAID: nil, displayOrder: 1, docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        
        let annotation = annotationStore.annotationWithID(bookmark.annotationID)!
        
        XCTAssertEqual(bookmark.id, annotationStore.bookmarkWithAnnotationID(annotation.id)!.id, "Loaded bookmark should match what was inserted")
        
        // Verify bookmark is trashed correctly
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Active)
        
        try! annotationStore.trashBookmarkWithID(bookmark.id, source: .Local)
        
        // Verify tag has been deleted
        XCTAssertNil(annotationStore.bookmarkWithID(bookmark.id))
        
        // Verify no annotations are associated with tag
        XCTAssertNil(annotationStore.annotationWithBookmarkID(bookmark.id))
        
        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Trashed)
    }
    
    func testBookmarksWithDocID() {
        let annotationStore = AnnotationStore()!
        
        let docID = "12345"
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark1", paragraphAID: nil, displayOrder: 1, docID: docID, docVersion: 1, appSource: "Test", device: "iphone")
        
        XCTAssertTrue(annotationStore.bookmarks(docID: docID).first == bookmark)
    }
    
    func testBookmarksWithParagraphAID() {
        let annotationStore = AnnotationStore()!
        
        let paragraphAID = "12345"
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark1", paragraphAID: paragraphAID, displayOrder: 1, docID: "20056057",  docVersion: 1, appSource: "Test", device: "iphone")
        
        XCTAssertTrue(annotationStore.bookmarks(paragraphAID: paragraphAID).first == bookmark)
    }
    
    func testCreateAndTrashNote() {
        let annotationStore = AnnotationStore()!
        
        let note = try! annotationStore.addNote("Title", content: "content", docID: "13859831", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "12345")], colorName: "yellow", style: .Underline, appSource: "Test", device: "iphone")
        
        let annotation = annotationStore.annotationWithID(note.annotationID)!
        
        XCTAssertEqual(note, annotationStore.noteWithAnnotationID(note.annotationID)!, "Loaded note should match what was inserted")
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotation.status == .Active)
        
        try! annotationStore.trashNoteWithID(note.id)
        
        // Verify note has been deleted
        XCTAssertNil(annotationStore.noteWithID(note.id))
        
        // Verify no annotations are associated with note
        XCTAssertNil(annotationStore.annotationWithNoteID(note.id))
        
        // Verify annotation still has highlights and is still active
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Active)
        XCTAssertTrue(!annotationStore.highlightsWithAnnotationID(annotation.id).isEmpty)
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
        
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark", paragraphAID: nil, displayOrder: 1, docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone")

        XCTAssertEqual(bookmark.annotationID, annotationStore.annotationWithBookmarkID(bookmark.id)!.id, "Annotation did not load correctly from database")
    }
    
    func testAnnotationWithNoteID() {
        let annotationStore = AnnotationStore()!
        
        let note = try! annotationStore.addNote("Title", content: "Content", docID: "13859831", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "12345")], colorName: "yellow", style: .Highlight, appSource: "Test", device: "ipad")
        
        XCTAssertEqual(note.annotationID, annotationStore.annotationWithNoteID(note.id)!.id, "Annotation did not load correctly from database")
    }
    
    func testAnnotationWithLinkID() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        let links = [
            try! annotationStore.addLink(name: "Link1", docID: "13859831", docVersion: 1, paragraphAIDs: ["1"], annotationID: annotation.id, source: .Local),
            try! annotationStore.addLink(name: "Link2", docID: "20056230", docVersion: 1, paragraphAIDs: ["1", "2"], annotationID: annotation.id, source: .Local),
        ]
        
        for link in links {
            // Verify annotationloads correctly
            XCTAssertEqual(annotation.id, annotationStore.annotationWithLinkID(link.id)!.id, "Annotation did not load correctly from database")
        }
        
        let annotation2 = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        let links2 = [
            try! annotationStore.addLink(name: "Link3", docID: "20056129", docVersion: 1, paragraphAIDs: ["1", "2", "3"], annotationID: annotation2.id, source: .Local),
            try! annotationStore.addLink(name: "Link4", docID: "20056278", docVersion: 1, paragraphAIDs: ["1", "2", "3", "4"], annotationID: annotation2.id, source: .Local)
        ]
        
        for link in links2 {
            // Verify annotationloads correctly
            XCTAssertEqual(annotation2.id, annotationStore.annotationWithLinkID(link.id)!.id, "Annotation did not load correctly from database")
        }
    }
    
    func testGetAnnotations() {
        let annotationStore = AnnotationStore()!
        
        let docID = "12345"
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        ]
        
        XCTAssertEqual(Set(annotations.map({ $0.uniqueID })), Set(annotationStore.annotations(docID: docID).map({ $0.uniqueID })))
        
        let paragraphRanges = [
            ParagraphRange(paragraphAID: "1"),
            ParagraphRange(paragraphAID: "2"),
            ParagraphRange(paragraphAID: "3"),
            ParagraphRange(paragraphAID: "3"),
            ParagraphRange(paragraphAID: "4")
        ]

        let highlights = try! annotationStore.addHighlights(docID: docID, docVersion: 1, paragraphRanges: paragraphRanges, colorName: "yellow", style: .Highlight, appSource: "Test", device: "iphone")
        let annotation = annotationStore.annotationWithID(highlights.first!.annotationID)
        
        XCTAssertEqual([annotation!], annotationStore.annotations(paragraphAIDs: paragraphRanges.map({ $0.paragraphAID })))
        XCTAssertEqual([annotation!], annotationStore.annotations(docID: docID, paragraphAIDs: paragraphRanges.map({ $0.paragraphAID })))
    }
    
    func testGetAnnotationIDsWithDocIDs() {
        let annotationStore = AnnotationStore()!
        
        let docID1 = "1"
        let docID2 = "2"
        let docID3 = "3"
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: docID1, docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: docID2, docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        ]
        try! annotationStore.addAnnotation(docID: docID3, docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        
        XCTAssertEqual(Set(annotations.map({ $0.id })), Set(annotationStore.annotationIDsWithDocIDsIn([docID1, docID2])))
    }
    
    func testGetAnnotationIDsForNotebook() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        var annotationIDs = [Int64]()
        
        for letter in alphabet {
            let note = try! annotationStore.addNote(title: nil, content: letter, appSource: "Test", device: "iphone", notebookID: notebook.id)
            annotationIDs.append(note.annotationID)
        }

        XCTAssertEqual(alphabet.count, annotationStore.annotationIDsForNotebookWithID(notebook.id).count, "Didn't load all annotation IDs")
    }
    
    func testGetAnnotationIDsForTag() {
        let annotationStore = AnnotationStore()!
        
        var annotationIDs = [Int64]()
        var tagNameToAnnotationIDs = [String: [Int64]]()
        
        for letter in alphabet {
            let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
            annotationIDs.append(annotation.id)
            
            for annotationID in annotationIDs {
                try! annotationStore.addTag(name: letter, annotationID: annotationID)
            }
            
            tagNameToAnnotationIDs[letter] = annotationIDs
        }
        
        for tagName in tagNameToAnnotationIDs.keys {
            let tag = annotationStore.tagWithName(tagName)!
            let annotationIDs = tagNameToAnnotationIDs[tagName]!
            
            XCTAssertTrue(Set(annotationIDs) == Set(annotationStore.annotationIDsForTagWithID(tag.id)), "Didn't load correct annotations for tagID")
        }
    }
    
    func testGetAnnotationIDs() {
        let annotationStore = AnnotationStore()!
        
        var annotations = [Annotation]()
        for _ in 0..<20 {
            annotations.append(try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local))
        }
        
        for limit in [1, 5, 10, 15, 20] {
            XCTAssertEqual(limit, annotationStore.annotationIDs(limit: limit).count, "Didn't load correct number of annotation IDs for notebook")
        }
        
        for i in 0..<10 {
            try! annotationStore.trashAnnotationWithID(annotations[i].id)
        }
        XCTAssertEqual(10, annotationStore.annotationIDs(limit: 20).count)
    }
    
    func testGetAnnotationIDsWithLastModified() {
        let annotationStore = AnnotationStore()!
        
        var annotations = [Annotation]()
        for _ in 0..<20 {
            annotations.append(try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local))
        }
        
        let idsAndModified = annotationStore.annotationIDsWithLastModified()
        XCTAssertEqual(idsAndModified.count, 20)
    }
    
    func testGetAnnotationsLinkedToDocID() {
        let annotationStore = AnnotationStore()!
        
        let docID = "2"
        let linkedToDocID = "1"
        
        var annotations = [Annotation]()
        var links = [Link]()
        
        for letter in alphabet {
            let link = try! annotationStore.addLink(name: letter, toDocID: linkedToDocID, toDocVersion: 1, toParagraphAIDs: ["1"], fromDocID: docID, fromDocVersion: 1, fromParagraphRanges: [ParagraphRange(paragraphAID: "1")], colorName: "yellow", style: .Highlight, appSource: "Test", device: "iphone")
            annotations.append(annotationStore.annotationWithID(link.annotationID)!)
            
            links.append(link)
        }
        
        XCTAssertEqual(annotations.map { $0.uniqueID }, annotationStore.annotationsLinkedToDocID(linkedToDocID).map { $0.uniqueID })
    }
    
    func testGetNumberOfAnnotations() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerate() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        XCTAssertEqual(annotationStore.numberOfAnnotations(notebookID: notebook.id), annotations.count)
    }
    
    func testReorderAnnotationIDs() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerate() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        let reversedAnnotationIDs = Array(annotations.map { $0.id }.reverse())
        try! annotationStore.reorderAnnotationIDs(reversedAnnotationIDs, notebookID: notebook.id)

        XCTAssertEqual(reversedAnnotationIDs, annotationStore.annotationIDsForNotebookWithID(notebook.id))
    }
    
    func testDeleteAnnotationNotebook() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerate() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        let firstAnnotationID = annotations.first!.id
        try! annotationStore.removeAnnotation(annotationID: firstAnnotationID, fromNotebook: notebook.id, source: .Local)
        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(firstAnnotationID)?.status == .Trashed)

        let secondAnnotationID = annotations.last!.id
        try! annotationStore.removeAnnotation(annotationID: secondAnnotationID, fromNotebook: notebook.id, source: .Local)
        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(secondAnnotationID)?.status == .Trashed)
    }

    func testDeleteAnnotationTag() {
        let annotationStore = AnnotationStore()!
        
        let tag = try! annotationStore.addTag(name: "TestTag")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
        ]
        
        for annotation in annotations {
            try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id, tagID: tag.id)
        }
        
        let firstAnnotationID = annotations.first!.id
        try! annotationStore.removeTag(tagID: tag.id, fromAnnotation: firstAnnotationID)
        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(firstAnnotationID)!.status == .Trashed)
        
        let secondAnnotationID = annotations.last!.id
        try! annotationStore.removeTag(tagID: tag.id, fromAnnotation: secondAnnotationID)
        // Verify annotation has been marked as .Trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(secondAnnotationID)!.status == .Trashed)
    }
    
    func testAddHighlights() {
        let annotationStore = AnnotationStore()!
        
        let docID = "12345"
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        ]
        
        XCTAssertEqual(Set(annotations.map({ $0.uniqueID })), Set(annotationStore.annotations(docID: docID).map({ $0.uniqueID })))
        
        let paragraphRanges = [
            ParagraphRange(paragraphAID: "1"),
            ParagraphRange(paragraphAID: "2"),
            ParagraphRange(paragraphAID: "3"),
            ParagraphRange(paragraphAID: "3"),
            ParagraphRange(paragraphAID: "4")
        ]
        
        let highlights = try! annotationStore.addHighlights(docID: docID, docVersion: 1, paragraphRanges: paragraphRanges, colorName: "yellow", style: .Highlight, appSource: "Test", device: "iphone")
        XCTAssertEqual(Set(paragraphRanges.map({ $0.paragraphAID })), Set(highlights.map({ $0.paragraphRange.paragraphAID })))
    }

    func testNotebookUpdateLastModifiedDate() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        try! annotationStore.updateLastModifiedDate(notebookID: notebook.id, source: .Local)
        
        XCTAssertNotEqual(notebook.lastModified, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.lastModified, "Notebook last modified date should have changed")
        XCTAssertEqual(notebook.status.rawValue, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status.rawValue, "Notebook status should not have changed")

        try! annotationStore.updateLastModifiedDate(notebookID: notebook.id, status: .Trashed, source: .Local)
        XCTAssertNotEqual(notebook.lastModified, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.lastModified, "Notebook last modified date should have changed")
        XCTAssertEqual(AnnotationStatus.Trashed.rawValue, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status.rawValue, "Notebook status should have been changed to .Trashed")
    }
    
    func testTrashEmptyNotebookWithID() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerate() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        try! annotationStore.trashNotebookWithID(notebook.id)
        XCTAssertTrue(annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status == .Trashed)
        XCTAssertEqual(0, annotationStore.annotationsWithNotebookID(notebook.id).count)
    }

    func testTrashNotebookWithID() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        try! annotationStore.trashNotebookWithID(notebook.id)
        XCTAssertTrue(annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status == .Trashed)
    }

    
    func testDeleteNotebookWithID() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook", source: .Local)
        try! annotationStore.deleteNotebookWithID(notebook.id, source: .Local)
        
        XCTAssertNil(annotationStore.notebookWithUniqueID(notebook.uniqueID))
    }
    
    func testDeleteTagWithID() {
        let annotationStore = AnnotationStore()!
        
        let tag = try! annotationStore.addTag(name: "TestTag", source: .Local)
        try! annotationStore.deleteTagWithID(tag.id, source: .Local)
        
        XCTAssertNil(annotationStore.tagWithName(tag.name))
        XCTAssertNil(annotationStore.tagWithID(tag.id))
    }
    
    func testTrashAnnotation() {
        let annotationStore = AnnotationStore()!
        
        let paragraphRanges = [
            ParagraphRange(paragraphAID: "1"),
            ParagraphRange(paragraphAID: "2"),
            ParagraphRange(paragraphAID: "3")
        ]
        
        let highlights = try! annotationStore.addHighlights(docID: "13859831", docVersion: 1, paragraphRanges: paragraphRanges, colorName: "yellow", style: .Highlight, appSource: "Test", device: "iphone")
        
        let annotation = annotationStore.annotationWithID(highlights.first!.annotationID)!
        
        let note = try! annotationStore.addNote(title: "TestTitle", content: "TestContent", annotationID: annotation.id)
        let link = try! annotationStore.addLink(name: "TestLink", toDocID: "2", toDocVersion: 1, toParagraphAIDs: ["4"], annotationID: annotation.id)
        try! annotationStore.addTag(name: "TestTag", annotationID: annotation.id)
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: 1)
        
        try! annotationStore.trashAnnotationWithID(annotation.id)
     
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)!.status == .Trashed)
        XCTAssertNil(annotationStore.linkWithID(link.id))
        XCTAssertNil(annotationStore.noteWithID(note.id))
        XCTAssertTrue(annotationStore.highlightsWithAnnotationID(annotation.id).isEmpty)
        XCTAssertTrue(annotationStore.tagsWithAnnotationID(annotation.id).isEmpty)
        XCTAssertTrue(annotationStore.notebooksWithAnnotationID(annotation.id).isEmpty)
        
        let bookmark = try! annotationStore.addBookmark(name: "TestBookmark", paragraphAID: "1", displayOrder: 1, docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone")
        let bookmarkAnnotation = annotationStore.annotationWithID(bookmark.annotationID)!
     
        try! annotationStore.trashAnnotationWithID(bookmarkAnnotation.id)
        XCTAssertTrue(annotationStore.annotationWithID(bookmarkAnnotation.id)!.status == .Trashed)
        XCTAssertNil(annotationStore.bookmarkWithID(bookmark.id))
    }
    
    func testDuplicateAnnotation() {
        let annotationStore = AnnotationStore()!
        
        let paragraphRanges = [
            ParagraphRange(paragraphAID: "1"),
            ParagraphRange(paragraphAID: "2"),
            ParagraphRange(paragraphAID: "3")
        ]
        
        let highlights = try! annotationStore.addHighlights(docID: "13859831", docVersion: 1, paragraphRanges: paragraphRanges, colorName: "yellow", style: .Highlight, appSource: "Test", device: "iphone")
        let annotation = annotationStore.annotationWithID(highlights.first!.annotationID)!
        let note = try! annotationStore.addNote(title: "TestTitle", content: "TestContent", annotationID: annotation.id)
        let link = try! annotationStore.addLink(name: "TestLink", toDocID: "2", toDocVersion: 1, toParagraphAIDs: ["4"], annotationID: annotation.id)
        let tag = try! annotationStore.addTag(name: "TestTag", annotationID: annotation.id)

        let duplicatedAnnotation = try! annotationStore.duplicateAnnotation(annotation, appSource: "Test", device: "iphone")
        XCTAssertNotEqual(annotation.id, duplicatedAnnotation.id)
        XCTAssertEqual(annotation.docID, duplicatedAnnotation.docID)
        XCTAssertEqual(annotation.docVersion, duplicatedAnnotation.docVersion)

        let duplicatedHighlights = annotationStore.highlightsWithAnnotationID(duplicatedAnnotation.id)
        XCTAssertTrue(duplicatedHighlights.count == highlights.count)
        
        for duplicatedHighlight in duplicatedHighlights {
            let highlight = highlights.filter({ $0.paragraphRange == duplicatedHighlight.paragraphRange }).first!
            XCTAssertNotEqual(highlight.id, duplicatedHighlight.id)
            XCTAssertEqual(highlight.paragraphRange, duplicatedHighlight.paragraphRange)
            XCTAssertEqual(highlight.colorName, duplicatedHighlight.colorName)
            XCTAssertEqual(highlight.style, duplicatedHighlight.style)
        }
        
        let duplicatedNote = annotationStore.noteWithAnnotationID(duplicatedAnnotation.id)!
        XCTAssertNotEqual(note.id, duplicatedNote.id)
        XCTAssertEqual(note.title, duplicatedNote.title)
        XCTAssertEqual(note.content, duplicatedNote.content)
        
        let duplicatedLink = annotationStore.linksWithAnnotationID(duplicatedAnnotation.id).first!
        XCTAssertNotEqual(link.id, duplicatedLink.id)
        XCTAssertEqual(link.name, duplicatedLink.name)
        XCTAssertEqual(link.docID, duplicatedLink.docID)
        XCTAssertEqual(link.docVersion, duplicatedLink.docVersion)
        XCTAssertEqual(link.paragraphAIDs, duplicatedLink.paragraphAIDs)
        
        XCTAssertEqual([tag], annotationStore.tagsWithAnnotationID(duplicatedAnnotation.id))
    }
    
    func testNumberOfAnnotations() {
        let annotationStore = AnnotationStore()!
        
        // One second ago, just to be safe
        let before = NSDate(timeIntervalSinceNow: -1)
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .Local)
        ]
        
        if var trashed = annotations.first {
            // Make sure it includes trashed annotations
            trashed.status = .Trashed
            try! annotationStore.updateAnnotation(trashed, source: .Local)
        }
        
        XCTAssertEqual(annotationStore.numberOfUnsyncedAnnotations(), annotations.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedAnnotations(lastModifiedAfter: before), annotations.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedAnnotations(lastModifiedAfter: NSDate()), 0)
    }
    
    func testNumberOfNotebooks() {
        let annotationStore = AnnotationStore()!
        
        // One second ago, just to be safe
        let before = NSDate(timeIntervalSinceNow: -1)
        
        let notebooks = [
            try! annotationStore.addNotebook(name: "Notebook1"),
            try! annotationStore.addNotebook(name: "Notebook2"),
            try! annotationStore.addNotebook(name: "Notebook3")
        ]
        
        if var trashed = notebooks.first {
            // Make sure it includes trashed notebooks
            trashed.status = .Trashed
            try! annotationStore.updateNotebook(trashed)
        }
        
        XCTAssertEqual(annotationStore.numberOfUnsyncedNotebooks(), notebooks.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedNotebooks(lastModifiedAfter: before), notebooks.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedNotebooks(lastModifiedAfter: NSDate()), 0)
    }
    
    func testRemovingNoteFromAnnotationWithClearHighlights() {
        let annotationStore = AnnotationStore()!
        
        let note = try! annotationStore.addNote("Title", content: "content", docID: "13859831", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "12345")], colorName: "clear", style: .Clear, appSource: "Test", device: "iphone")
        
        let annotation = annotationStore.annotationWithID(note.annotationID)!
        
        XCTAssertEqual(note, annotationStore.noteWithAnnotationID(note.annotationID)!, "Loaded note should match what was inserted")
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotation.status == .Active)
        
        try! annotationStore.trashNoteWithID(note.id)
        
        // Verify note has been deleted
        XCTAssertNil(annotationStore.noteWithID(note.id))
        
        // Verify no annotations are associated with note
        XCTAssertNil(annotationStore.annotationWithNoteID(note.id))
        
        // Verify annotation is trashed
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .Trashed)
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
