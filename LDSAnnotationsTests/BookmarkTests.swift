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

class BookmarkTests: XCTestCase {
    
    static let emptyNotebooksResult = SyncNotebooksResult(localSyncNotebooksDate: NSDate(), serverSyncNotebooksDate: NSDate(), changes: SyncNotebooksChanges(notebookAnnotationIDs: [:], uploadedNotebooks: [], downloadedNotebooks: []), deserializationErrors: [])
    
    func testBookmarkMissingPID() {
        let bookmark = [
            "name": "BookmarkName",
            "sort": "1",
            "uri": "/scriptures/bofm/1-ne/1"
        ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = BookmarkTests.emptyNotebooksResult
        
        do {
            try annotationStore.inTransaction(.Sync) {
                try operation.applyServerChanges(self.payloadForBookmark(bookmark), onOrBefore: NSDate())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertTrue(annotationStore.bookmarks().isEmpty)
    }
    
    func testBookmarkWithOffset() {
        let bookmark = [
            "name": "BookmarkName",
            "@pid": "20527924",
            "sort": 1,
            "@offset": "2"
        ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = BookmarkTests.emptyNotebooksResult
        
        do {
            try annotationStore.inTransaction(.Sync) {
                try operation.applyServerChanges(self.payloadForBookmark(bookmark), onOrBefore: NSDate())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        let expected = Bookmark(id: 1, name: "BookmarkName", paragraphAID: "20527924", displayOrder: 1, annotationID: 1, offset: 2)
        let actual = annotationStore.bookmarks().first
        
        XCTAssertEqual(actual, expected)
    }
    
    func testBookmarkWithSentinelOffset() {
        let bookmark = [
            "name": "BookmarkName",
            "@pid": "20527924",
            "sort": 1,
            "@offset": "-1"
        ]
        
        let annotationStore = AnnotationStore()!
        let session = createSession()
        let operation = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: nil, serverSyncAnnotationsDate: nil) { _ in }
        operation.requirement = BookmarkTests.emptyNotebooksResult
        
        do {
            try annotationStore.inTransaction(.Sync) {
                try operation.applyServerChanges(self.payloadForBookmark(bookmark), onOrBefore: NSDate())
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let expected = Bookmark(id: 1, name: "BookmarkName", paragraphAID: "20527924", displayOrder: 1, annotationID: 1, offset: -1)
        let actual = annotationStore.bookmarks().first
        XCTAssertEqual(actual, expected)
    }

    func payloadForBookmark(bookmark: [String: AnyObject]) -> [String: AnyObject] {
        let uniqueID = NSUUID().UUIDString
        let annotation = [
            "changeType": "new",
            "timestamp" : "2016-08-04T11:21:38.849-06:00",
            "annotationId" : uniqueID,
            "annotation": [
                "source": "Test",
                "@type": "bookmark",
                "@docId": "20056057",
                "device": "iphone",
                "@status": "",
                "timestamp": "2016-08-04T11:26:09.440-06:00",
                "@id": uniqueID,
                "bookmark": bookmark
            ]
        ]
        let annotations = [annotation]
        return ["syncAnnotations": ["count": annotations.count, "changes": annotations]]
    }
    
}
