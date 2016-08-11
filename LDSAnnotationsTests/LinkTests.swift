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

class LinkTests: XCTestCase {
    
    func testLinkMissingPID() {
        let link = [
            "$" : "name",
            "@docId" : "19158224",
            "@contentVersion" : "1",
        ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let syncAnnotationsOperation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, notebookAnnotationIDs: [:], localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        
        do {
            try syncAnnotationsOperation.applyServerChanges(payloadForLink(link), onOrBefore: NSDate())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertTrue(annotationStore.linksWithAnnotationID(1).isEmpty)
    }
    
    
    func testLink() {
        let link = [
            "$": "name",
            "@docId": "13859831",
            "@contentVersion": "1",
            "@pid": "20527924",
        ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let syncAnnotationsOperation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, notebookAnnotationIDs: [:], localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        
        do {
            try syncAnnotationsOperation.applyServerChanges(payloadForLink(link), onOrBefore: NSDate())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertFalse(annotationStore.linksWithAnnotationID(1).isEmpty)
        
        let expected = Link(id: 1, name: "name", docID: "13859831", docVersion: 1, paragraphAIDs: ["20527924"], annotationID: 1)
        let actual = annotationStore.linksWithAnnotationID(1).first
        
        XCTAssertEqual(actual, expected)
    }
    
    func payloadForLink(link: [String: AnyObject]) -> [String: AnyObject] {
        let uniqueID = NSUUID().UUIDString
        let annotation = [
            "changeType": "new",
            "timestamp" : "2016-08-04T11:21:38.849-06:00",
            "annotationId" : uniqueID,
            "annotation": [
                "source": "Test",
                "@type": "reference",
                "@docId": "20056057",
                "device": "iphone",
                "@status": "",
                "timestamp": "2016-08-04T11:26:09.440-06:00",
                "@id": uniqueID,
                "highlights": [
                    "highlight": [
                        [
                            "@color" : "yellow",
                            "@pid" : "19155093",
                            "@offset-start" : "3",
                            "@offset-end" : "3"
                        ]
                    ]
                ],
                "refs" : [
                    "ref" : [link]
                ]
            ]
        ]
        let annotations = [annotation]
        return ["syncAnnotations": ["count": annotations.count, "changes": annotations]]
    }
    
}