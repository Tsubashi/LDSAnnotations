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
        
        let addExpectation = expectation(description: "Notebook added")
        let addObserver = annotationStore.notebookObservers.add { source, notebooks in
            if source == .local && notebooks.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        var notebook = try! annotationStore.addNotebook(name: "Test Notebook", source: .local)
        annotationStore.notebookObservers.remove(addObserver)
        
        let updateExpectation = expectation(description: "Notebook updated")
        let updateObserver = annotationStore.notebookObservers.add { source, notebooks in
            if source == .local && notebooks.count == 1 {
                updateExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        notebook.name = "Renamed Notebook"
        try! annotationStore.updateNotebook(notebook)
        annotationStore.notebookObservers.remove(updateObserver)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testAddAndUpdateAnnotation() {
        let annotationStore = AnnotationStore()!
        
        let addExpectation = expectation(description: "Annotation added")
        let addObserver = annotationStore.annotationObservers.add { source, annotations in
            if source == .local && annotations.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        annotationStore.annotationObservers.remove(addObserver)
        
        let updateExpectation = expectation(description: "Annotation updated")
        let updateObserver = annotationStore.annotationObservers.add { source, notebooks in
            if source == .local && notebooks.count == 1 {
                updateExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        try! annotationStore.updateAnnotation(annotation, source: .local)
        annotationStore.annotationObservers.remove(updateObserver)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testAddAndUpdateAnnotationInTransactions() {
        let annotationStore = AnnotationStore()!
        
        let addExpectation = expectation(description: "Annotation added")
        let addObserver = annotationStore.annotationObservers.add { source, annotations in
            if source == .local && annotations.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        try! annotationStore.inTransaction(notificationSource: .local) {
            try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        }
        annotationStore.annotationObservers.remove(addObserver)
        
        let updateExpectation = expectation(description: "Annotation updated")
        let updateObserver = annotationStore.annotationObservers.add { source, notebooks in
            if source == .local && notebooks.count == 1 {
                updateExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        try! annotationStore.inTransaction(notificationSource: .local) {
            let annotation = annotationStore.annotationWithID(1)!
            try! annotationStore.updateAnnotation(annotation, source: .local)
        }
        annotationStore.annotationObservers.remove(updateObserver)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testAddAndUpdateAnnotationInOneTransaction() {
        let annotationStore = AnnotationStore()!
        
        let expectation = self.expectation(description: "Annotation added")
        let observer = annotationStore.annotationObservers.add { source, annotations in
            if source == .local && annotations.count == 1 {
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }
        
        try! annotationStore.inTransaction(notificationSource: .local) {
            let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
            try! annotationStore.updateAnnotation(annotation, source: .local)
        }
        
        annotationStore.annotationObservers.remove(observer)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testAddAnnotationNotebookNotification() {
        let annotationStore = AnnotationStore()!

        let annotation = try! annotationStore.addAnnotation(docID: "13859831", docVersion: 1, appSource: "Test", device: "iphone", source: .local)
        let notebook = try! annotationStore.addNotebook(name: "Test Notebook", source: .local)

        let addExpectation = expectation(description: "Notebook added")
        let addObserver = annotationStore.notebookObservers.add { source, notebooks in
            if source == .local && notebooks.count == 1 {
                addExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        
        try! annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: notebook.id, displayOrder: 1)
        
        waitForExpectations(timeout: 2, handler: nil)
        
        annotationStore.notebookObservers.remove(addObserver)
    }
    
}
