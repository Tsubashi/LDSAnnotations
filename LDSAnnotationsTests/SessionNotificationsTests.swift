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

class SessionNotificationsTests: XCTestCase {

    func testInitialStatus() {
        let session = createSession()
        XCTAssertEqual(session.status, Session.Status.Unauthenticated)
    }
    
    func testAuthSuccessNotifications() {
        let expectation = expectationWithDescription("Successfully signed in")
        let session = createSession()
        
        var statuses: [Session.Status] = []
        let observer = session.statusObservers.add { status in
            statuses.append(status)
        }
        
        session.authenticate { error in
            XCTAssertNil(error)
            
            XCTAssertEqual(session.status, Session.Status.AuthenticationSuccessful)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
        
        XCTAssertEqual(statuses, [Session.Status.AuthenticationInProgress, Session.Status.AuthenticationSuccessful])
        
        session.statusObservers.remove(observer)
    }
    
    func testAuthFailedNotifications() {
        let expectation = expectationWithDescription("Failed to sign in")
        let session = createSession(useIncorrectPassword: true)

        var statuses: [Session.Status] = []
        let observer = session.statusObservers.add { status in
            statuses.append(status)
        }
        
        session.authenticate { error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error!.domain, Error.Domain)
            XCTAssertEqual(error!.code, Error.Code.AuthenticationFailed.rawValue)

            XCTAssertEqual(session.status, Session.Status.AuthenticationFailed)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)

        XCTAssertEqual(statuses, [Session.Status.AuthenticationInProgress, Session.Status.AuthenticationFailed])
        
        session.statusObservers.remove(observer)
    }
    
    func testSyncSuccessfulNotifications() {
        let annotationStore = AnnotationStore()!
        let session = createSession()
        var token: SyncToken?

        var statuses: [Session.Status] = []
        let observer = session.statusObservers.add { status in
            statuses.append(status)
        }
        
        sync(annotationStore, session: session, token: &token, description: "Initial sync") { _, _ in
            XCTAssertEqual(statuses, [Session.Status.SyncInProgress, Session.Status.SyncSuccessful])
        }
        
        // Clear statuses
        statuses.removeAll()
        
        // Add a notebook
        let notebook = try! annotationStore.addNotebook(name: "Test Notebook", source: .Local)
        sync(annotationStore, session: session, token: &token, description: "Sync new folder") { uploadCount, downloadCount in
            XCTAssertEqual(statuses, [Session.Status.SyncInProgress, Session.Status.SyncSuccessful])
        }

        // Clear statuses
        statuses.removeAll()
        
        // Update the notebook
        var modifiedNotebook = notebook
        modifiedNotebook.name = "Renamed"
        try! annotationStore.updateNotebook(modifiedNotebook, source: .Local)
        
        sync(annotationStore, session: session, token: &token, description: "Sync updated folder") { uploadCount, downloadCount in
            XCTAssertEqual(statuses, [Session.Status.SyncInProgress, Session.Status.SyncSuccessful])
        }

        session.statusObservers.remove(observer)
    }
    
    func testSyncFailedNotifications() {
        let annotationStore = AnnotationStore()!
        let session = createSession(useIncorrectPassword: true)
        var token: SyncToken?
        
        var statuses: [Session.Status] = []
        let observer = session.statusObservers.add { status in
            statuses.append(status)
        }

        sync(annotationStore, session: session, token: &token, description: "Initial sync", allowSyncFailure: true) { _, _ in
            XCTAssertEqual(statuses, [Session.Status.SyncInProgress, Session.Status.SyncFailed])
        }
        
        session.statusObservers.remove(observer)
    }
    
}
