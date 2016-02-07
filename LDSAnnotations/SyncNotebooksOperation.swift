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

import Foundation
import PSOperations

class SyncNotebooksOperation: Operation {
    
    let session: Session
    let annotationStore: AnnotationStore
    let token: SyncToken?
    
    var localSyncDate: NSDate?
    var serverSyncDate: NSDate?
    var uploadCount: Int?
    var downloadCount: Int?
    
    init(session: Session, annotationStore: AnnotationStore, token: SyncToken?, completion: (SyncNotebooksResult) -> Void) {
        self.session = session
        self.annotationStore = annotationStore
        self.token = token
        
        super.init()
        
        addCondition(AuthenticateCondition(session: session))
        addObserver(BlockObserver(startHandler: nil, produceHandler: nil, finishHandler: { operation, errors in
            if errors.isEmpty, let localSyncDate = self.localSyncDate, serverSyncDate = self.serverSyncDate, uploadCount = self.uploadCount, downloadCount = self.downloadCount {
                completion(.Success(token: SyncToken(localSyncDate: localSyncDate, serverSyncDate: serverSyncDate), uploadCount: uploadCount, downloadCount: downloadCount))
            } else {
                completion(.Error(errors: errors))
            }
        }))
    }
    
    override func execute() {
        let localSyncDate = NSDate()
        let localChanges = localChangesAfter(token?.localSyncDate, onOrBefore: localSyncDate)
        
        self.localSyncDate = localSyncDate
        
        var syncFolders: [String: AnyObject] = [
            "since": (token?.serverSyncDate ?? NSDate(timeIntervalSince1970: 0)).formattedISO8601,
            "clientTime": NSDate().formattedISO8601,
            "changes": localChanges,
        ]
        if token?.serverSyncDate == nil {
            // TODO: have another syncStatus option defined that includes active and trashed folders
            syncFolders["syncStatus"] = "normal"
        }
        let payload = [
            "syncFolders": syncFolders
        ]
        
        session.put("/ws/annotation/v1.4/Services/rest/sync/folders?xver=2", payload: payload) { response in
            switch response {
            case .Success(let payload):
                do {
                    try self.annotationStore.inSyncTransaction {
                        self.annotationStore.deletedNotebooks(lastModifiedOnOrBefore: localSyncDate)
                        try self.applyServerChanges(payload)
                    }
                    self.finish()
                } catch let error as NSError {
                    self.finishWithError(error)
                }
            case .Failure(let payload):
                self.finishWithError(Error.errorWithCode(.Unknown, failureReason: "Failure response: \(payload)"))
            case .Error(let error):
                self.finishWithError(error)
            }
        }
    }
    
    func localChangesAfter(after: NSDate?, onOrBefore: NSDate) -> [[String: AnyObject]] {
        let modifiedNotebooks = annotationStore.allNotebooks(lastModifiedAfter: after, lastModifiedOnOrBefore: onOrBefore)
        
        uploadCount = modifiedNotebooks.count
        
        return modifiedNotebooks.map { (notebook: Notebook) -> [String: AnyObject] in
            var result: [String: AnyObject] = [
                "changeType": ChangeType(status: notebook.status).rawValue,
                "folderId": notebook.uniqueID,
                "timestamp": notebook.lastModified.formattedISO8601,
            ]
            
            if notebook.status != .Deleted {
                result["folder"] = notebook.jsonObject()
            }
            
            return result
        }
    }
    
    func applyServerChanges(payload: [String: AnyObject]) throws {
        guard let syncFolders = payload["syncFolders"] as? [String: AnyObject] else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing syncFolders")
        }
        
        guard let rawServerSyncDate = syncFolders["before"] as? String, serverSyncDate = NSDate.parseFormattedISO8601(rawServerSyncDate) else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing before")
        }
        
        self.serverSyncDate = serverSyncDate
        
        if let remoteChanges = syncFolders["changes"] as? [[String: AnyObject]] {
            var downloadCount = 0
            
            for change in remoteChanges {
                guard let rawChangeType = change["changeType"] as? String, changeType = ChangeType(rawValue: rawChangeType) else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Missing changeType")
                }
                
                guard let uniqueID = change["folderId"] as? String else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Missing folderId")
                }
                
                guard let folder = change["folder"] as? [String: AnyObject], downloadedNotebook = Notebook(jsonObject: folder) else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Failed to deserialize folder")
                }
                
                // TODO: handle "order"
                
                switch changeType {
                case .New, .Trash:
                    downloadCount += 1
                    
                    if let existingNotebook = annotationStore.notebookWithUniqueID(uniqueID) {
                        var mergedNotebook = downloadedNotebook
                        mergedNotebook.id = existingNotebook.id
                        annotationStore.addOrUpdateNotebook(mergedNotebook)
                    } else {
                        annotationStore.addOrUpdateNotebook(downloadedNotebook)
                    }
                case .Delete:
                    if let existingNotebook = annotationStore.notebookWithUniqueID(uniqueID), existingNotebookID = existingNotebook.id {
                        annotationStore.deleteNotebookWithID(existingNotebookID)
                    } else {
                        // If the notebook doesn't exist there's no need to delete it
                    }
                }
            }
            
            self.downloadCount = downloadCount
        } else {
            downloadCount = 0
        }
    }
    
}
