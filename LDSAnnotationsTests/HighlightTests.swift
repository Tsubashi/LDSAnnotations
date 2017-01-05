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
import Swiftification

class HighlightTests: XCTestCase {
    
    static let emptyNotebooksResult = SyncNotebooksResult(localSyncNotebooksDate: Date(), serverSyncNotebooksDate: Date(), changes: SyncNotebooksChanges(notebookAnnotationIDs: [:], uploadedNotebooks: [], downloadedNotebooks: []), deserializationErrors: [])
    
    func testHighlightMissingPID() {
        let highlight = [
            "@offset-start": "3",
            "@offset-end": "7",
            "@color": "yellow",
            ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = .ready(HighlightTests.emptyNotebooksResult)
        
        do {
            try annotationStore.inTransaction(notificationSource: .sync) {
                try operation.applyServerChanges(self.payloadForHighlight(highlight), onOrBefore: Date())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertTrue(annotationStore.highlightsWithAnnotationID(1).isEmpty)
    }
    
    func testHighlightMissingOffset() {
        let highlight = [
            "@offset-end": "7",
            "@color": "yellow",
            "@pid": "20527924",
            ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = .ready(HighlightTests.emptyNotebooksResult)
        
        do {
            try annotationStore.inTransaction(notificationSource: .sync) {
                try operation.applyServerChanges(self.payloadForHighlight(highlight), onOrBefore: Date())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertTrue(annotationStore.highlightsWithAnnotationID(1).isEmpty)
    }
    
    func testHighlightWithOffset() {
        let highlight = [
            "@offset-start": "2",
            "@offset-end": "6",
            "@pid": "20527924",
            "@color": "yellow",
            ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = .ready(HighlightTests.emptyNotebooksResult)
        
        do {
            try annotationStore.inTransaction(notificationSource: .sync) {
                try operation.applyServerChanges(self.payloadForHighlight(highlight), onOrBefore: Date())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertFalse(annotationStore.highlightsWithAnnotationID(1).isEmpty)
        
        let expected = Highlight(id: 1, paragraphRange: ParagraphRange(paragraphAID: "20527924", startWordOffset: 2, endWordOffset: 6), colorName: "yellow", style: .highlight, annotationID: 1)
        let actual = annotationStore.highlightsWithAnnotationID(1).first
        
        XCTAssertEqual(actual, expected)
    }
    
    func testHighlightWithSentinelOffset() {
        let highlight = [
            "@offset-start": "-1",
            "@offset-end": "-1",
            "@pid": "20527924",
            "@color": "yellow",
            ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = .ready(HighlightTests.emptyNotebooksResult)
        
        do {
            try annotationStore.inTransaction(notificationSource: .sync) {
                try operation.applyServerChanges(self.payloadForHighlight(highlight), onOrBefore: Date())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertFalse(annotationStore.highlightsWithAnnotationID(1).isEmpty)
        
        let expected = Highlight(id: 1, paragraphRange: ParagraphRange(paragraphAID: "20527924"), colorName: "yellow", style: .highlight, annotationID: 1)
        let actual = annotationStore.highlightsWithAnnotationID(1).first
        
        XCTAssertEqual(actual, expected)
    }
    
    func payloadForHighlight(_ highlight: [String: Any]) -> [String: Any] {
        let uniqueID = UUID().uuidString
        let annotation: [String: Any] = [
            "changeType": "new",
            "timestamp" : "2016-08-04T11:21:38.849-06:00",
            "annotationId" : uniqueID,
            "annotation": [
                "source": "Test",
                "@type": "highlight",
                "@docId": "20056057",
                "device": "iphone",
                "@status": "",
                "timestamp": "2016-08-04T11:26:09.440-06:00",
                "@id": uniqueID,
                "highlights": ["highlight": [highlight]]
            ]
        ]
        return ["syncAnnotations": ["count": 1, "changes": [annotation]]]
    }
    
}
