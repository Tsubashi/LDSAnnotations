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
import LDSAnnotations

class SyncNotebooksTests: XCTestCase {
    
    func testAddAndUpdateNotebook() {
        let annotationStore = AnnotationStore()!
        let session = createSession()
        var token: SyncToken?
        resetNotebooks(annotationStore: annotationStore, session: session, token: &token)
        
        // Add a notebook
        let notebook = try! annotationStore.addNotebook(name: "Test Notebook")
        
        sync(annotationStore, session: session, token: &token, description: "Sync new folder") { uploadCount, downloadCount in
            XCTAssertEqual(uploadCount, 1)
            XCTAssertEqual(downloadCount, 0)
        }
        
        // Update the notebook
        var modifiedNotebook = notebook
        modifiedNotebook.name = "Renamed"
        try! annotationStore.updateNotebook(modifiedNotebook)
        
        sync(annotationStore, session: session, token: &token, description: "Sync updated folder") { uploadCount, downloadCount in
            XCTAssertEqual(uploadCount, 1)
            XCTAssertEqual(downloadCount, 0)
        }
    }
    
    func testUploadAndDownloadNotebook() {
        let annotationStore1 = AnnotationStore()!
        let session1 = createSession()
        var token1: SyncToken?
        resetNotebooks(annotationStore: annotationStore1, session: session1, token: &token1)
        
        let annotationStore2 = AnnotationStore()!
        let session2 = createSession()
        var token2: SyncToken?
        resetNotebooks(annotationStore: annotationStore2, session: session2, token: &token2)
        
        // Add a notebook to one annotation store
        let notebook = try! annotationStore1.addNotebook(name: "Test Notebook")
        
        // Upload the changes
        sync(annotationStore1, session: session1, token: &token1, description: "Sync new folder") { uploadCount, downloadCount in
            XCTAssertEqual(uploadCount, 1)
            XCTAssertEqual(downloadCount, 0)
        }
        
        // Download the changes to another annotation store
        sync(annotationStore2, session: session2, token: &token2, description: "Sync updated folder") { uploadCount, downloadCount in
            XCTAssertEqual(uploadCount, 0)
            XCTAssertEqual(downloadCount, 1)
        }
        
        // Verify the changes
        let notebooks = annotationStore2.notebooks()
        XCTAssertEqual(notebooks.count, 1)
        XCTAssertEqual(notebooks.first!.name, notebook.name)
    }
    
    func resetNotebooks(annotationStore annotationStore: AnnotationStore, session: Session, inout token: SyncToken?) {
        sync(annotationStore, session: session, token: &token, description: "Initial sync") { uploadCount, downloadCount in
            XCTAssertEqual(uploadCount, 0, "There were existing local notebooks")
            
            let notebookCount = annotationStore.notebookCount() + annotationStore.trashedNotebookCount()
            XCTAssertEqual(downloadCount, notebookCount, "Not all downloaded notebooks were saved locally")
        }
        
        let deleteCount = annotationStore.notebookCount() + annotationStore.trashedNotebookCount()
        if deleteCount > 0 {
            try! annotationStore.inTransaction {
                // Trash all active notebooks
                let notebooks = annotationStore.notebooks()
                try annotationStore.trashNotebooks(notebooks)
                
                // Delete all trashed notebooks
                let trashedNotebooks = annotationStore.trashedNotebooks()
                try annotationStore.deleteNotebooks(trashedNotebooks)
            }
            
            sync(annotationStore, session: session, token: &token, description: "Sync deleted notebooks") { uploadCount, downloadCount in
                XCTAssertEqual(uploadCount, deleteCount, "Not all local notebooks were deleted")
                XCTAssertEqual(downloadCount, 0)
            }
            
            XCTAssertEqual(annotationStore.notebookCount() + annotationStore.trashedNotebookCount(), 0)
        }
    }
    
}
