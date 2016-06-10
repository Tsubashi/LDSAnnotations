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
    
}
