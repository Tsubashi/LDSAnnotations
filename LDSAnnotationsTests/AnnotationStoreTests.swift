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
    
    func testTagsOrderedByName() {
        let annotationStore = AnnotationStore(path: "")!
        
        var tags = [Tag]()
        var annotations = [Annotation]()
        var date = NSDate()
        
        for i in 0..<alphabet.count {
            for j in i..<alphabet.count {
                let tag = try! annotationStore.addOrUpdateTag(Tag(id: nil, name: alphabet[i]))!
                tags.append(tag)
                
                let annotation = annotationStore.addOrUpdateAnnotation(Annotation(id: nil, uniqueID: "\(i)_\(j)", iso639_3Code: "eng", docID: alphabet[i], docVersion: 1, type: .Journal, status: .Active, created: nil, lastModified: date, noteID: nil, bookmarkID: nil, source: nil, device: nil))!
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
        print(actualMostRecent)
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
            let annotation = Annotation(id: nil, uniqueID: "\(i)", iso639_3Code: "eng", docID: alphabet[i], docVersion: 1, type: .Journal, status: .Active, created: nil, lastModified: NSDate(), noteID: nil, bookmarkID: nil, source: nil, device: nil)
            annotations.append(annotationStore.addOrUpdateAnnotation(annotation)!)
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
