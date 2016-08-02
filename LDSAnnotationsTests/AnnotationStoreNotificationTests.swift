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

class AnnotationStoreNotificationTests: XCTestCase {
    
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
    
    func testAddAndUpdateAnnotation() {
        let annotationStore = AnnotationStore()!
        
        let addExpectation = expectationWithDescription("Annotation added")
        let addObserver = annotationStore.annotationObservers.add { source, annotations in
            if source == .Local && annotations.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        let annotation = try! annotationStore.addAnnotation(iso639_3Code: "eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        annotationStore.annotationObservers.remove(addObserver)
        
        let updateExpectation = expectationWithDescription("Annotation updated")
        let updateObserver = annotationStore.annotationObservers.add { source, notebooks in
            if source == .Local && notebooks.count == 1 {
                updateExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        try! annotationStore.updateAnnotation(annotation)
        annotationStore.annotationObservers.remove(updateObserver)
        
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testAddAndUpdateAnnotationInTransactions() {
        let annotationStore = AnnotationStore()!
        
        let addExpectation = expectationWithDescription("Annotation added")
        let addObserver = annotationStore.annotationObservers.add { source, annotations in
            if source == .Local && annotations.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        try! annotationStore.inTransaction {
            try! annotationStore.addAnnotation(iso639_3Code: "eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
        }
        annotationStore.annotationObservers.remove(addObserver)
        
        let updateExpectation = expectationWithDescription("Annotation updated")
        let updateObserver = annotationStore.annotationObservers.add { source, notebooks in
            if source == .Local && notebooks.count == 1 {
                updateExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        try! annotationStore.inTransaction {
            let annotation = annotationStore.annotationWithID(1)!
            try! annotationStore.updateAnnotation(annotation)
        }
        annotationStore.annotationObservers.remove(updateObserver)
        
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testAddAndUpdateAnnotationInOneTransaction() {
        let annotationStore = AnnotationStore()!
        
        let expectation = self.expectationWithDescription("Annotation added")
        let observer = annotationStore.annotationObservers.add { source, annotations in
            if source == .Local && annotations.count == 1 {
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }
        
        try! annotationStore.inTransaction {
            let annotation = try! annotationStore.addAnnotation(iso639_3Code: "eng", docID: "1", docVersion: 1, type: .Highlight, source: "Test", device: "iphone")
            try! annotationStore.updateAnnotation(annotation)
        }
        
        annotationStore.annotationObservers.remove(observer)
        
        waitForExpectationsWithTimeout(2, handler: nil)
    }
}
