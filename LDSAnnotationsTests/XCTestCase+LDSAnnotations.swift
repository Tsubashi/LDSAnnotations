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

extension XCTestCase {

    func createSession(useIncorrectPassword: Bool = false) -> Session {
        guard let username = UserDefaults.standard.string(forKey: "TestAccountUsername") else {
            XCTFail("Missing TestAccountUsername")
            fatalError()
        }
        guard let password = UserDefaults.standard.string(forKey: "TestAccountPassword") else {
            XCTFail("Missing TestAccountPassword")
            fatalError()
        }
        guard let clientUsername = UserDefaults.standard.string(forKey: "ClientUsername") else {
            XCTFail("Missing ClientUsername")
            fatalError()
        }
        guard let clientPassword = UserDefaults.standard.string(forKey: "ClientPassword") else {
            XCTFail("Missing ClientPassword")
            fatalError()
        }
        
        let userAgent = "LDSAnnotations unit tests"
        let clientVersion = "1"
        
        return Session(username: username, password: useIncorrectPassword ? "wrong-\(password)" : password, userAgent: userAgent, clientVersion: clientVersion, clientUsername: clientUsername, clientPassword: clientPassword)
    }
    
    func sync(_ annotationStore: AnnotationStore, session: Session, token: SyncToken?, description: String, allowSyncFailure: Bool = false, completion: ((_ uploadCount: Int, _ downloadCount: Int) -> Void)? = nil) -> SyncToken? {
        let semaphore = DispatchSemaphore(value: 0)
        var updatedToken: SyncToken?
        session.sync(annotationStore: annotationStore, token: token) { syncResult in
            switch syncResult {
            case let .success(token: newToken, changes: changes, deserializationErrors: _):
                updatedToken = newToken
                completion?(changes.uploadedNotebooks.count + changes.uploadAnnotationCount, changes.downloadedNotebooks.count + changes.downloadAnnotationCount)
            case let .error(errors: errors):
                if allowSyncFailure {
                    completion?(0, 0)
                } else {
                    XCTFail("Failed with errors \(errors)")
                }
            }
            /* 
             The service takes a little while after we send annotations to run through some db triggers, and transformations, so add a delay after each sync to make sure it has processed everything we've sent and is able to return to us all the user's annotations.
            */
            semaphore.signal()
        }
        semaphore.wait(timeout: DispatchTime.now() + Double(Int64(300 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC))
        
        return updatedToken
    }
    
    func resetAnnotations(annotationStore: AnnotationStore, session: Session, token: SyncToken?) -> SyncToken? {
        var currentToken = token
        currentToken = sync(annotationStore, session: session, token: currentToken, description: "Initial sync") { uploadCount, downloadCount in
            XCTAssertEqual(uploadCount, 0, "There were existing local annotations")
            
            let count = annotationStore.annotationCount() + annotationStore.trashedAnnotationCount() + annotationStore.notebookCount() + annotationStore.trashedNotebookCount()
            XCTAssertEqual(downloadCount, count, "Not all downloaded annotations were saved locally")
        }
        
        // Do we have any active annotations?
        let deleteCount = annotationStore.annotationCount() + annotationStore.notebookCount()
        if deleteCount > 0 {
            for notebook in annotationStore.notebooks() {
                try! annotationStore.trashNotebookWithID(notebook.id, source: .local)
            }
            for annotation in annotationStore.annotations() {
                try! annotationStore.trashAnnotationWithID(annotation.id, source: .local)
            }
            
            currentToken = sync(annotationStore, session: session, token: currentToken, description: "Sync deleted annotations") { uploadCount, downloadCount in
                XCTAssertEqual(uploadCount, deleteCount, "Not all local annotations were deleted")
                XCTAssertEqual(downloadCount, 0)
            }
            
            try! annotationStore.deleteNotebooks(annotationStore.trashedNotebooks(), source: .local)
            try! annotationStore.deleteAnnotations(annotationStore.trashedAnnotations(), source: .local)
            
            let count = annotationStore.annotationCount() + annotationStore.notebookCount()
            XCTAssertEqual(count, 0)
        }
        
        return currentToken
    }
    
}
