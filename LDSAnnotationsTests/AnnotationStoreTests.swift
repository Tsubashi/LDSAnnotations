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
        let expected = try! annotationStore.addNote(title: nil, content: "", annotationID: 1, source: .local)
        let actual = annotationStore.noteWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testAddBookmark() {
        let annotationStore = AnnotationStore()!
        try! annotationStore.addBookmark(name: "Test", paragraphAID: nil, displayOrder: 5, annotationID: 1, offset: 0, source: .local)
        let expected = Bookmark(id: 1, name: "Test", paragraphAID: nil, displayOrder: 5, annotationID: 1, offset: 0)
        let actual = annotationStore.bookmarkWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testAddLink() {
        let annotationStore = AnnotationStore()!
        try! annotationStore.addLink(name: "Link", docID: "DocID", docVersion: 1, paragraphAIDs: ["ParagraphID"], annotationID: 1, source: .local)
        let expected = Link(id: 1, name: "Link", docID: "DocID", docVersion: 1, paragraphAIDs: ["ParagraphID"], annotationID: 1)
        let actual = annotationStore.linkWithID(1)
        XCTAssertEqual(actual, expected)
    }
    
    func testTagsOrderedByName() {
        let annotationStore = AnnotationStore(path: "")!
        
        var tags = [Tag]()
        var annotations = [Annotation]()
        var date = Date()
        
        for i in 0..<alphabet.count {
            for j in i..<alphabet.count {
                let tag = try! annotationStore.addTag(name: alphabet[i], source: .local)
                tags.append(tag)
                
                let annotation = try! annotationStore.addAnnotation(uniqueID: "\(i)_\(j)", docID: alphabet[i], docVersion: 1, lastModified: date, appSource: "Test", device: "iphone", source: .local)
                annotations.append(annotation)
                
                try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id, tagID: tag.id, source: .local)
            }
            
            date = date.addingTimeInterval(1)
        }
        
        let byName = annotationStore.tags(orderBy: .name)
        XCTAssertEqual(byName.map { $0.name }, alphabet)
        
        let byNameWithIDs = annotationStore.tags(ids: [5, 10, 15], orderBy: .name)
        XCTAssertEqual(byNameWithIDs.map { $0.name }, ["e", "j", "o"])

        let actualMostRecent = annotationStore.tags(orderBy: .mostRecent).map { $0.name }
        XCTAssert(actualMostRecent == Array(alphabet.reversed()), "Most recent tags ordered incorrectly")

        let actualMostRecentWithIDs = annotationStore.tags(ids: [5, 10, 15], orderBy: .mostRecent).map { $0.name }
        XCTAssert(actualMostRecentWithIDs == ["o", "j", "e"], "Most recent tags with ids ordered incorrectly")

        let byNumberOfAnnotations = annotationStore.tags(orderBy: .numberOfAnnotations).map { $0.name }
        XCTAssertEqual(byNumberOfAnnotations, alphabet, "Tags ordered by number of annotations is ordered incorrectly")
        
        let byNumberOfAnnotationsWithIDs = annotationStore.tags(ids: [5, 10, 15], orderBy: .numberOfAnnotations).map { $0.name }
        XCTAssertEqual(byNumberOfAnnotationsWithIDs, ["e", "j", "o"], "Tags ordered by number of annotations is ordered incorrectly")
    }
    
    func testNotebooksOrderBy() {
        let annotationStore = AnnotationStore()!
        
        var date = Date()
        var notebooks = [Notebook]()
        for i in 0..<alphabet.count {
            notebooks.append(try! annotationStore.addNotebook(uniqueID: "\(i)", name: alphabet[i], description: nil, status: .active, lastModified: date, source: .local))
            date = date.addingTimeInterval(1)
        }
        
        var annotations = [Annotation]()
        
        for i in 0..<alphabet.count {
            annotations.append(try! annotationStore.addAnnotation(uniqueID: "\(i)", docID: alphabet[i], docVersion: 1, status: .active, created: nil, lastModified: Date(), appSource: "Test", device: "iphone", source: .local))
        }
        
        for i in 1...alphabet.count {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 5, displayOrder: i, source: .local)
        }
        
        for i in 1...Int(alphabet.count / 2) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 10, displayOrder: i, source: .local)
        }
        
        for i in 1...Int(alphabet.count / 3) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 15, displayOrder: i, source: .local)
        }
        
        for i in 1...Int(alphabet.count / 5) {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: Int64(i), notebookID: 20, displayOrder: i, source: .local)
        }
        
        let byName = annotationStore.notebooks(orderBy: .name)
        XCTAssertEqual(byName.map { $0.name }, alphabet)
        
        let byNameWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .name)
        XCTAssertEqual(byNameWithIDs.map { $0.name }, ["e", "j", "o"])
        
        let actualMostRecent = annotationStore.notebooks(orderBy: .mostRecent).map { $0.name }
        XCTAssertEqual(actualMostRecent, ["z", "y", "x", "w", "v", "u", "s", "r", "q", "p", "n", "m", "l", "k", "i", "h", "g", "f", "d", "c", "b", "t", "o", "j", "e", "a"], "Most recent notebooks ordered incorrectly")
        
        let actualMostRecentWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .mostRecent).map { $0.name }
        XCTAssert(actualMostRecentWithIDs == ["o", "j", "e"], "Most recent notebooks with ids ordered incorrectly")
        
        let byNumberOfAnnotations = annotationStore.notebooks(orderBy: .numberOfAnnotations).map { $0.name }
        let expected = ["e", "j", "o", "t", "a", "b", "c", "d", "f", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "u", "v", "w", "x", "y", "z"]
        XCTAssertEqual(byNumberOfAnnotations, expected, "Notebooks ordered by number of annotations is ordered incorrectly")
        
        let byNumberOfAnnotationsWithIDs = annotationStore.notebooks(ids: [5, 10, 15], orderBy: .numberOfAnnotations).map { $0.name }
        XCTAssertEqual(byNumberOfAnnotationsWithIDs, ["e", "j", "o"], "Notebooks ordered by number of annotations is ordered incorrectly")
    }
    
    func testAnnotationWithID() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        
        XCTAssertEqual(annotation.uniqueID, annotationStore.annotationWithID(annotation.id)!.uniqueID, "Annotations should be the same")
    }
    
    func testCreateAndTrashTags() {
        let annotationStore = AnnotationStore()!

        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        
        let tags = ["sally", "sells", "seashells", "by", "the", "seashore"].map { try! annotationStore.addTag(name: $0) }
        
        for tag in tags {
            try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id, tagID: tag.id)
        }
        
        XCTAssertEqual(tags.sorted(by: { $0.name < $1.name }).map({ $0.id }), annotationStore.tagsWithAnnotationID(annotation.id).map({ $0.id }), "Loaded tags should equal inserted tags")
        
        // Verify tags are trashed correctly
        for tag in tags {
            // Verify annotation hasn't been marked as trashed yet because its not empty
            XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .active)
            
            try! annotationStore.trashTagWithID(tag.id, source: .local)

            // Verify tag has been deleted
            XCTAssertNil(annotationStore.tagWithName(tag.name))
            
            // Verify no annotations are associated with tag
            XCTAssertTrue(annotationStore.annotationsWithTagID(tag.id).isEmpty)
        }

        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .trashed)
    }
    
    func testCreateAndTrashLinks() {
        let annotationStore = AnnotationStore()!
        
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        
        let links = [
            try! annotationStore.addLink(name: "Link1", docID: "13859831", docVersion: 1, paragraphAIDs: ["1"], annotationID: annotation.id, source: .local),
            try! annotationStore.addLink(name: "Link2", docID: "20056230", docVersion: 1, paragraphAIDs: ["1", "2"], annotationID: annotation.id, source: .local),
            try! annotationStore.addLink(name: "Link3", docID: "20056129", docVersion: 1, paragraphAIDs: ["1", "2", "3"], annotationID: annotation.id, source: .local),
            try! annotationStore.addLink(name: "Link4", docID: "20056278", docVersion: 1, paragraphAIDs: ["1", "2", "3", "4"], annotationID: annotation.id, source: .local)
        ]

        XCTAssertEqual(links.map({ $0.id }), annotationStore.linksWithAnnotationID(annotation.id).map({ $0.id }), "Loaded links should match what was inserted")

        // Verify links are trashed correctly
        for link in links {
            // Verify annotation hasn't been marked as trashed yet because its not empty
            XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .active)
            
            try! annotationStore.trashLinkWithID(link.id)
            
            // Verify tag has been deleted
            XCTAssertNil(annotationStore.linkWithID(link.id))
            
            // Verify no annotations are associated with tag
            XCTAssertNil(annotationStore.annotationWithLinkID(link.id))
        }
        
        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .trashed)
    }
    
    func testCreateAndTrashBookmark() {
        let annotationStore = AnnotationStore()!
        
        let bookmark = try! annotationStore.addBookmark(name: "Bookmark1", paragraphAID: nil, displayOrder: 1, docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        
        let annotation = annotationStore.annotationWithID(bookmark.annotationID)!
        
        XCTAssertEqual(bookmark.id, annotationStore.bookmarkWithAnnotationID(annotation.id)!.id, "Loaded bookmark should match what was inserted")
        
        // Verify bookmark is trashed correctly
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .active)
        
        try! annotationStore.trashBookmarkWithID(bookmark.id, source: .local)
        
        // Verify tag has been deleted
        XCTAssertNil(annotationStore.bookmarkWithID(bookmark.id))
        
        // Verify no annotations are associated with tag
        XCTAssertNil(annotationStore.annotationWithBookmarkID(bookmark.id))
        
        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .trashed)
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
    
    func testBookmarksHideChapterBookmarks() {
        let annotationStore = AnnotationStore()!
        
        let paragraphBookmark = try! annotationStore.addBookmark(name: "Bookmark1", paragraphAID: "12345", displayOrder: 1, docID: "20056057",  docVersion: 1, appSource: "Test", device: "iphone")
        let chapterBookmark = try! annotationStore.addBookmark(name: "Bookmark2", paragraphAID: nil, displayOrder: 1, docID: "20056057",  docVersion: 1, appSource: "Test", device: "iphone")
        
        XCTAssertTrue(Set(annotationStore.bookmarks().map({ $0.id })) == Set([paragraphBookmark, chapterBookmark].map({ $0.id })))
        XCTAssertTrue(Set(annotationStore.bookmarks(requireParagraphAID: true).map({ $0.id })) == Set([paragraphBookmark].map({ $0.id })))
    }
    
    func testCreateAndTrashNote() {
        let annotationStore = AnnotationStore()!
        
        let note = try! annotationStore.addNote("Title", content: "content", docID: "13859831", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "12345")], colorName: "yellow", style: .Underline, appSource: "Test", device: "iphone")
        
        let annotation = annotationStore.annotationWithID(note.annotationID)!
        
        XCTAssertEqual(note, annotationStore.noteWithAnnotationID(note.annotationID)!, "Loaded note should match what was inserted")
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotation.status == .active)
        
        try! annotationStore.trashNoteWithID(note.id)
        
        // Verify note has been deleted
        XCTAssertNil(annotationStore.noteWithID(note.id))
        
        // Verify no annotations are associated with note
        XCTAssertNil(annotationStore.annotationWithNoteID(note.id))
        
        // Verify annotation still has highlights and is still active
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .active)
        XCTAssertTrue(!annotationStore.highlightsWithAnnotationID(annotation.id).isEmpty)
    }
    
    func testTagsContainingString() {
        let annotationStore = AnnotationStore()!
        
        ["sally", "sells", "seashells", "by", "the", "seashore"].forEach { try! annotationStore.addTag(name: $0) }
        
        XCTAssertEqual(annotationStore.tagsContainingString("sea").map({ $0.name }), ["seashells", "seashore"].sorted(), "Tags containing string missing tags")
    }
    
    func testInsertingDuplicateTags() {
        let annotationStore = AnnotationStore()!
        
        let names = ["sally", "sells", "seashells", "by", "the", "seashore"].sorted()
        for name in names {
            try! annotationStore.addTag(name: name)
            try! annotationStore.addTag(name: name.capitalized(with: nil))
            try! annotationStore.addTag(name: name.uppercased())
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
        
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        let links = [
            try! annotationStore.addLink(name: "Link1", docID: "13859831", docVersion: 1, paragraphAIDs: ["1"], annotationID: annotation.id, source: .local),
            try! annotationStore.addLink(name: "Link2", docID: "20056230", docVersion: 1, paragraphAIDs: ["1", "2"], annotationID: annotation.id, source: .local),
        ]
        
        for link in links {
            // Verify annotationloads correctly
            XCTAssertEqual(annotation.id, annotationStore.annotationWithLinkID(link.id)!.id, "Annotation did not load correctly from database")
        }
        
        let annotation2 = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        let links2 = [
            try! annotationStore.addLink(name: "Link3", docID: "20056129", docVersion: 1, paragraphAIDs: ["1", "2", "3"], annotationID: annotation2.id, source: .local),
            try! annotationStore.addLink(name: "Link4", docID: "20056278", docVersion: 1, paragraphAIDs: ["1", "2", "3", "4"], annotationID: annotation2.id, source: .local)
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
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .local)
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
            try! annotationStore.addAnnotation(docID: docID1, docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: docID2, docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        ]
        try! annotationStore.addAnnotation(docID: docID3, docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        
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
            let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
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
            annotations.append(try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local))
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
            annotations.append(try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local))
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
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerated() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        XCTAssertEqual(annotationStore.numberOfAnnotations(notebookID: notebook.id), annotations.count)
    }
    
    func testReorderAnnotationIDs() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerated() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        let reversedAnnotationIDs = Array(annotations.map { $0.id }.reversed())
        try! annotationStore.reorderAnnotationIDs(reversedAnnotationIDs, notebookID: notebook.id)

        XCTAssertEqual(reversedAnnotationIDs, annotationStore.annotationIDsForNotebookWithID(notebook.id))
    }
    
    func testDeleteAnnotationNotebook() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerated() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        let firstAnnotationID = annotations.first!.id
        try! annotationStore.removeAnnotation(annotationID: firstAnnotationID, fromNotebook: notebook.id, source: .local)
        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(firstAnnotationID)?.status == .trashed)

        let secondAnnotationID = annotations.last!.id
        try! annotationStore.removeAnnotation(annotationID: secondAnnotationID, fromNotebook: notebook.id, source: .local)
        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(secondAnnotationID)?.status == .trashed)
    }

    func testDeleteAnnotationTag() {
        let annotationStore = AnnotationStore()!
        
        let tag = try! annotationStore.addTag(name: "TestTag")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
        ]
        
        for annotation in annotations {
            try! annotationStore.addOrUpdateAnnotationTag(annotationID: annotation.id, tagID: tag.id)
        }
        
        let firstAnnotationID = annotations.first!.id
        try! annotationStore.removeTag(tagID: tag.id, fromAnnotation: firstAnnotationID)
        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(firstAnnotationID)!.status == .trashed)
        
        let secondAnnotationID = annotations.last!.id
        try! annotationStore.removeTag(tagID: tag.id, fromAnnotation: secondAnnotationID)
        // Verify annotation has been marked as .trashed now that its empty
        XCTAssertTrue(annotationStore.annotationWithID(secondAnnotationID)!.status == .trashed)
    }
    
    func testAddHighlights() {
        let annotationStore = AnnotationStore()!
        
        let docID = "12345"
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: docID, docVersion: 1, appSource: "Test", device: "iphone", source: .local)
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
        
        try! annotationStore.updateLastModifiedDate(notebookID: notebook.id, source: .local)
        
        XCTAssertNotEqual(notebook.lastModified, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.lastModified, "Notebook last modified date should have changed")
        XCTAssertEqual(notebook.status.rawValue, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status.rawValue, "Notebook status should not have changed")

        try! annotationStore.updateLastModifiedDate(notebookID: notebook.id, status: .trashed, source: .local)
        XCTAssertNotEqual(notebook.lastModified, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.lastModified, "Notebook last modified date should have changed")
        XCTAssertEqual(AnnotationStatus.trashed.rawValue, annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status.rawValue, "Notebook status should have been changed to .trashed")
    }
    
    func testTrashEmptyNotebookWithID() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
        ]
        
        for (displayOrder, annotation) in annotations.enumerated() {
            try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: displayOrder)
        }
        
        try! annotationStore.trashNotebookWithID(notebook.id)
        XCTAssertTrue(annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status == .trashed)
        XCTAssertEqual(0, annotationStore.annotationsWithNotebookID(notebook.id).count)
    }

    func testTrashNotebookWithID() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook")
        try! annotationStore.trashNotebookWithID(notebook.id)
        XCTAssertTrue(annotationStore.notebookWithUniqueID(notebook.uniqueID)!.status == .trashed)
    }

    
    func testDeleteNotebookWithID() {
        let annotationStore = AnnotationStore()!
        
        let notebook = try! annotationStore.addNotebook(name: "TestNotebook", source: .local)
        try! annotationStore.deleteNotebookWithID(notebook.id, source: .local)
        
        XCTAssertNil(annotationStore.notebookWithUniqueID(notebook.uniqueID))
    }
    
    func testDeleteTagWithID() {
        let annotationStore = AnnotationStore()!
        
        let tag = try! annotationStore.addTag(name: "TestTag", source: .local)
        try! annotationStore.deleteTagWithID(tag.id, source: .local)
        
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
     
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)!.status == .trashed)
        XCTAssertNil(annotationStore.linkWithID(link.id))
        XCTAssertNil(annotationStore.noteWithID(note.id))
        XCTAssertTrue(annotationStore.highlightsWithAnnotationID(annotation.id).isEmpty)
        XCTAssertTrue(annotationStore.tagsWithAnnotationID(annotation.id).isEmpty)
        XCTAssertTrue(annotationStore.notebooksWithAnnotationID(annotation.id).isEmpty)
        
        let bookmark = try! annotationStore.addBookmark(name: "TestBookmark", paragraphAID: "1", displayOrder: 1, docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone")
        let bookmarkAnnotation = annotationStore.annotationWithID(bookmark.annotationID)!
     
        try! annotationStore.trashAnnotationWithID(bookmarkAnnotation.id)
        XCTAssertTrue(annotationStore.annotationWithID(bookmarkAnnotation.id)!.status == .trashed)
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
        let before = Date(timeIntervalSinceNow: -1)
        
        let annotations = [
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local),
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        ]
        
        if var trashed = annotations.first {
            // Make sure it includes trashed annotations
            trashed.status = .trashed
            try! annotationStore.updateAnnotation(trashed, source: .local)
        }
        
        XCTAssertEqual(annotationStore.numberOfUnsyncedAnnotations(), annotations.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedAnnotations(lastModifiedAfter: before), annotations.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedAnnotations(lastModifiedAfter: Date()), 0)
    }
    
    func testNumberOfNotebooks() {
        let annotationStore = AnnotationStore()!
        
        // One second ago, just to be safe
        let before = Date(timeIntervalSinceNow: -1)
        
        let notebooks = [
            try! annotationStore.addNotebook(name: "Notebook1"),
            try! annotationStore.addNotebook(name: "Notebook2"),
            try! annotationStore.addNotebook(name: "Notebook3")
        ]
        
        if var trashed = notebooks.first {
            // Make sure it includes trashed notebooks
            trashed.status = .trashed
            try! annotationStore.updateNotebook(trashed)
        }
        
        XCTAssertEqual(annotationStore.numberOfUnsyncedNotebooks(), notebooks.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedNotebooks(lastModifiedAfter: before), notebooks.count)
        XCTAssertEqual(annotationStore.numberOfUnsyncedNotebooks(lastModifiedAfter: Date()), 0)
    }
    
    func testRemovingNoteFromAnnotationWithClearHighlights() {
        let annotationStore = AnnotationStore()!
        
        let note = try! annotationStore.addNote("Title", content: "content", docID: "13859831", docVersion: 1, paragraphRanges: [ParagraphRange(paragraphAID: "12345")], colorName: "clear", style: .Clear, appSource: "Test", device: "iphone")
        
        let annotation = annotationStore.annotationWithID(note.annotationID)!
        
        XCTAssertEqual(note, annotationStore.noteWithAnnotationID(note.annotationID)!, "Loaded note should match what was inserted")
        
        // Verify annotation hasn't been marked as trashed yet because its not empty
        XCTAssertTrue(annotation.status == .active)
        
        try! annotationStore.trashNoteWithID(note.id)
        
        // Verify note has been deleted
        XCTAssertNil(annotationStore.noteWithID(note.id))
        
        // Verify no annotations are associated with note
        XCTAssertNil(annotationStore.annotationWithNoteID(note.id))
        
        // Verify annotation is trashed
        XCTAssertTrue(annotationStore.annotationWithID(annotation.id)?.status == .trashed)
    }
    
    func testTagCaseSensitivity() {
        let annotationStore = AnnotationStore()!
        
        let tagNames = ["Misterios de Dios", "Ananías", "Dignidad", "Arrepentimiento", "Maestros (Docentes)", "Activación", "Apologética", "Activación Activación", "Matrimonio celestial", "Matrimonio celestial Matrimonio celestial", "Autoridad", "Tecnología", "Conferencias Generales", "Conferencias Generales Conferencias Generales", "Bautismo", "Paternidad", "Mujeres", "Feminismo", "Familia", "Feminismo Feminismo", "Bienestar", "Diezmo", "Estadísticas", "Conferencias Generales Conferencias Generales", "Simbolismo", "Cronología", "María; madre del Señor", "Convenio de la posteridad", "Escogidos", "Quiasmo", "Revelación", "Humildad", "Oración", "Gratitud", "Alimentos", "Adoración", "Arrepentimiento Arrepentimiento", "Bautismo Bautismo", "Moisés", "Lehi", "Convenio de la tierra", "América", "Convenios (en general)", "Baile", "Arrepentimiento Arrepentimiento", "Escrituras; estudio de", "Perdón de los pecados", "Profecías", "Profetas", "Contención", "Discriminación", "Convenio de Abraham", "Escribir", "Felicidad", "José; el soñador", "Contención Contención", "Satanás", "Iglesia", "Misterios de Dios Misterios de Dios", "Pena de muerte", "Ordenación", "Sumo Sacerdocio", "Albedrío", "Rascismo", "Arrepentimiento Arrepentimiento", "Paciencia", "Deseo", "Apostasía general", "Materialismo", "Cristianos", "Arrepentimiento Arrepentimiento", "Derecha", "Disciplina", "Satanás Satanás", "Libro de Mormón", "Libro de Mormón Libro de Mormón", "Nefi", "Disciplina Disciplina", "Arrepentimiento Arrepentimiento", "Muerte", "Día de reposo", "Primera resurrección", "Amor al prójimo", "Comunicación", "Contención Contención", "Fraternidad", "Unidad", "Llamamientos", "Conferencias Generales Conferencias Generales", "Juicio final", "Conocimiento", "Exaltación", "Progenie espiritual", "Dios; naturaleza corpórea de", "Educación académica", "Continuación de vidas", "Abraham", "Contención Contención", "Funerales", "Dones espirituales", "Arrepentimiento Arrepentimiento", "Adulterio", "Humildad Humildad", "Alabanza", "Oración Oración", "Aceite", "Autoridad Autoridad", "Elías (el Profeta)", "Enseñanza", "Combinaciones secretas", "Gentiles", "Guerra", "Gentiles Gentiles", "Milenio", "Biblia", "Apostasía general Apostasía general", "Recogimiento", "Jesucristo; Hijo del Hombre", "Gratitud Gratitud", "Ley de los testigos", "Finanzas", "Trabajo", "Conferencias Generales Conferencias Generales", "Hijos de Perdición", "Trabajo Trabajo", "Angeles", "Milenio Milenio", "Dignidad Dignidad", "Espíritus", "Conocimiento Conocimiento", "Educación académica Educación académica", "Enseñanza Enseñanza", "Gloria", "Condenación", "Espíritu Santo", "Poder sellador", "Oración Oración", "Obra vicaria", "Matrimonio celestial Matrimonio celestial", "Día de reposo Día de reposo", "Amor al prójimo Amor al prójimo", "Simbolismo del templo", "Jesucristo; es Jehová", "Amor al prójimo Amor al prójimo", "Domingo", "Día de reposo Día de reposo", "Caín", "Vida eterna", "Amor al prójimo Amor al prójimo", "Dios", "Oposición", "Ejemplo", "Dignidad Dignidad", "Celibato", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Juicio final Juicio final", "Adopción (de los gentiles)", "Recogimiento Recogimiento", "Predicación del evangelio", "Carácter", "Juicio final Juicio final", "Falsedad", "Almacenamiento", "Bienestar Bienestar", "Juan el Bautista", "Bienestar Bienestar", "David", "Jesucristo; es Jehová Jesucristo; es Jehová", "Persecución", "Abraham Abraham", "Templos", "Comunión", "Enseñanza Enseñanza", "Crítica", "Celebraciones", "Sumo Sacerdocio Sumo Sacerdocio", "Arrepentimiento Arrepentimiento", "Confesión", "Liderazgo", "Obispos", "Sumo Sacerdocio Sumo Sacerdocio", "Convenio y juramento del sacerdocio", "Juramentos", "Obediencia", "Fe", "Trinidad", "Gloria Gloria", "Jesucristo es un Dios", "Jesucristo; Creador", "Gloria Gloria", "Dios; puede ser visto", "Jesucristo; Rey de los judíos", "Dios el Padre", "Mujeres Mujeres", "Jesucristo; familia terrenal de", "Jerusalén", "Mujeres Mujeres", "Planeación", "Apercepción", "Parábola del rico y Lázaro", "Pedro", "Pedro Pedro", "Pedro Pedro", "Santa Cena", "Secreto mesiánico", "Santa Cena Santa Cena", "Parábola de la semilla que crece", "Día de reposo Día de reposo", "Testimonio", "Baile Baile", "Secreto mesiánico Secreto mesiánico", "Comunicación Comunicación", "Apercepción Apercepción", "Parábola del trigo y la cizaña", "Hades", "Llaves", "Consejos de la Iglesia", "Adopción (de infantes)", "Ley de los testigos Ley de los testigos", "Consagración", "Jesucristo es un Dios Jesucristo es un Dios", "Parábola de la fiesta de bodas del hijo del rey", "Parábolas", "Parábola de los talentos", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Día de reposo Día de reposo", "Bautismo Bautismo", "Autoridad Autoridad", "Justicia", "Dios el Padre Dios el Padre", "Convenio de la tierra Convenio de la tierra", "Hijos de Dios (por el nuevo nacimiento)", "Ejemplo Ejemplo", "Consuelo", "Misericordia", "Satanás Satanás", "Consejo", "Condenación Condenación", "Obispos Obispos", "Dios; puede ser visto Dios; puede ser visto", "Liderazgo Liderazgo", "Pastores", "Preparación", "Celibato Celibato", "Adán", "Gárments", "Día de reposo Día de reposo", "Pena de muerte Pena de muerte", "Día de reposo Día de reposo", "Diezmo Diezmo", "Arbol de la ciencia", "Altar", "Adopción (de infantes) Adopción (de infantes)", "Guerra Guerra", "Cam", "Idolatría", "Jesucristo; es Jehová Jesucristo; es Jehová", "Visiones", "Bienestar Bienestar", "Apostasía general Apostasía general", "Dios el Padre Dios el Padre", "Unción (consagración)", "Homosexualidad", "Incesto", "Juan el Bautista Juan el Bautista", "Caída", "Setentas", "Honor", "Ira", "Adopción (de infantes) Adopción (de infantes)", "Apologética Apologética", "Integridad", "Liderazgo Liderazgo", "Dignidad Dignidad", "Integridad Integridad", "Quiasmo Quiasmo", "Concilio de los Cielos", "Dios; puede ser visto Dios; puede ser visto", "Adán Adán", "Fe Fe", "Doctrina y Convenios", "Dios; atributos de", "Reino de Dios", "Juan el Bautista Juan el Bautista", "Bienestar Bienestar", "Gratitud Gratitud", "Misión de tiempo completo", "Noviazgo", "Celibato Celibato", "Arrepentimiento Arrepentimiento", "Enseñanza Enseñanza", "Felicidad Felicidad", "Santa Cena Santa Cena", "Pascua", "Enseñanza Enseñanza", "Apologética Apologética", "Ética", "Dudas", "Enseñanza Enseñanza", "Arrepentimiento Arrepentimiento", "Madres", "Perdón de los pecados Perdón de los pecados", "Enseñanza Enseñanza", "Enseñanza Enseñanza", "Don de sueños", "Niños pequeños", "Apostasía general Apostasía general", "Materialismo Materialismo", "Abominable", "Bautismo Bautismo", "Llaves Llaves", "Bendición patriarcal", "Contexto", "Cronología Cronología", "Adán-ondi-Ahmán", "Maestros (Docentes) Maestros (Docentes)", "Enseñanza Enseñanza", "Convenios", "Predicación del evangelio Predicación del evangelio", "Arrepentimiento Arrepentimiento", "Activación Activación", "Autodeterminación", "Gratitud Gratitud", "Oración Oración", "Estadísticas Estadísticas", "Oposición Oposición", "Perdón al prójimo", "Oposición Oposición", "Juicio de Dios", "Liahona", "Lehi Lehi", "Baile Baile", "Apologética Apologética", "Zenós", "Cronología Cronología", "Babilonia", "Convenio de Abraham Convenio de Abraham", "Convenio de Abraham Convenio de Abraham", "Planchas de bronce", "Juramentos Juramentos", "Ley de Moisés", "Nefi Nefi", "Visiones Visiones", "Convenio de la tierra Convenio de la tierra", "Suercherías sacerdotales", "Convenio de Abraham Convenio de Abraham", "Enseñanza Enseñanza", "Zenoc", "Apóstoles", "Autoridad Autoridad", "Ordenación Ordenación", "Santa Cena Santa Cena", "Condenación Condenación", "Jerusalén Jerusalén", "Cristianos Cristianos", "Arrepentimiento Arrepentimiento", "Dignidad Dignidad", "Poder sellador Poder sellador", "Satanás Satanás", "Nefi Nefi", "Lamanitas", "Lamanitas Lamanitas", "Disciplina Disciplina", "Bautismo Bautismo", "Ética Ética", "Satanás Satanás", "Escrituras; estudio de Escrituras; estudio de", "Día de reposo Día de reposo", "Iglesia; organización de;", "Liderazgo Liderazgo", "Llamamientos Llamamientos", "Ordenación Ordenación", "Expiación", "Poder sellador Poder sellador", "Comunión Comunión", "Adán-ondi-Ahmán Adán-ondi-Ahmán", "Setentas Setentas", "Atención", "Juicio final Juicio final", "Espíritus Espíritus", "Dios; puede ser visto Dios; puede ser visto", "Conocimiento Conocimiento", "Educación académica Educación académica", "Enseñanza Enseñanza", "Gloria Gloria", "Inteligencia", "Resurrección", "Espíritu Santo Espíritu Santo", "Angeles Angeles", "Emma Smith", "Funerales Funerales", "Obediencia Obediencia", "Arrepentimiento Arrepentimiento", "Santa Cena Santa Cena", "Arrepentimiento Arrepentimiento", "Elderes", "Dios; existencia de", "Perdón de los pecados Perdón de los pecados", "Adán Adán", "Espíritu Santo Espíritu Santo", "Gentiles Gentiles", "Desastres naturales", "Alimentos Alimentos", "Alimentos Alimentos", "Segunda Venida", "Bienestar Bienestar", "Arrepentimiento Arrepentimiento", "Angeles Angeles", "Jesucristo; Principio y Fin", "Escrituras", "Día de reposo Día de reposo", "Adán Adán", "Jesucristo; Juez", "Conocimiento de Dios", "Confianza ante Dios", "Dios; atributos de Dios; atributos de", "Espíritus Espíritus", "Probación (pruebas)", "David Whitmer", "José Smith", "Templos Templos", "Gárments Gárments", "Albedrío Albedrío", "Convenio de Enoc", "Apariencia", "Convenio de Noé", "Amor al prójimo Amor al prójimo", "Justicia Justicia", "Dios; puede ser visto Dios; puede ser visto", "Arrepentimiento Arrepentimiento", "Anticristo(s)", "Amor al prójimo Amor al prójimo", "Amor al prójimo Amor al prójimo", "Caridad", "Santa Cena Santa Cena", "Matrimonio", "Anticristo(s) Anticristo(s)", "Autoridad Autoridad", "Recogimiento Recogimiento", "Exaltación Exaltación", "Apostasía", "Día de reposo Día de reposo", "Jesucristo; Creador Jesucristo; Creador", "Dios; puede ser visto Dios; puede ser visto", "Dios; puede ser visto Dios; puede ser visto", "Moisés Moisés", "Contención Contención", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Dios; puede ser visto Dios; puede ser visto", "Apóstoles Apóstoles", "Sacerdocio Aarónico", "Vocación y Elección", "Apostasía personal", "Hijos de Perdición Hijos de Perdición", "Pecado imperdonable", "Abraham Abraham", "Bienestar Bienestar", "Arrepentimiento Arrepentimiento", "Jesucristo es un Dios Jesucristo es un Dios", "Misterios de Dios Misterios de Dios", "Escrituras adicionales", "Día de reposo Día de reposo", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Domingo Domingo", "Arrepentimiento Arrepentimiento", "Dios; puede ser visto Dios; puede ser visto", "Jesucristo; Juez Jesucristo; Juez", "Secreto mesiánico Secreto mesiánico", "Satanás Satanás", "Satanás Satanás", "Navidad", "Día de reposo Día de reposo", "Tres testigos", "Arrepentimiento Arrepentimiento", "Quiasmo Quiasmo", "Gentiles Gentiles", "Apercepción Apercepción", "Humildad Humildad", "Planeación Planeación", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Investidura", "Liderazgo Liderazgo", "Humildad Humildad", "Día de reposo Día de reposo", "Celibato Celibato", "Pedro Pedro", "Día de reposo Día de reposo", "Expiación Expiación", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Ropas blancas", "Juan el Amado", "Quiasmo Quiasmo", "Dios; puede ser visto Dios; puede ser visto", "Apercepción Apercepción", "Parábola del tesoro escondido", "Niños pequeños Niños pequeños", "Amistad", "Consagración Consagración", "El joven rico", "Apóstoles Apóstoles", "Ley de castidad", "Parábola de los dos hijos", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Bautismo Bautismo", "Camino", "Obediencia Obediencia", "Autodominio", "Oposición Oposición", "Amistad Amistad", "Asertividad", "Conversión", "Domingo Domingo", "Arbol de la vida", "Adopción (de los gentiles) Adopción (de los gentiles)", "Creación", "Apologética Apologética", "Jeremías", "Idolatría Idolatría", "Alabanza Alabanza", "Ayuno", "Incesto Incesto", "Día de reposo Día de reposo", "Baile Baile", "Dios; puede ser visto Dios; puede ser visto", "Pena de muerte Pena de muerte", "Gog", "Arbol de la ciencia Arbol de la ciencia", "Arbol de la vida Arbol de la vida", "Aborto", "Libros de genealogía", "Altar Altar", "Recogimiento Recogimiento", "Conocimiento Conocimiento", "Educación académica Educación académica", "Enseñanza Enseñanza", "Satanás Satanás", "Maestros (Docentes) Maestros (Docentes)", "Recogimiento Recogimiento", "Esclavitud", "Dios; puede ser visto Dios; puede ser visto", "Segunda Venida Segunda Venida", "Niños pequeños Niños pequeños", "Escrituras; estudio de Escrituras; estudio de", "Dios; puede ser visto Dios; puede ser visto", "Incesto Incesto", "Arrepentimiento Arrepentimiento", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Autoestima", "Dignidad Dignidad", "Creación Creación", "Tiempo", "Alabanza Alabanza", "Olaha Shinehah", "Predicación del evangelio Predicación del evangelio", "Albedrío Albedrío", "Satanás Satanás", "Dios; puede ser visto Dios; puede ser visto", "Dios; puede ser visto Dios; puede ser visto", "Geografía", "Dios; atributos de Dios; atributos de", "Bautismo Bautismo", "Discreción", "Dignidad Dignidad", "Autosuficiencia temporal", "Sanidad", "Apologética Apologética", "Autosuficiencia temporal Autosuficiencia temporal", "Albedrío Albedrío", "Albedrío Albedrío", "Impiedad", "Adopción (de infantes) Adopción (de infantes)", "Dignidad Dignidad", "Dios; atributos de Dios; atributos de", "José Smith José Smith", "Autoridad Autoridad", "Dones espirituales Dones espirituales", "Dones espirituales Dones espirituales", "Gratitud Gratitud", "Humildad Humildad", "Amor al prójimo Amor al prójimo", "Consagración Consagración", "Misión de tiempo completo Misión de tiempo completo", "Obediencia Obediencia", "Obra misional", "Sacrificio", "Familia Familia", "Familia Familia", "Fe Fe", "Arrepentimiento Arrepentimiento", "Apóstoles Apóstoles", "Disciplina Disciplina", "Espíritu Santo; Don del", "Enseñanza Enseñanza", "Enseñanza Enseñanza", "Iglesia Iglesia", "Apologética Apologética", "Clero laico", "Hijos de Dios (por su paternidad preterrenal)", "Adopción (de infantes) Adopción (de infantes)", "Adopción (de infantes) Adopción (de infantes)", "Educación académica Educación académica", "Crucifixión", "Expiación Expiación", "Pascua Pascua", "Sacrificio Sacrificio", "Simbolismo Simbolismo", "Church", "Great and Abominable Church", "Apostasy", "Great and Abominable Church Great and Abominable Church", "Perdón de los pecados Perdón de los pecados", "Preparación Preparación", "Familia Familia", "Vida preterrenal", "Baile Baile", "Consejos de la Iglesia Consejos de la Iglesia", "Aborto Aborto", "Libro de Abraham", "Preguntas (técnica didáctica)", "Apostasía general Apostasía general", "Ordenación Ordenación", "Misterios de Dios Misterios de Dios", "Autoridad Autoridad", "Maestros (Docentes) Maestros (Docentes)", "Manual de la Iglesia", "Templos Templos", "Apartheid", "Aprendizaje", "Bienestar Bienestar", "Conferencias Generales Conferencias Generales", "Anécdotas", "Jesucristo; misión de", "Profetas Profetas", "Escrituras; estudio de Escrituras; estudio de", "Mujeres Mujeres", "Mujeres Mujeres", "Aborto Aborto", "Lehi Lehi", "Liahona Liahona", "Juicio final Juicio final", "Contención Contención", "Juicio final Juicio final", "Lamán", "Alabanza Alabanza", "Convenio de Abraham Convenio de Abraham", "Pena de muerte Pena de muerte", "Consuelo Consuelo", "Almacenamiento Almacenamiento", "Amonestación", "Lamán Lamán", "Rascismo Rascismo", "Juan el Bautista Juan el Bautista", "Enseñanza Enseñanza", "Convenio de la tierra Convenio de la tierra", "Contención Contención", "Juicio final Juicio final", "Jesucristo; Hijo de Dios", "Disciplina Disciplina", "Comunicación Comunicación", "Fidelidad", "Escrituras Escrituras", "Caída Caída", "Dios; atributos de Dios; atributos de", "Muerte espiritual", "Arrepentimiento Arrepentimiento", "Abeja", "Baile Baile", "Arrepentimiento Arrepentimiento", "Jesucristo; la Roca", "Apartamiento", "Condenación Condenación", "Apóstoles Apóstoles", "Juicio final Juicio final", "Satanás Satanás", "Baile Baile", "Bautismo Bautismo", "Bautismo Bautismo", "Corazón", "Autoridad Autoridad", "Contención Contención", "Dios; existencia de Dios; existencia de", "Educación académica Educación académica", "Planchas de bronce Planchas de bronce", "Satanás Satanás", "Satanás Satanás", "Contención Contención", "Almacenamiento Almacenamiento", "Misterios de Dios Misterios de Dios", "Setentas Setentas", "Setentas Setentas", "Adán Adán", "Adán Adán", "Setentas Setentas", "Reino Celestial", "Abraham Abraham", "José Smith José Smith", "Abraham Abraham", "Matrimonio Matrimonio", "Emma Smith Emma Smith", "José Smith José Smith", "Oración Oración", "Exaltación Exaltación", "Testimonio Testimonio", "Preordenación", "Vida preterrenal Vida preterrenal", "Judíos", "Arrepentimiento Arrepentimiento", "Arrepentimiento Arrepentimiento", "Conferencias Generales Conferencias Generales", "Cristianos Cristianos", "Disciplina Disciplina", "Santa Cena Santa Cena", "DE Recogimiento", "Guerra Guerra", "Angeles Angeles", "Enoc", "Salud", "Parábola de la higuera", "Segunda Venida Segunda Venida", "Convenio de Abraham Convenio de Abraham", "Misterios de Dios Misterios de Dios", "Misterios de Dios Misterios de Dios", "Sión", "Gloria Gloria", "Condenación Condenación", "Perdición", "Reino Terrestre", "Sacerdocio Aarónico Sacerdocio Aarónico", "Angeles Angeles", "Gloria Gloria", "Enseñanza Enseñanza", "Templos Templos", "Templos Templos", "Humildad Humildad", "Albedrío Albedrío", "Música", "Dios; puede ser visto Dios; puede ser visto", "Matrimonio celestial Matrimonio celestial", "Santos", "Dios el Padre Dios el Padre", "Astros", "Amor al prójimo Amor al prójimo", "Espíritu Santo; Don del Espíritu Santo; Don del", "Hijos de Dios (por el nuevo nacimiento) Hijos de Dios (por el nuevo nacimiento)", "Aceite Aceite", "Confianza ante Dios Confianza ante Dios", "Conciencia", "Aceite Aceite", "Obras", "Preguntas (técnica didáctica) Preguntas (técnica didáctica)", "Apologética Apologética", "Dios el Padre Dios el Padre", "Preguntas (técnica didáctica) Preguntas (técnica didáctica)", "Hijos de Dios (por su paternidad preterrenal) Hijos de Dios (por su paternidad preterrenal)", "Arcángel", "Santa Cena Santa Cena", "Misterios de Dios Misterios de Dios", "Alimentos Alimentos", "Recogimiento Recogimiento", "Apóstoles Apóstoles", "Apóstoles Apóstoles", "Expiación Expiación", "Santos Santos", "Resurrección Resurrección", "Patriarca (primeros Padres)", "Familia Familia", "Aprendizaje Aprendizaje", "Enseñanza Enseñanza", "Obra misional Obra misional", "Albedrío Albedrío", "Fe Fe", "Justificación", "Fe Fe", "Fe Fe", "Autoridad Autoridad", "Negligencia", "Obediencia Obediencia", "Coronas", "Fe Fe", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Profetas Profetas", "Amor a Dios", "Escrituras adicionales Escrituras adicionales", "Juan el Bautista Juan el Bautista", "Juicio final Juicio final", "Resurrección Resurrección", "Codicia", "Arrepentimiento Arrepentimiento", "Día de reposo Día de reposo", "Divorcio", "Pedro Pedro", "Perdón al prójimo Perdón al prójimo", "Fe Fe", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Pedro Pedro", "Autoridad Autoridad", "Día de reposo Día de reposo", "Misión de tiempo completo Misión de tiempo completo", "Fariseos", "Discreción Discreción", "Crítica Crítica", "Parábola de la levadura", "Parábola del grano de mostaza", "Secreto mesiánico Secreto mesiánico", "Tropiezos", "Abuso", "Bienestar Bienestar", "Parábola de las ovejas y los cabritos", "Domingo Domingo", "Santa Cena Santa Cena", "Perdón al prójimo Perdón al prójimo", "Consagración Consagración", "Condenación Condenación", "Obediencia Obediencia", "Fe Fe", "Ley de Cristo", "Amor al prójimo Amor al prójimo", "Dios el Padre Dios el Padre", "Adulterio Adulterio", "Estrella (símbolica)", "Libro de la Vida", "Jesucristo; Juez Jesucristo; Juez", "Nombre nuevo", "Contención Contención", "Santos Santos", "Identidad sexual", "Bautismo Bautismo", "Apologética Apologética", "Contención Contención", "Creación Creación", "Convenio de Abraham Convenio de Abraham", "Ayuno Ayuno", "Adán-ondi-Ahmán Adán-ondi-Ahmán", "Día de reposo Día de reposo", "Ropas blancas Ropas blancas", "Ropas blancas Ropas blancas", "Gloria Gloria", "Aarón; hermano de Moisés", "Pena de muerte Pena de muerte", "Satanás Satanás", "Adán Adán", "Celibato Celibato", "Templos Templos", "Aborto Aborto", "Cam Cam", "Apostasía general Apostasía general", "Idolatría Idolatría", "Día de reposo Día de reposo", "Emmanuel", "Deseo Deseo", "Animales", "Abeja Abeja", "Dignidad Dignidad", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Familia Familia", "Pecado", "Familia Familia", "Día de reposo Día de reposo", "Setentas Setentas", "Autodominio Autodominio", "Apologética Apologética", "Disciplina Disciplina", "Honor Honor", "Apologética Apologética", "Contención Contención", "Apologética Apologética", "Abeja Abeja", "Alabanza Alabanza", "Día de reposo Día de reposo", "Autoridad Autoridad", "Imposición de manos", "Llamamientos Llamamientos", "Ordenación Ordenación", "Revelación Revelación", "Tiempo Tiempo", "Control de la natalidad", "Conciencia Conciencia", "Dones espirituales Dones espirituales", "Condenación Condenación", "Milagros", "Imposición de manos Imposición de manos", "Apologética Apologética", "Fe Fe", "Sanidad Sanidad", "Juicio final Juicio final", "Albedrío Albedrío", "Albedrío Albedrío", "Albedrío Albedrío", "Condenación Condenación", "Seminario", "Trinidad Trinidad", "Hombre; Teosis", "José Smith; padre", "Juan el Bautista Juan el Bautista", "Juan el Bautista Juan el Bautista", "Espíritu Santo Espíritu Santo", "Consagración Consagración", "Matrimonio Matrimonio", "Matrimonio celestial Matrimonio celestial", "Sacrificio Sacrificio", "Misión de tiempo completo Misión de tiempo completo", "Obra misional Obra misional", "Protección", "Estados Unidos", "Matrimonio Matrimonio", "Matrimonio celestial Matrimonio celestial", "Orden patriarcal", "Matrimonio Matrimonio", "Sacrificio Sacrificio", "Bienestar Bienestar", "Servicio", "Bautismo Bautismo", "Bautismo Bautismo", "Familia Familia", "Alabanza Alabanza", "Ley de Cristo Ley de Cristo", "Arrepentimiento Arrepentimiento", "Justificación Justificación", "Fe Fe", "Expiación Expiación", "Expiación Expiación", "Conversión Conversión", "Testimonio Testimonio", "Aborto Aborto", "Escrituras; estudio de Escrituras; estudio de", "Educación académica Educación académica", "Estadísticas Estadísticas", "Great and Abominable Church Great and Abominable Church", "Bautismo Bautismo", "Baile Baile", "Aborto Aborto", "Contexto Contexto", "Autoridad Autoridad", "Apartamiento Apartamiento", "Decisiones", "Maestros (Docentes) Maestros (Docentes)", "Maestros (Docentes) Maestros (Docentes)", "Humildad Humildad", "Contención Contención", "Matrimonio celestial Matrimonio celestial", "Crítica Crítica", "Activación Activación", "Bautismo Bautismo", "Predicación del evangelio Predicación del evangelio", "Bautismo Bautismo", "Predicación del evangelio Predicación del evangelio", "Mujeres Mujeres", "Madres Madres", "Anécdotas Anécdotas", "Crecimiento de la Iglesia", "Valor", "Diligencia", "María; madre del Señor María; madre del Señor", "Misterios de Dios Misterios de Dios", "Lamán Lamán", "Jacob (hermano de Nefi)", "Convenio de la tierra Convenio de la tierra", "Convenio de la posteridad Convenio de la posteridad", "Genealogía", "Nefi Nefi", "Convenio de la tierra Convenio de la tierra", "Genealogía Genealogía", "Planchas de bronce Planchas de bronce", "Angeles Angeles", "Gloria Gloria", "Ley de los testigos Ley de los testigos", "Disciplina Disciplina", "Convenio de Abraham Convenio de Abraham", "Jacob (hermano de Nefi) Jacob (hermano de Nefi)", "Inmundo", "Juicio final Juicio final", "Educación académica Educación académica", "América América", "Caín Caín", "Juicio final Juicio final", "Ordenación Ordenación", "Convenio de la tierra Convenio de la tierra", "Arrepentimiento Arrepentimiento", "Apologética Apologética", "Apologética Apologética", "Nuevo nacimiento", "Misterios de Dios Misterios de Dios", "Ley de los testigos Ley de los testigos", "Contención Contención", "Jacob (hermano de Nefi) Jacob (hermano de Nefi)", "Rascismo Rascismo", "Día de reposo Día de reposo", "Disciplina Disciplina", "Escrituras Escrituras", "Primera resurrección Primera resurrección", "Baile Baile", "Amor al prójimo Amor al prójimo", "Gratitud Gratitud", "Autoridad Autoridad", "Pena de muerte Pena de muerte", "Satanás Satanás", "Preparación Preparación", "Albedrío Albedrío", "Nombre nuevo Nombre nuevo", "Dios; naturaleza corpórea de Dios; naturaleza corpórea de", "Emma Smith Emma Smith", "Convenio de Abraham Convenio de Abraham", "Sacerdocio Aarónico Sacerdocio Aarónico", "Guerra Guerra", "Alabanza Alabanza", "Santa Cena Santa Cena", "Gracia", "Santa Cena Santa Cena", "Bautismo Bautismo", "Autoridad Autoridad", "Apóstoles Apóstoles", "Espíritu Santo Espíritu Santo", "Apóstoles Apóstoles", "Bienestar Bienestar", "Consagración Consagración", "Amor al prójimo Amor al prójimo", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Milenio Milenio", "Convenio de la posteridad Convenio de la posteridad", "Monte de los Olivos", "Segunda Venida Segunda Venida", "Espíritu Santo Espíritu Santo", "Parábola de las diez vírgenes", "Segunda Venida Segunda Venida", "Música Música", "Arrepentimiento Arrepentimiento", "Consuelo Consuelo", "Apostasía Apostasía", "Conferencias Generales Conferencias Generales", "Domingo Domingo", "Día de reposo Día de reposo", "Obediencia Obediencia", "Misterios de Dios Misterios de Dios", "Misterios de Dios Misterios de Dios", "Satanás Satanás", "Ayuno Ayuno", "Adoración Adoración", "Templos Templos", "Albedrío Albedrío", "Música Música", "Dios; naturaleza corpórea de Dios; naturaleza corpórea de", "Música Música", "Baile Baile", "Bautismo Bautismo", "Perseverancia", "Anticristo(s) Anticristo(s)", "Justicia Justicia", "Dios; atributos de Dios; atributos de", "Cristianos Cristianos", "Modestia en el vestir", "Apariencia Apariencia", "Gratitud Gratitud", "Celibato Celibato", "Día de reposo Día de reposo", "Derechos de autor", "Ley de los testigos Ley de los testigos", "Matrimonio Matrimonio", "Matrimonio Matrimonio", "Apostasía general Apostasía general", "Día de reposo Día de reposo", "Santos Santos", "Circunsición", "Templos Templos", "Convenio de la posteridad Convenio de la posteridad", "Misterios de Dios Misterios de Dios", "Amor de Dios", "Disciplina Disciplina", "Día de reposo Día de reposo", "Sacerdocio", "Simbolismo del templo Simbolismo del templo", "Sumo Sacerdocio Sumo Sacerdocio", "Arrepentimiento Arrepentimiento", "Elderes Elderes", "Juan el Bautista Juan el Bautista", "Dios; puede ser visto Dios; puede ser visto", "Expiación Expiación", "Autoridad Autoridad", "Llamamientos Llamamientos", "Obra misional Obra misional", "Oración Oración", "Retención", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Domingo Domingo", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Dios; puede ser visto Dios; puede ser visto", "Oración Oración", "Herodes Antipas", "Apercepción Apercepción", "Abraham Abraham", "Obras Obras", "Bienestar Bienestar", "Consagración Consagración", "Codicia Codicia", "Juicio final Juicio final", "Mujeres Mujeres", "Discreción Discreción", "Domingo Domingo", "Expiación Expiación", "Apóstoles Apóstoles", "Santa Cena Santa Cena", "Baile Baile", "Discreción Discreción", "Juan el Amado Juan el Amado", "Jesucristo; Maestro", "Andrés", "Apercepción Apercepción", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Apercepción Apercepción", "Parábola de la perla de gran precio", "Pedro Pedro", "Pedro Pedro", "Disciplina Disciplina", "Matrimonio celestial Matrimonio celestial", "Humildad Humildad", "Niños pequeños Niños pequeños", "Amor al prójimo Amor al prójimo", "Día de reposo Día de reposo", "Santa Cena Santa Cena", "Bautismo Bautismo", "Confesión Confesión", "Disciplina Disciplina", "Celibato Celibato", "Ansiedad", "Discreción Discreción", "Ayuno Ayuno", "Amor al prójimo Amor al prójimo", "Falsedad Falsedad", "Amor al prójimo Amor al prójimo", "Condenación Condenación", "Justicia Justicia", "Indignación", "Expiación Expiación", "Satanás Satanás", "Jesucristo; Juez Jesucristo; Juez", "Apologética Apologética", "Enseñanza Enseñanza", "Celibato Celibato", "Expiación Expiación", "Creación Creación", "Investidura Investidura", "Gloria Gloria", "Día de reposo Día de reposo", "Dios; puede ser visto Dios; puede ser visto", "Día de reposo Día de reposo", "Ley de castidad Ley de castidad", "Ley de castidad Ley de castidad", "Día de reposo Día de reposo", "Dios; puede ser visto Dios; puede ser visto", "Simbolismo del templo Simbolismo del templo", "Ropas blancas Ropas blancas", "Día de reposo Día de reposo", "Pena de muerte Pena de muerte", "Eva", "Matrimonio plural", "Albedrío Albedrío", "Aborto Aborto", "Adopción (de infantes) Adopción (de infantes)", "Profecías mesiánicas", "Día de reposo Día de reposo", "Gloria Gloria", "Recogimiento Recogimiento", "Día de reposo Día de reposo", "Ayuno Ayuno", "Día de reposo Día de reposo", "Incesto Incesto", "Arrepentimiento Arrepentimiento", "Apercepción Apercepción", "Caída Caída", "Ayuno Ayuno", "Dios; puede ser visto Dios; puede ser visto", "Arrepentimiento Arrepentimiento", "Disciplina Disciplina", "Liderazgo Liderazgo", "Discernimiento", "Integridad Integridad", "Bienestar Bienestar", "Aceite Aceite", "Astros Astros", "Tiempo Tiempo", "Albedrío Albedrío", "Albedrío Albedrío", "Dios; atributos de Dios; atributos de", "Caín Caín", "Bautismo Bautismo", "Dones espirituales Dones espirituales", "Juicio final Juicio final", "Albedrío Albedrío", "Autosuficiencia espiritual", "Educación académica Educación académica", "José Smith; padre José Smith; padre", "Autoridad Autoridad", "Juan el Bautista Juan el Bautista", "Elías (precursor)", "Consagración Consagración", "Misión de tiempo completo Misión de tiempo completo", "Obediencia Obediencia", "Obra misional Obra misional", "Sacrificio Sacrificio", "Bienestar Bienestar", "Noviazgo Noviazgo", "Dios el Padre Dios el Padre", "Carácter Carácter", "Santa Cena Santa Cena", "Testimonio Testimonio", "Ley de castidad Ley de castidad", "Igualdad de género", "Familia Familia", "Jesucristo; Creador Jesucristo; Creador", "Apóstoles Apóstoles", "Santa Cena Santa Cena", "Anécdotas Anécdotas", "Matrimonio Matrimonio", "Jeremías Jeremías", "Apostasía general Apostasía general", "Santa Cena Santa Cena", "Crucifixión Crucifixión", "Expiación Expiación", "Pascua Pascua", "Sacrificio Sacrificio", "Simbolismo Simbolismo", "Halloween", "Convenios (en general) Convenios (en general)", "Bautismo Bautismo", "Bendición patriarcal Bendición patriarcal", "Arrepentimiento Arrepentimiento", "Contexto Contexto", "Far West", "Familia Familia", "Enseñanza Enseñanza", "Maestros (Docentes) Maestros (Docentes)", "Maestros (Docentes) Maestros (Docentes)", "Anécdotas Anécdotas", "Llamamientos Llamamientos", "Escrituras; estudio de Escrituras; estudio de", "Mujeres Mujeres", "Diezmo Diezmo", "Santa Cena Santa Cena", "Relativismo", "Betábara", "Restauración", "Santos Santos", "Liderazgo Liderazgo", "Deseo Deseo", "Escrituras; estudio de Escrituras; estudio de", "Convenio de la tierra Convenio de la tierra", "Corazón Corazón", "Don de sueños Don de sueños", "Muerte Muerte", "Satanás Satanás", "Rascismo Rascismo", "Condenación Condenación", "Escribir Escribir", "Ayuno Ayuno", "Santa Cena Santa Cena", "Arrepentimiento Arrepentimiento", "Condenación Condenación", "Consejo Consejo", "Confianza ante Dios Confianza ante Dios", "Conciencia Conciencia", "Alabanza Alabanza", "Gehenna", "Albedrío Albedrío", "Apologética Apologética", "Jareditas", "Convenio de la tierra Convenio de la tierra", "Apologética Apologética", "Nefi Nefi", "Escrituras Escrituras", "Consejo Consejo", "Bautismo Bautismo", "Enseñanza Enseñanza", "Profetas Profetas", "Bienestar Bienestar", "Escrituras Escrituras", "DE Recogimiento DE Recogimiento", "Finanzas Finanzas", "Deseo Deseo", "Adán Adán", "Autoridad Autoridad", "Ley de los testigos Ley de los testigos", "Palabra profética más segura", "Exaltación Exaltación", "Jesucristo; apariencia de", "Abraham Abraham", "Ejemplo Ejemplo", "Aprendizaje Aprendizaje", "Espíritu Santo; Don del Espíritu Santo; Don del", "Dios Dios", "Misterios de Dios Misterios de Dios", "Tentación", "Santa Cena Santa Cena", "Elderes Elderes", "DE Recogimiento DE Recogimiento", "Escrituras Escrituras", "Amor al prójimo Amor al prójimo", "Segunda Venida Segunda Venida", "Predicación del evangelio Predicación del evangelio", "Segunda Venida Segunda Venida", "Arrepentimiento Arrepentimiento", "Guerra Guerra", "Fe Fe", "Segunda Venida Segunda Venida", "Confesión Confesión", "Arrepentimiento Arrepentimiento", "Bautismo Bautismo", "Hijo Ahmán", "Reino Telestial", "Perdición Perdición", "Delegación", "Gloria Gloria", "Maestros (Docentes) Maestros (Docentes)", "Arrepentimiento Arrepentimiento", "Conocimiento Conocimiento", "Conversión Conversión", "Gloria Gloria", "Adoración Adoración", "Oración Oración", "Revelación Revelación", "Obra vicaria Obra vicaria", "Convenio de la posteridad Convenio de la posteridad", "Convenio de Enoc Convenio de Enoc", "Baile Baile", "Contención Contención", "Mujeres Mujeres", "Amor al prójimo Amor al prójimo", "Amor al prójimo Amor al prójimo", "Amor al prójimo Amor al prójimo", "Amor al prójimo Amor al prójimo", "Ley de Cristo Ley de Cristo", "Conciencia Conciencia", "Esposos", "Dones espirituales Dones espirituales", "Expiación Expiación", "Santa Cena Santa Cena", "Crítica Crítica", "Día de reposo Día de reposo", "Ley de los testigos Ley de los testigos", "Matrimonio Matrimonio", "Recogimiento Recogimiento", "Tiempo Tiempo", "Juicio final Juicio final", "Carácter Carácter", "Juicio parcial", "Escrituras; estudio de Escrituras; estudio de", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Domingo Domingo", "Día de reposo Día de reposo", "Celibato Celibato", "Cristianos Cristianos", "Santos Santos", "Alabanza Alabanza", "Apologética Apologética", "Aprendizaje Aprendizaje", "Expiación Expiación", "Pruebas", "Sacrificio Sacrificio", "Ejemplo Ejemplo", "Fe Fe", "Aprendizaje Aprendizaje", "Arrepentimiento Arrepentimiento", "Jesucristo; Maestro Jesucristo; Maestro", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Secreto mesiánico Secreto mesiánico", "Día de reposo Día de reposo", "Santa Cena Santa Cena", "Escrituras; estudio de Escrituras; estudio de", "Autoridad Autoridad", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Día de reposo Día de reposo", "Consagración Consagración", "Día de reposo Día de reposo", "Consagración Consagración", "Consagración Consagración", "Abuso Abuso", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Jesucristo; el Mesías", "Pedro Pedro", "Ayuno Ayuno", "Día de reposo Día de reposo", "Fe Fe", "Arrepentimiento Arrepentimiento", "Misión de tiempo completo Misión de tiempo completo", "Secreto mesiánico Secreto mesiánico", "Santa Cena Santa Cena", "Día de reposo Día de reposo", "Aceite Aceite", "Juan el Bautista Juan el Bautista", "Día de reposo Día de reposo", "Capacitación", "Parábola de la red", "Amonestación Amonestación", "Disciplina Disciplina", "Abuso Abuso", "Divorcio Divorcio", "Parábola de los obreros de la viña", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Dios el Padre Dios el Padre", "Escrituras; estudio de Escrituras; estudio de", "Honor Honor", "Discreción Discreción", "Riquezas", "Crítica Crítica", "Crítica Crítica", "Oración Oración", "Día de reposo Día de reposo", "Infierno", "Libro de la Vida Libro de la Vida", "Dignidad Dignidad", "Condenación Condenación", "Apostasía Apostasía", "Juan el Bautista Juan el Bautista", "Apostasía general Apostasía general", "Juicio final Juicio final", "Ayuno Ayuno", "Dios; puede ser visto Dios; puede ser visto", "Dios; puede ser visto Dios; puede ser visto", "Ayuno Ayuno", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Pangea", "Eva Eva", "Celibato Celibato", "Día de reposo Día de reposo", "Quiasmo Quiasmo", "Expiación Expiación", "Dios; puede ser visto Dios; puede ser visto", "Aborto Aborto", "Apercepción Apercepción", "Ayuno Ayuno", "Dios; puede ser visto Dios; puede ser visto", "Aceite Aceite", "Abeja Abeja", "Apostasía general Apostasía general", "Dios; puede ser visto Dios; puede ser visto", "Baile Baile", "Incesto Incesto", "Incesto Incesto", "Incesto Incesto", "Caída Caída", "Caída Caída", "Dios; puede ser visto Dios; puede ser visto", "Setentas Setentas", "Quiasmo Quiasmo", "Enseñanza Enseñanza", "Apologética Apologética", "Conciencia Conciencia", "Arrepentimiento Arrepentimiento", "Alabanza Alabanza", "Gratitud Gratitud", "Control de la natalidad Control de la natalidad", "Alabanza Alabanza", "Creación Creación", "Animales Animales", "Mundos", "Dios el Padre Dios el Padre", "Gloria Gloria", "Revelación Revelación", "Rascismo Rascismo", "Adán-ondi-Ahmán Adán-ondi-Ahmán", "Conferencias Generales Conferencias Generales", "Misterios de Dios Misterios de Dios", "Juicio final Juicio final", "Expiación Expiación", "Juicio final Juicio final", "Dios; naturaleza corpórea de Dios; naturaleza corpórea de", "Elías (precursor) Elías (precursor)", "Dones espirituales Dones espirituales", "Fe Fe", "Neutralidad política", "Obediencia civil", "Oración Oración", "Familia Familia", "Exaltación Exaltación", "Familia Familia", "Principios", "Espíritu Santo Espíritu Santo", "Activación Activación", "Restauración Restauración", "Enseñanza Enseñanza", "Enseñanza Enseñanza", "Iglesia Iglesia", "Racionalismo", "Hijos de Dios (por su paternidad preterrenal) Hijos de Dios (por su paternidad preterrenal)", "Aborto Aborto", "Autodeterminación Autodeterminación", "Consejos de la Iglesia Consejos de la Iglesia", "Anécdotas Anécdotas", "Apercepción Apercepción", "Preparación Preparación", "Obra vicaria Obra vicaria", "Amor al prójimo Amor al prójimo", "Actitud", "Matrimonio celestial Matrimonio celestial", "Consejos de la Iglesia Consejos de la Iglesia", "Albedrío Albedrío", "Día de reposo Día de reposo", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Faith", "Abeja Abeja", "Abominable Abominable", "Contención Contención", "Nauvoo", "Apologética Apologética", "Mansedumbre", "Mansedumbre Mansedumbre", "Apologética Apologética", "Activación Activación", "Apologética Apologética", "Activación Activación", "Conferencias Generales Conferencias Generales", "Conferencias Generales Conferencias Generales", "Anécdotas Anécdotas", "Enseñanza Enseñanza", "Transtornos emocionales", "Idolatría Idolatría", "Arrepentimiento Arrepentimiento", "Mujeres Mujeres", "Feminismo Feminismo", "Empleo", "Templos Templos", "Convenio de Abraham Convenio de Abraham", "Liahona Liahona", "Conocimiento Conocimiento", "Convenio de la tierra Convenio de la tierra", "Igualdad", "Crítica Crítica", "Lehi Lehi", "Genealogía Genealogía", "Gratitud Gratitud", "Control de la natalidad Control de la natalidad", "Gratitud Gratitud", "Esclavitud Esclavitud", "Albedrío Albedrío", "Jesucristo; es Jehová Jesucristo; es Jehová", "Gentiles Gentiles", "Combinaciones secretas Combinaciones secretas", "Libro de Mormón Libro de Mormón", "Profecías Profecías", "Conferencias Generales Conferencias Generales", "Enseñanza Enseñanza", "Jesucristo; Juez Jesucristo; Juez", "Rascismo Rascismo", "Santa Cena Santa Cena", "Santa Cena Santa Cena", "Santa Cena Santa Cena", "América América", "Resurrección Resurrección", "Nombre de Jesucristo", "Jesucristo; Creador Jesucristo; Creador", "Juicio final Juicio final", "Bautismo Bautismo", "Amor a Dios Amor a Dios", "Convenio de la tierra Convenio de la tierra", "Cristianos Cristianos", "Dios; atributos de Dios; atributos de", "María; madre del Señor María; madre del Señor", "Sacerdocio Sacerdocio", "Rascismo Rascismo", "Bienestar Bienestar", "Juicio final Juicio final", "Niños pequeños Niños pequeños", "Día de reposo Día de reposo", "Gratitud Gratitud", "Oración Oración", "Contención Contención", "Arrepentimiento Arrepentimiento", "Caída Caída", "Confesión Confesión", "Enseñanza Enseñanza", "Autoridad Autoridad", "Investidura Investidura", "Setentas Setentas", "Adán Adán", "Llamamientos Llamamientos", "Setentas Setentas", "Poder sellador Poder sellador", "Angeles Angeles", "José Smith José Smith", "Abraham Abraham", "Escrituras; estudio de Escrituras; estudio de", "Deudas", "Codicia Codicia", "Oración Oración", "Bautismo Bautismo", "Adán Adán", "Preparación Preparación", "Unidad Unidad", "Ley de castidad Ley de castidad", "Discernimiento Discernimiento", "Confidencia", "Apostasía general Apostasía general", "Ayuno Ayuno", "Combinaciones secretas Combinaciones secretas", "Día de reposo Día de reposo", "Gratitud Gratitud", "Arrepentimiento Arrepentimiento", "Gratitud Gratitud", "Niños pequeños Niños pequeños", "Satanás Satanás", "Arrepentimiento Arrepentimiento", "Convenios Convenios", "Arcángel Arcángel", "Pornografía", "Falsedad Falsedad", "Isaías", "Espíritu Santo Espíritu Santo", "Obra vicaria Obra vicaria", "Alimentos Alimentos", "Santa Cena Santa Cena", "Mujeres Mujeres", "Simbolismo del templo Simbolismo del templo", "Santa Cena Santa Cena", "Bautismo Bautismo", "Discreción Discreción", "Milenio Milenio", "Confesión Confesión", "Arrepentimiento Arrepentimiento", "Apologética Apologética", "Conocimiento de Dios Conocimiento de Dios", "Conocimiento de Dios Conocimiento de Dios", "Bienestar Bienestar", "Apariencia Apariencia", "Apostasía general Apostasía general", "Perdón de los pecados Perdón de los pecados", "Hijos del diablo", "Dios Dios", "Dios; naturaleza corpórea de Dios; naturaleza corpórea de", "Día de reposo Día de reposo", "Reino Celestial Reino Celestial", "Matrimonio Matrimonio", "Matrimonio Matrimonio", "Jacob (Israel)", "Recogimiento Recogimiento", "Palabra profética más segura Palabra profética más segura", "Juicio final Juicio final", "Apóstoles Apóstoles", "Enseñanza Enseñanza", "Escrituras; estudio de Escrituras; estudio de", "Llamamientos Llamamientos", "Misterios de Dios Misterios de Dios", "Gratitud Gratitud", "Apóstoles Apóstoles", "Ira Ira", "Jesucristo es un Dios Jesucristo es un Dios", "Condenación Condenación", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Bautismo Bautismo", "Ordenación Ordenación", "Sacerdocio Aarónico Sacerdocio Aarónico", "Diezmo Diezmo", "Patriarca (primeros Padres) Patriarca (primeros Padres)", "Amor al prójimo Amor al prójimo", "Actitud Actitud", "Bienestar Bienestar", "Música Música", "Jesucristo; Creador Jesucristo; Creador", "Espíritu Santo Espíritu Santo", "Dios el Padre Dios el Padre", "Jesucristo; Rey de los judíos Jesucristo; Rey de los judíos", "Testimonio Testimonio", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "María Magdalena", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Adán Adán", "Autoridad Autoridad", "Trabajo Trabajo", "Idolatría Idolatría", "Jerusalén Jerusalén", "Reino de Dios Reino de Dios", "Pedro Pedro", "Angeles Angeles", "Barrabás", "Barrabás Barrabás", "Jesucristo; Rey de los judíos Jesucristo; Rey de los judíos", "Día de reposo Día de reposo", "Ayuno Ayuno", "Día de reposo Día de reposo", "Bautismo Bautismo", "Maestros (Docentes) Maestros (Docentes)", "Secreto mesiánico Secreto mesiánico", "Pedro Pedro", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Día de reposo Día de reposo", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Jesucristo; Maestro Jesucristo; Maestro", "Parábola del trigo y la cizaña Parábola del trigo y la cizaña", "Gloria Gloria", "Consagración Consagración", "Ley de los testigos Ley de los testigos", "Amistad Amistad", "Finanzas Finanzas", "Parábola de los labradores malvados", "Consagración Consagración", "Ley de Cristo Ley de Cristo", "Aceite Aceite", "Parábola de las diez vírgenes Parábola de las diez vírgenes", "Preparación Preparación", "Segunda Venida Segunda Venida", "Juan el Bautista Juan el Bautista", "Espíritu Santo; Don del Espíritu Santo; Don del", "Espíritus inmundos", "Expiación Expiación", "Reino Celestial Reino Celestial", "Dios; puede ser visto Dios; puede ser visto", "Guerra contra el mal", "Dios; puede ser visto Dios; puede ser visto", "Estrella (símbolica) Estrella (símbolica)", "Reino de Dios Reino de Dios", "Alabanza Alabanza", "Juicio final Juicio final", "Bautismo Bautismo", "Apostasía personal Apostasía personal", "Esperanza", "Pangea Pangea", "Alabanza Alabanza", "Adán-ondi-Ahmán Adán-ondi-Ahmán", "Ley de los testigos Ley de los testigos", "Recogimiento Recogimiento", "Consejo Consejo", "Dios; puede ser visto Dios; puede ser visto", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Pena de muerte Pena de muerte", "Pena de muerte Pena de muerte", "Cus", "Templos Templos", "Abraham Abraham", "Adán Adán", "Adán Adán", "Alimentos Alimentos", "Conciencia Conciencia", "Madres Madres", "Adán Adán", "Hombre; Teosis Hombre; Teosis", "Recogimiento Recogimiento", "Quiasmo Quiasmo", "Templos Templos", "Sión Sión", "Jesucristo es un Dios Jesucristo es un Dios", "Ordenación Ordenación", "Preordenación Preordenación", "Profetas Profetas", "Santificación", "Vida preterrenal Vida preterrenal", "Rascismo Rascismo", "Jerusalén Jerusalén", "Astros Astros", "Jerusalén Jerusalén", "Rascismo Rascismo", "Adulterio Adulterio", "Disciplina Disciplina", "Arrepentimiento Arrepentimiento", "Blasfemia", "Amor al prójimo Amor al prójimo", "Arrepentimiento Arrepentimiento", "Disciplina Disciplina", "Igualdad Igualdad", "Igualdad Igualdad", "Mujeres Mujeres", "Convenios (en general) Convenios (en general)", "Disciplina Disciplina", "Jesucristo; Juez Jesucristo; Juez", "Patriarca (primeros Padres) Patriarca (primeros Padres)", "Exaltación Exaltación", "Concilio de los Cielos Concilio de los Cielos", "Animales Animales", "Mundos Mundos", "Escrituras; estudio de Escrituras; estudio de", "Sanidad Sanidad", "Misterios de Dios Misterios de Dios", "Dones espirituales Dones espirituales", "Discreción Discreción", "Discreción Discreción", "Dones espirituales Dones espirituales", "Dones espirituales Dones espirituales", "Revelación Revelación", "Discreción Discreción", "Albedrío Albedrío", "Albedrío Albedrío", "Gloria Gloria", "Funerales Funerales", "Trinidad Trinidad", "Dios; atributos de Dios; atributos de", "Dios; atributos de Dios; atributos de", "José Smith José Smith", "Juan el Bautista Juan el Bautista", "Bautismo Bautismo", "Apostasía Apostasía", "Dignidad Dignidad", "Preparación Preparación", "Consagración Consagración", "Misión de tiempo completo Misión de tiempo completo", "Noviazgo Noviazgo", "Obra misional Obra misional", "Misión de tiempo completo Misión de tiempo completo", "Noviazgo Noviazgo", "Bautismo Bautismo", "Reino de Dios Reino de Dios", "Familia Familia", "Amonestación Amonestación", "Amonestación Amonestación", "Sacrificio Sacrificio", "Enseñanza Enseñanza", "Racionalismo Racionalismo", "Enseñanza Enseñanza", "Hombre; Teosis Hombre; Teosis", "Divorcio Divorcio", "Identidad sexual Identidad sexual", "Bautismo Bautismo", "Lorenzo Snow", "Predicación del evangelio Predicación del evangelio", "Parley P. Pratt", "Expiación Expiación", "Secret Combination", "Baile Baile", "Bendición patriarcal Bendición patriarcal", "Baile Baile", "Preguntas (técnica didáctica) Preguntas (técnica didáctica)", "Preguntas (técnica didáctica) Preguntas (técnica didáctica)", "Juan el Amado Juan el Amado", "Maestros (Docentes) Maestros (Docentes)", "Maestros (Docentes) Maestros (Docentes)", "Arrepentimiento Arrepentimiento", "Ansiedad Ansiedad", "Conversión Conversión", "Activación Activación", "Investidura Investidura", "Conferencias Generales Conferencias Generales", "Anécdotas Anécdotas", "Fe Fe", "Anécdotas Anécdotas", "Llamamientos Llamamientos", "Arrepentimiento Arrepentimiento", "Familia Familia", "Diezmo Diezmo", "Bienestar Bienestar", "Firmeza de carácter", "Fe Fe", "Valor Valor", "Valor Valor", "Oposición Oposición", "Valor Valor", "Apologética Apologética", "Espíritu Santo; Don del Espíritu Santo; Don del", "Revelación Revelación", "Apóstoles Apóstoles", "Simbolismo Simbolismo", "Alabanza Alabanza", "Libro de Lehi", "Liahona Liahona", "Oración Oración", "Enseñanza Enseñanza", "Alimentos Alimentos", "Genealogía Genealogía", "Angeles Angeles", "Genealogía Genealogía", "Escrituras; estudio de Escrituras; estudio de", "Juramentos Juramentos", "Lehi Lehi", "Escrituras Escrituras", "Labán (pariente de Lehi)", "Simbolismo Simbolismo", "Angeles Angeles", "Condenación Condenación", "Jesucristo; el Mesías Jesucristo; el Mesías", "Probación (pruebas) Probación (pruebas)", "Convenio de la tierra Convenio de la tierra", "Escrituras Escrituras", "Educación académica Educación académica", "Santa Cena Santa Cena", "Santa Cena Santa Cena", "Caín Caín", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Apologética Apologética", "Cristianos Cristianos", "Satanás Satanás", "Gloria Gloria", "Exaltación Exaltación", "Llamamientos Llamamientos", "Misión de tiempo completo Misión de tiempo completo", "Obra misional Obra misional", "Ordenación Ordenación", "Muerte espiritual Muerte espiritual", "Ayuno Ayuno", "Testimonio Testimonio", "Amor a Dios Amor a Dios", "Convenio de Abraham Convenio de Abraham", "América América", "Cristianos Cristianos", "Disciplina Disciplina", "Juicio final Juicio final", "Alabanza Alabanza", "Ética Ética", "Bautismo Bautismo", "Convenios Convenios", "Santa Cena Santa Cena", "Hijos de Dios (por el nuevo nacimiento) Hijos de Dios (por el nuevo nacimiento)", "Bienestar Bienestar", "Misterios de Dios Misterios de Dios", "Maestros (Docentes) Maestros (Docentes)", "Adán Adán", "Iglesia Iglesia", "Estacas", "Diezmo Diezmo", "Amor a Dios Amor a Dios", "Predicación del evangelio Predicación del evangelio", "Investidura Investidura", "Investidura Investidura", "Dios; puede ser visto Dios; puede ser visto", "Segunda Venida Segunda Venida", "Estados Unidos Estados Unidos", "Emma Smith Emma Smith", "Adulterio Adulterio", "David David", "Adulterio Adulterio", "Alabanza Alabanza", "Enseñanza Enseñanza", "Funerales Funerales", "Liderazgo Liderazgo", "Preordenación Preordenación", "Vida preterrenal Vida preterrenal", "Jesucristo", "Misión de tiempo completo Misión de tiempo completo", "Consagración Consagración", "Bienestar Bienestar", "Adán Adán", "Gracia Gracia", "Satanás Satanás", "José Smith José Smith", "Discernimiento Discernimiento", "Nombre de Jesucristo Nombre de Jesucristo", "Segunda Venida Segunda Venida", "Guerra Guerra", "Nueva Jerusalén", "Lamanitas Lamanitas", "Conocimiento Conocimiento", "Obediencia Obediencia", "Dios; puede ser visto Dios; puede ser visto", "José Smith José Smith", "Misterios de Dios Misterios de Dios", "Poder sellador Poder sellador", "Juicio de Dios Juicio de Dios", "Misterios de Dios Misterios de Dios", "Consejos de la Iglesia Consejos de la Iglesia", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Astros Astros", "Conocimiento Conocimiento", "Educación académica Educación académica", "Reino de Dios Reino de Dios", "Gloria Gloria", "Aprendizaje Aprendizaje", "Consuelo Consuelo", "Templos Templos", "Gárments Gárments", "Alabanza Alabanza", "Música Música", "Música Música", "Bautismo Bautismo", "Apologética Apologética", "Celibato Celibato", "Ejemplo Ejemplo", "Orden patriarcal Orden patriarcal", "Arrepentimiento Arrepentimiento", "Bautismo por los muertos", "Expiación Expiación", "Homicidio", "Anticristo(s) Anticristo(s)", "Gloria Gloria", "Santa Cena Santa Cena", "Llamamientos Llamamientos", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Recogimiento Recogimiento", "Recogimiento Recogimiento", "Recogimiento Recogimiento", "Corazón Corazón", "Dignidad Dignidad", "Carácter Carácter", "Aprendizaje Aprendizaje", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Vida preterrenal Vida preterrenal", "Adopción (de los gentiles) Adopción (de los gentiles)", "Gratitud Gratitud", "Jesucristo es un Dios Jesucristo es un Dios", "Adopción (de los gentiles) Adopción (de los gentiles)", "Adopción (de los gentiles) Adopción (de los gentiles)", "Dios el Padre Dios el Padre", "Convenio de Abraham Convenio de Abraham", "Obediencia Obediencia", "Fe Fe", "Bienestar Bienestar", "Bienestar Bienestar", "Crítica Crítica", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Amor a Dios Amor a Dios", "Dios el Padre Dios el Padre", "Dios el Padre Dios el Padre", "Escrituras; estudio de Escrituras; estudio de", "Mundo de los espíritus", "Día de reposo Día de reposo", "Dignidad Dignidad", "Setentas Setentas", "Poncio Pilato", "Discreción Discreción", "Betania", "Espíritus Espíritus", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Juan el Amado Juan el Amado", "Barrabás Barrabás", "Ayuno Ayuno", "Secreto mesiánico Secreto mesiánico", "Día de reposo Día de reposo", "Genealogía de Jesucristo", "Secreto mesiánico Secreto mesiánico", "Elías (precursor) Elías (precursor)", "Parábola del sembrador", "Jesucristo; Hijo del Hombre Jesucristo; Hijo del Hombre", "Arrepentimiento Arrepentimiento", "Autoridad Autoridad", "Apóstoles Apóstoles", "Bautismo Bautismo", "Autoridad Autoridad", "Concilio de los Cielos Concilio de los Cielos", "Jesucristo; Hijo del Hombre Jesucristo; Hijo del Hombre", "Expiación Expiación", "Convenio de Abraham Convenio de Abraham", "Ley de Moisés Ley de Moisés", "Fe Fe", "Perdón al prójimo Perdón al prójimo", "Confidencia Confidencia", "Condenación Condenación", "Jesucristo; Maestro Jesucristo; Maestro", "Apologética Apologética", "Disciplina Disciplina", "Escribas", "Adulterio Adulterio", "Dignidad Dignidad", "Apologética Apologética", "Satanás Satanás", "Ropas blancas Ropas blancas", "Escrituras Escrituras", "Infierno Infierno", "Expiación Expiación", "Crítica Crítica", "Adopción (de los gentiles) Adopción (de los gentiles)", "Espíritu Santo Espíritu Santo", "Juan el Bautista Juan el Bautista", "Día de reposo Día de reposo", "Aceite Aceite", "Misterios de Dios Misterios de Dios", "Ayuno Ayuno", "Baile Baile", "Dios; puede ser visto Dios; puede ser visto", "Dios; puede ser visto Dios; puede ser visto", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Contención Contención", "Alimentos Alimentos", "Astros Astros", "Evolución", "Arbol de la ciencia Arbol de la ciencia", "Altar Altar", "Simbolismo del templo Simbolismo del templo", "Arbol de la ciencia Arbol de la ciencia", "Aborto Aborto", "Aborto Aborto", "Aborto Aborto", "Aborto Aborto", "Aborto Aborto", "Aborto Aborto", "Adán Adán", "Recogimiento Recogimiento", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Día de reposo Día de reposo", "Concilio de los Cielos Concilio de los Cielos", "Aceite Aceite", "Incesto Incesto", "Incesto Incesto", "Albedrío Albedrío", "Día de reposo Día de reposo", "Pena de muerte Pena de muerte", "Consejos", "Arrepentimiento Arrepentimiento", "Apologética Apologética", "Simbolismo del templo Simbolismo del templo", "Ayuno Ayuno", "Convenios (en general) Convenios (en general)", "Codicia Codicia", "Satanás Satanás", "Bautismo Bautismo", "Simbolismo Simbolismo", "Adán Adán", "Espíritu Santo Espíritu Santo", "Milagros Milagros", "Reinos de gloria", "Arrepentimiento Arrepentimiento", "Conocimiento Conocimiento", "Trinidad Trinidad", "Elías (precursor) Elías (precursor)", "Juan el Bautista Juan el Bautista", "Juan el Bautista Juan el Bautista", "Apologética Apologética", "Apologética Apologética", "Misión de tiempo completo Misión de tiempo completo", "Noviazgo Noviazgo", "Sacrificio Sacrificio", "Paternidad Paternidad", "Familia Familia", "Familia Familia", "Anécdotas Anécdotas", "Arrepentimiento Arrepentimiento", "Arrepentimiento Arrepentimiento", "Restauración Restauración", "Maestros (Docentes) Maestros (Docentes)", "Ética Ética", "Iglesia Iglesia", "Apologética Apologética", "Amor a Dios Amor a Dios", "Familia Familia", "Abuso Abuso", "Familia Familia", "Disciplina Disciplina", "Adulterio Adulterio", "Familia Familia", "Jesucristo Jesucristo", "Jesucristo; misión de Jesucristo; misión de", "Ejemplo Ejemplo", "Jesucristo; el Mesías Jesucristo; el Mesías", "Adopción (de infantes) Adopción (de infantes)", "Anécdotas Anécdotas", "Libro de Mormón Libro de Mormón", "Oración Oración", "Apercepción Apercepción", "Probación (pruebas) Probación (pruebas)", "Bendición patriarcal Bendición patriarcal", "Bendición patriarcal Bendición patriarcal", "Baile Baile", "Preguntas (técnica didáctica) Preguntas (técnica didáctica)", "Maestros (Docentes) Maestros (Docentes)", "Juan el Bautista Juan el Bautista", "Experiencia", "Humildad Humildad", "Espíritu Santo; Don del Espíritu Santo; Don del", "Conferencias Generales Conferencias Generales", "Activación Activación", "Anécdotas Anécdotas", "Feminismo Feminismo", "Feminismo Feminismo", "Almacenamiento Almacenamiento", "Apologética Apologética", "Liahona Liahona", "Liahona Liahona", "Pena de muerte Pena de muerte", "Juramentos Juramentos", "Escrituras; estudio de Escrituras; estudio de", "Razas", "Ayuno Ayuno", "Rascismo Rascismo", "Jesucristo; Buen Pastor", "Disciplina Disciplina", "Escrituras; estudio de Escrituras; estudio de", "Lehi Lehi", "Libro de Mormón Libro de Mormón", "Funerales Funerales", "Condenación Condenación", "Bienestar Bienestar", "Angeles Angeles", "Amistad Amistad", "Abraham Abraham", "Deseo Deseo", "Arrepentimiento Arrepentimiento", "Expiación Expiación", "Mundo de los espíritus Mundo de los espíritus", "Obra vicaria Obra vicaria", "Templos Templos", "Elderes Elderes", "Satanás Satanás", "Gratitud Gratitud", "Dignidad Dignidad", "Bautismo Bautismo", "Día de reposo Día de reposo", "Bautismo Bautismo", "Arcángel Arcángel", "Arcángel Arcángel", "Jesucristo; preordenación de", "Homicidio Homicidio", "Parábola de los labradores malvados Parábola de los labradores malvados", "Santa Cena Santa Cena", "Confianza ante Dios Confianza ante Dios", "Convenio y juramento del sacerdocio Convenio y juramento del sacerdocio", "Perdón al prójimo Perdón al prójimo", "Convenio de Abraham Convenio de Abraham", "Arrepentimiento Arrepentimiento", "Cristianos Cristianos", "Antioquía", "Apariencia Apariencia", "Confesión Confesión", "Hijos de Dios (por el nuevo nacimiento) Hijos de Dios (por el nuevo nacimiento)", "Domingo Domingo", "Día de reposo Día de reposo", "Jesucristo; es Jehová Jesucristo; es Jehová", "Dios; puede ser visto Dios; puede ser visto", "Jesucristo; Rey de los judíos Jesucristo; Rey de los judíos", "Destrucción de Jerusalén", "Genealogía de Jesucristo Genealogía de Jesucristo", "Día de reposo Día de reposo", "Arrepentimiento Arrepentimiento", "Arrepentimiento Arrepentimiento", "Mujeres Mujeres", "Ayuno Ayuno", "Juan el Amado Juan el Amado", "Alabanza Alabanza", "Gentiles Gentiles", "Dios el Padre Dios el Padre", "Alimentos Alimentos", "Autoridad Autoridad", "Pena de muerte Pena de muerte", "Nombre nuevo Nombre nuevo", "Misterios de Dios Misterios de Dios", "Carácter Carácter", "Amor de Dios Amor de Dios", "Aceite Aceite", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Pangea Pangea", "Pangea Pangea", "Simbolismo del templo Simbolismo del templo", "Esclavitud Esclavitud", "Diáspora", "Recogimiento Recogimiento", "Crítica Crítica", "Muerte Muerte", "Aarón; hermano de Moisés Aarón; hermano de Moisés", "Arrepentimiento Arrepentimiento", "Juicio de Dios Juicio de Dios", "Educación académica Educación académica", "Día de reposo Día de reposo", "Jesucristo; Creador Jesucristo; Creador", "Templos Templos", "Convenio de la tierra Convenio de la tierra", "Espíritu Santo Espíritu Santo", "Igualdad Igualdad", "Hombre; Teosis Hombre; Teosis", "Asael Smith", "Familia Familia", "Familia Familia", "Matrimonio Matrimonio", "Santa Cena Santa Cena", "Esclavitud Esclavitud", "Sacerdocio Sacerdocio", "Obra vicaria Obra vicaria", "Anécdotas Anécdotas", "Church Church", "Comunión Comunión", "Abeja Abeja"]
        
        for tagName in tagNames {
            try! annotationStore.addTag(name: tagName)
        }
        
        let expected = ["Aarón; hermano de Moisés Aarón; hermano de Moisés", "Aarón; hermano de Moisés", "Abeja Abeja", "Abeja", "Abominable Abominable", "Abominable", "Aborto Aborto", "Aborto", "Abraham Abraham", "Abraham", "Abuso Abuso", "Abuso", "Aceite Aceite", "Aceite", "Actitud Actitud", "Actitud", "Activación Activación", "Activación", "Adopción (de infantes) Adopción (de infantes)", "Adopción (de infantes)", "Adopción (de los gentiles) Adopción (de los gentiles)", "Adopción (de los gentiles)", "Adoración Adoración", "Adoración", "Adulterio Adulterio", "Adulterio", "Adán Adán", "Adán", "Adán-ondi-Ahmán Adán-ondi-Ahmán", "Adán-ondi-Ahmán", "Alabanza Alabanza", "Alabanza", "Albedrío Albedrío", "Albedrío", "Alimentos Alimentos", "Alimentos", "Almacenamiento Almacenamiento", "Almacenamiento", "Altar Altar", "Altar", "Amistad Amistad", "Amistad", "Amonestación Amonestación", "Amonestación", "Amor a Dios Amor a Dios", "Amor a Dios", "Amor al prójimo Amor al prójimo", "Amor al prójimo", "Amor de Dios Amor de Dios", "Amor de Dios", "América América", "América", "Ananías", "Andrés", "Angeles Angeles", "Angeles", "Animales Animales", "Animales", "Ansiedad Ansiedad", "Ansiedad", "Anticristo(s) Anticristo(s)", "Anticristo(s)", "Antioquía", "Anécdotas Anécdotas", "Anécdotas", "Apariencia Apariencia", "Apariencia", "Apartamiento Apartamiento", "Apartamiento", "Apartheid", "Apercepción Apercepción", "Apercepción", "Apologética Apologética", "Apologética", "Apostasy", "Apostasía Apostasía", "Apostasía general Apostasía general", "Apostasía general", "Apostasía personal Apostasía personal", "Apostasía personal", "Apostasía", "Aprendizaje Aprendizaje", "Aprendizaje", "Apóstoles Apóstoles", "Apóstoles", "Arbol de la ciencia Arbol de la ciencia", "Arbol de la ciencia", "Arbol de la vida Arbol de la vida", "Arbol de la vida", "Arcángel Arcángel", "Arcángel", "Arrepentimiento Arrepentimiento", "Arrepentimiento", "Asael Smith", "Asertividad", "Astros Astros", "Astros", "Atención", "Autodeterminación Autodeterminación", "Autodeterminación", "Autodominio Autodominio", "Autodominio", "Autoestima", "Autoridad Autoridad", "Autoridad", "Autosuficiencia espiritual", "Autosuficiencia temporal Autosuficiencia temporal", "Autosuficiencia temporal", "Ayuno Ayuno", "Ayuno", "Babilonia", "Baile Baile", "Baile", "Barrabás Barrabás", "Barrabás", "Bautismo Bautismo", "Bautismo por los muertos", "Bautismo", "Bendición patriarcal Bendición patriarcal", "Bendición patriarcal", "Betania", "Betábara", "Biblia", "Bienestar Bienestar", "Bienestar", "Blasfemia", "Cam Cam", "Cam", "Camino", "Capacitación", "Caridad", "Carácter Carácter", "Carácter", "Caída Caída", "Caída", "Caín Caín", "Caín", "Celebraciones", "Celibato Celibato", "Celibato", "Church Church", "Church", "Circunsición", "Clero laico", "Codicia Codicia", "Codicia", "Combinaciones secretas Combinaciones secretas", "Combinaciones secretas", "Comunicación Comunicación", "Comunicación", "Comunión Comunión", "Comunión", "Conciencia Conciencia", "Conciencia", "Concilio de los Cielos Concilio de los Cielos", "Concilio de los Cielos", "Condenación Condenación", "Condenación", "Conferencias Generales Conferencias Generales", "Conferencias Generales", "Confesión Confesión", "Confesión", "Confianza ante Dios Confianza ante Dios", "Confianza ante Dios", "Confidencia Confidencia", "Confidencia", "Conocimiento Conocimiento", "Conocimiento de Dios Conocimiento de Dios", "Conocimiento de Dios", "Conocimiento", "Consagración Consagración", "Consagración", "Consejo Consejo", "Consejo", "Consejos de la Iglesia Consejos de la Iglesia", "Consejos de la Iglesia", "Consejos", "Consuelo Consuelo", "Consuelo", "Contención Contención", "Contención", "Contexto Contexto", "Contexto", "Continuación de vidas", "Control de la natalidad Control de la natalidad", "Control de la natalidad", "Convenio de Abraham Convenio de Abraham", "Convenio de Abraham", "Convenio de Enoc Convenio de Enoc", "Convenio de Enoc", "Convenio de la posteridad Convenio de la posteridad", "Convenio de la posteridad", "Convenio de la tierra Convenio de la tierra", "Convenio de la tierra", "Convenio de Noé", "Convenio y juramento del sacerdocio Convenio y juramento del sacerdocio", "Convenio y juramento del sacerdocio", "Convenios (en general) Convenios (en general)", "Convenios (en general)", "Convenios Convenios", "Convenios", "Conversión Conversión", "Conversión", "Corazón Corazón", "Corazón", "Coronas", "Creación Creación", "Creación", "Crecimiento de la Iglesia", "Cristianos Cristianos", "Cristianos", "Cronología Cronología", "Cronología", "Crucifixión Crucifixión", "Crucifixión", "Crítica Crítica", "Crítica", "Cus", "David David", "David Whitmer", "David", "DE Recogimiento DE Recogimiento", "DE Recogimiento", "Decisiones", "Delegación", "Derecha", "Derechos de autor", "Desastres naturales", "Deseo Deseo", "Deseo", "Destrucción de Jerusalén", "Deudas", "Diezmo Diezmo", "Diezmo", "Dignidad Dignidad", "Dignidad", "Diligencia", "Dios Dios", "Dios el Padre Dios el Padre", "Dios el Padre", "Dios", "Dios; atributos de Dios; atributos de", "Dios; atributos de", "Dios; existencia de Dios; existencia de", "Dios; existencia de", "Dios; naturaleza corpórea de Dios; naturaleza corpórea de", "Dios; naturaleza corpórea de", "Dios; puede ser visto Dios; puede ser visto", "Dios; puede ser visto", "Discernimiento Discernimiento", "Discernimiento", "Disciplina Disciplina", "Disciplina", "Discreción Discreción", "Discreción", "Discriminación", "Divorcio Divorcio", "Divorcio", "Diáspora", "Doctrina y Convenios", "Domingo Domingo", "Domingo", "Don de sueños Don de sueños", "Don de sueños", "Dones espirituales Dones espirituales", "Dones espirituales", "Dudas", "Día de reposo Día de reposo", "Día de reposo", "Educación académica Educación académica", "Educación académica", "Ejemplo Ejemplo", "Ejemplo", "El joven rico", "Elderes Elderes", "Elderes", "Elías (el Profeta)", "Elías (precursor) Elías (precursor)", "Elías (precursor)", "Emma Smith Emma Smith", "Emma Smith", "Emmanuel", "Empleo", "Enoc", "Enseñanza Enseñanza", "Enseñanza", "Esclavitud Esclavitud", "Esclavitud", "Escogidos", "Escribas", "Escribir Escribir", "Escribir", "Escrituras adicionales Escrituras adicionales", "Escrituras adicionales", "Escrituras Escrituras", "Escrituras", "Escrituras; estudio de Escrituras; estudio de", "Escrituras; estudio de", "Esperanza", "Esposos", "Espíritu Santo Espíritu Santo", "Espíritu Santo", "Espíritu Santo; Don del Espíritu Santo; Don del", "Espíritu Santo; Don del", "Espíritus Espíritus", "Espíritus inmundos", "Espíritus", "Estacas", "Estados Unidos Estados Unidos", "Estados Unidos", "Estadísticas Estadísticas", "Estadísticas", "Estrella (símbolica) Estrella (símbolica)", "Estrella (símbolica)", "Eva Eva", "Eva", "Evolución", "Exaltación Exaltación", "Exaltación", "Experiencia", "Expiación Expiación", "Expiación", "Faith", "Falsedad Falsedad", "Falsedad", "Familia Familia", "Familia", "Far West", "Fariseos", "Fe Fe", "Fe", "Felicidad Felicidad", "Felicidad", "Feminismo Feminismo", "Feminismo", "Fidelidad", "Finanzas Finanzas", "Finanzas", "Firmeza de carácter", "Fraternidad", "Funerales Funerales", "Funerales", "Gehenna", "Genealogía de Jesucristo Genealogía de Jesucristo", "Genealogía de Jesucristo", "Genealogía Genealogía", "Genealogía", "Gentiles Gentiles", "Gentiles", "Geografía", "Gloria Gloria", "Gloria", "Gog", "Gracia Gracia", "Gracia", "Gratitud Gratitud", "Gratitud", "Great and Abominable Church Great and Abominable Church", "Great and Abominable Church", "Guerra contra el mal", "Guerra Guerra", "Guerra", "Gárments Gárments", "Gárments", "Hades", "Halloween", "Herodes Antipas", "Hijo Ahmán", "Hijos de Dios (por el nuevo nacimiento) Hijos de Dios (por el nuevo nacimiento)", "Hijos de Dios (por el nuevo nacimiento)", "Hijos de Dios (por su paternidad preterrenal) Hijos de Dios (por su paternidad preterrenal)", "Hijos de Dios (por su paternidad preterrenal)", "Hijos de Perdición Hijos de Perdición", "Hijos de Perdición", "Hijos del diablo", "Hombre; Teosis Hombre; Teosis", "Hombre; Teosis", "Homicidio Homicidio", "Homicidio", "Homosexualidad", "Honor Honor", "Honor", "Humildad Humildad", "Humildad", "Identidad sexual Identidad sexual", "Identidad sexual", "Idolatría Idolatría", "Idolatría", "Iglesia Iglesia", "Iglesia", "Iglesia; organización de;", "Igualdad de género", "Igualdad Igualdad", "Igualdad", "Impiedad", "Imposición de manos Imposición de manos", "Imposición de manos", "Incesto Incesto", "Incesto", "Indignación", "Infierno Infierno", "Infierno", "Inmundo", "Integridad Integridad", "Integridad", "Inteligencia", "Investidura Investidura", "Investidura", "Ira Ira", "Ira", "Isaías", "Jacob (hermano de Nefi) Jacob (hermano de Nefi)", "Jacob (hermano de Nefi)", "Jacob (Israel)", "Jareditas", "Jeremías Jeremías", "Jeremías", "Jerusalén Jerusalén", "Jerusalén", "Jesucristo es un Dios Jesucristo es un Dios", "Jesucristo es un Dios", "Jesucristo Jesucristo", "Jesucristo", "Jesucristo; apariencia de", "Jesucristo; Buen Pastor", "Jesucristo; Creador Jesucristo; Creador", "Jesucristo; Creador", "Jesucristo; el Mesías Jesucristo; el Mesías", "Jesucristo; el Mesías", "Jesucristo; es Jehová Jesucristo; es Jehová", "Jesucristo; es Jehová", "Jesucristo; familia terrenal de Jesucristo; familia terrenal de", "Jesucristo; familia terrenal de", "Jesucristo; Hijo de Dios Jesucristo; Hijo de Dios", "Jesucristo; Hijo de Dios", "Jesucristo; Hijo del Hombre Jesucristo; Hijo del Hombre", "Jesucristo; Hijo del Hombre", "Jesucristo; Juez Jesucristo; Juez", "Jesucristo; Juez", "Jesucristo; la Roca", "Jesucristo; Maestro Jesucristo; Maestro", "Jesucristo; Maestro", "Jesucristo; misión de Jesucristo; misión de", "Jesucristo; misión de", "Jesucristo; preordenación de", "Jesucristo; Principio y Fin", "Jesucristo; Rey de los judíos Jesucristo; Rey de los judíos", "Jesucristo; Rey de los judíos", "José Smith José Smith", "José Smith", "José Smith; padre José Smith; padre", "José Smith; padre", "José; el soñador", "Juan el Amado Juan el Amado", "Juan el Amado", "Juan el Bautista Juan el Bautista", "Juan el Bautista", "Judíos", "Juicio de Dios Juicio de Dios", "Juicio de Dios", "Juicio final Juicio final", "Juicio final", "Juicio parcial", "Juramentos Juramentos", "Juramentos", "Justicia Justicia", "Justicia", "Justificación Justificación", "Justificación", "Labán (pariente de Lehi)", "Lamanitas Lamanitas", "Lamanitas", "Lamán Lamán", "Lamán", "Lehi Lehi", "Lehi", "Ley de castidad Ley de castidad", "Ley de castidad", "Ley de Cristo Ley de Cristo", "Ley de Cristo", "Ley de los testigos Ley de los testigos", "Ley de los testigos", "Ley de Moisés Ley de Moisés", "Ley de Moisés", "Liahona Liahona", "Liahona", "Libro de Abraham", "Libro de la Vida Libro de la Vida", "Libro de la Vida", "Libro de Lehi", "Libro de Mormón Libro de Mormón", "Libro de Mormón", "Libros de genealogía", "Liderazgo Liderazgo", "Liderazgo", "Llamamientos Llamamientos", "Llamamientos", "Llaves Llaves", "Llaves", "Lorenzo Snow", "Madres Madres", "Madres", "Maestros (Docentes) Maestros (Docentes)", "Maestros (Docentes)", "Mansedumbre Mansedumbre", "Mansedumbre", "Manual de la Iglesia", "María Magdalena", "María; madre del Señor María; madre del Señor", "María; madre del Señor", "Materialismo Materialismo", "Materialismo", "Matrimonio celestial Matrimonio celestial", "Matrimonio celestial", "Matrimonio Matrimonio", "Matrimonio plural", "Matrimonio", "Milagros Milagros", "Milagros", "Milenio Milenio", "Milenio", "Misericordia", "Misión de tiempo completo Misión de tiempo completo", "Misión de tiempo completo", "Misterios de Dios Misterios de Dios", "Misterios de Dios", "Modestia en el vestir", "Moisés Moisés", "Moisés", "Monte de los Olivos", "Muerte espiritual Muerte espiritual", "Muerte espiritual", "Muerte Muerte", "Muerte", "Mujeres Mujeres", "Mujeres", "Mundo de los espíritus Mundo de los espíritus", "Mundo de los espíritus", "Mundos Mundos", "Mundos", "Música Música", "Música", "Nauvoo", "Navidad", "Nefi Nefi", "Nefi", "Negligencia", "Neutralidad política", "Niños pequeños Niños pequeños", "Niños pequeños", "Nombre de Jesucristo Nombre de Jesucristo", "Nombre de Jesucristo", "Nombre nuevo Nombre nuevo", "Nombre nuevo", "Noviazgo Noviazgo", "Noviazgo", "Nueva Jerusalén", "Nuevo nacimiento", "Obediencia civil", "Obediencia Obediencia", "Obediencia", "Obispos Obispos", "Obispos", "Obra misional Obra misional", "Obra misional", "Obra vicaria Obra vicaria", "Obra vicaria", "Obras Obras", "Obras", "Olaha Shinehah", "Oposición Oposición", "Oposición", "Oración Oración", "Oración", "Orden patriarcal Orden patriarcal", "Orden patriarcal", "Ordenación Ordenación", "Ordenación", "Paciencia", "Palabra profética más segura Palabra profética más segura", "Palabra profética más segura", "Pangea Pangea", "Pangea", "Parley P. Pratt", "Parábola de la fiesta de bodas del hijo del rey", "Parábola de la higuera", "Parábola de la levadura", "Parábola de la perla de gran precio", "Parábola de la red", "Parábola de la semilla que crece", "Parábola de las diez vírgenes Parábola de las diez vírgenes", "Parábola de las diez vírgenes", "Parábola de las ovejas y los cabritos", "Parábola de los dos hijos", "Parábola de los labradores malvados Parábola de los labradores malvados", "Parábola de los labradores malvados", "Parábola de los obreros de la viña", "Parábola de los talentos", "Parábola del grano de mostaza", "Parábola del rico y Lázaro", "Parábola del sembrador", "Parábola del tesoro escondido", "Parábola del trigo y la cizaña Parábola del trigo y la cizaña", "Parábola del trigo y la cizaña", "Parábolas", "Pascua Pascua", "Pascua", "Pastores", "Paternidad Paternidad", "Paternidad", "Patriarca (primeros Padres) Patriarca (primeros Padres)", "Patriarca (primeros Padres)", "Pecado imperdonable", "Pecado", "Pedro Pedro", "Pedro", "Pena de muerte Pena de muerte", "Pena de muerte", "Perdición Perdición", "Perdición", "Perdón al prójimo Perdón al prójimo", "Perdón al prójimo", "Perdón de los pecados Perdón de los pecados", "Perdón de los pecados", "Persecución", "Perseverancia", "Planchas de bronce Planchas de bronce", "Planchas de bronce", "Planeación Planeación", "Planeación", "Poder sellador Poder sellador", "Poder sellador", "Poncio Pilato", "Pornografía", "Predicación del evangelio Predicación del evangelio", "Predicación del evangelio", "Preguntas (técnica didáctica) Preguntas (técnica didáctica)", "Preguntas (técnica didáctica)", "Preordenación Preordenación", "Preordenación", "Preparación Preparación", "Preparación", "Primera resurrección Primera resurrección", "Primera resurrección", "Principios", "Probación (pruebas) Probación (pruebas)", "Probación (pruebas)", "Profecías mesiánicas", "Profecías Profecías", "Profecías", "Profetas Profetas", "Profetas", "Progenie espiritual", "Protección", "Pruebas", "Quiasmo Quiasmo", "Quiasmo", "Racionalismo Racionalismo", "Racionalismo", "Rascismo Rascismo", "Rascismo", "Razas", "Recogimiento Recogimiento", "Recogimiento", "Reino Celestial Reino Celestial", "Reino Celestial", "Reino de Dios Reino de Dios", "Reino de Dios", "Reino Telestial", "Reino Terrestre", "Reinos de gloria", "Relativismo", "Restauración Restauración", "Restauración", "Resurrección Resurrección", "Resurrección", "Retención", "Revelación Revelación", "Revelación", "Riquezas", "Ropas blancas Ropas blancas", "Ropas blancas", "Sacerdocio Aarónico Sacerdocio Aarónico", "Sacerdocio Aarónico", "Sacerdocio Sacerdocio", "Sacerdocio", "Sacrificio Sacrificio", "Sacrificio", "Salud", "Sanidad Sanidad", "Sanidad", "Santa Cena Santa Cena", "Santa Cena", "Santificación", "Santos Santos", "Santos", "Satanás Satanás", "Satanás", "Secret Combination", "Secreto mesiánico Secreto mesiánico", "Secreto mesiánico", "Segunda Venida Segunda Venida", "Segunda Venida", "Seminario", "Servicio", "Setentas Setentas", "Setentas", "Simbolismo del templo Simbolismo del templo", "Simbolismo del templo", "Simbolismo Simbolismo", "Simbolismo", "Sión Sión", "Sión", "Suercherías sacerdotales", "Sumo Sacerdocio Sumo Sacerdocio", "Sumo Sacerdocio", "Tecnología", "Templos Templos", "Templos", "Tentación", "Testimonio Testimonio", "Testimonio", "Tiempo Tiempo", "Tiempo", "Trabajo Trabajo", "Trabajo", "Transtornos emocionales", "Tres testigos", "Trinidad Trinidad", "Trinidad", "Tropiezos", "Unción (consagración)", "Unidad Unidad", "Unidad", "Valor Valor", "Valor", "Vida eterna", "Vida preterrenal Vida preterrenal", "Vida preterrenal", "Visiones Visiones", "Visiones", "Vocación y Elección", "Zenoc", "Zenós", "Ética Ética", "Ética"]
        
        XCTAssertNotEqual(tagNames.count, expected.count)
        
        let actual = annotationStore.tags().map { $0.name }
        XCTAssertNotEqual(tagNames.count, expected.count)
        XCTAssertEqual(actual.count, expected.count)
    }
    
}

extension String {
    
    subscript (i: Int) -> Character {
        return self[self.characters.index(self.startIndex, offsetBy: i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        let start = characters.index(startIndex, offsetBy: r.lowerBound)
        let end = characters.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        return self[Range(start ..< end)]
    }
    
    
}
