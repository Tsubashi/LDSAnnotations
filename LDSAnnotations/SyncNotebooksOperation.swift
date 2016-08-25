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
    let previousLocalSyncNotebooksDate: NSDate?
    let previousServerSyncNotebooksDate: NSDate?
    
    var localSyncNotebooksDate: NSDate?
    var serverSyncNotebooksDate: NSDate?
    
    var uploadedNotebooks = [Notebook]()
    var downloadedNotebooks = [Notebook]()
    
    var notebookAnnotationIDs = [String: [String]]()
    var deserializationErrors = [NSError]()
    
    private let source: NotificationSource = .Sync
    
    init(session: Session, annotationStore: AnnotationStore, localSyncNotebooksDate: NSDate?, serverSyncNotebooksDate: NSDate?, completion: (SyncNotebooksResult) -> Void) {
        self.session = session
        self.annotationStore = annotationStore
        self.previousLocalSyncNotebooksDate = localSyncNotebooksDate
        self.previousServerSyncNotebooksDate = serverSyncNotebooksDate
        
        super.init()
        
        addCondition(AuthenticateCondition(session: session))
        addObserver(BlockObserver(startHandler: nil, produceHandler: nil, finishHandler: { operation, errors in
            if errors.isEmpty, let localSyncNotebooksDate = self.localSyncNotebooksDate, serverSyncNotebooksDate = self.serverSyncNotebooksDate {
                let changes = SyncNotebooksChanges(notebookAnnotationIDs: self.notebookAnnotationIDs, uploadedNotebooks: self.uploadedNotebooks, downloadedNotebooks: self.downloadedNotebooks)
                completion(.Success(localSyncNotebooksDate: localSyncNotebooksDate, serverSyncNotebooksDate: serverSyncNotebooksDate, changes: changes, deserializationErrors: self.deserializationErrors))
            } else {
                completion(.Error(errors: errors))
            }
        }))
    }
    
    override func execute() {
        let localSyncDate = NSDate()
        let localChanges = localChangesAfter(previousLocalSyncNotebooksDate, onOrBefore: localSyncDate)
        
        self.localSyncNotebooksDate = localSyncDate
        
        var syncFolders: [String: AnyObject] = [
            "since": (previousServerSyncNotebooksDate ?? NSDate(timeIntervalSince1970: 0)).formattedISO8601,
            "clientTime": NSDate().formattedISO8601,
        ]
        
        if !localChanges.isEmpty {
            syncFolders["changes"] = localChanges
        }
        
        if previousServerSyncNotebooksDate == nil {
            syncFolders["syncStatus"] = "notdeleted"
        }
        
        let payload = ["syncFolders": syncFolders]
        
        session.put("/ws/annotation/v1.4/Services/rest/sync/folders?xver=2", payload: payload) { response in
            switch response {
            case .Success(let payload):
                do {
                    try self.annotationStore.inTransaction(.Sync) {
                        try self.applyServerChanges(payload, onOrBefore: localSyncDate)
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
        
        uploadedNotebooks = modifiedNotebooks
        
        let localChanges = modifiedNotebooks.map { notebook -> [String: AnyObject] in
            var result: [String: AnyObject] = [
                "changeType": ChangeType(status: notebook.status).rawValue,
                "folderId": notebook.uniqueID,
                "timestamp": notebook.lastModified.formattedISO8601,
            ]
            
            if notebook.status == .Active {
                result["folder"] = notebook.jsonObject(annotationStore)
            }
            
            return result
        }
        
        return localChanges
    }
    
    func applyServerChanges(payload: [String: AnyObject], onOrBefore: NSDate) throws {
        guard let syncFolders = payload["syncFolders"] as? [String: AnyObject] else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing syncFolders")
        }
        
        guard let rawServerSyncDate = syncFolders["before"] as? String, serverSyncDate = NSDate.parseFormattedISO8601(rawServerSyncDate) else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing before")
        }
        
        self.serverSyncNotebooksDate = serverSyncDate
        
        var notebookAnnotationIDs = [String: [String]]()
        
        if let remoteChanges = syncFolders["changes"] as? [[String: AnyObject]] {
            var downloadedNotebooks = [Notebook]()
            
            for change in remoteChanges {
                do {
                    try annotationStore.db.savepoint {
                        guard let uniqueID = change["folderId"] as? String else {
                            throw Error.errorWithCode(.SyncDeserializationFailed, failureReason: "Notebook is missing missing folderId")
                        }
                        guard let rawChangeType = change["changeType"] as? String, changeType = ChangeType(rawValue: rawChangeType) else {
                            throw Error.errorWithCode(.SyncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing changeType")
                        }
                        guard let rawNotebook = change["folder"] as? [String: AnyObject] else {
                            throw Error.errorWithCode(.SyncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing folder")
                        }
                        
                        if let order = rawNotebook["order"] as? [String: [String]] {
                            notebookAnnotationIDs[uniqueID] = order["id"]
                        }
                        
                        switch changeType {
                        case .New:
                            guard let rawLastModified = rawNotebook["timestamp"] as? String, lastModified = NSDate.parseFormattedISO8601(rawLastModified) else {
                                throw Error.errorWithCode(.SyncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing last modified date")
                            }
                            guard let name = rawNotebook["label"] as? String else {
                                throw Error.errorWithCode(.SyncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing name")
                            }
                            
                            let description = rawNotebook["desc"] as? String
                            let status = (rawNotebook["@status"] as? String).flatMap { AnnotationStatus(rawValue: $0) } ?? .Active
                            
                            let downloadedNotebook: Notebook
                            if var existingNotebook = self.annotationStore.notebookWithUniqueID(uniqueID) {
                                existingNotebook.name = name
                                existingNotebook.description = description
                                existingNotebook.status = status
                                existingNotebook.lastModified = lastModified
                                downloadedNotebook = try self.annotationStore.updateNotebook(existingNotebook, source: self.source)
                            } else {
                                downloadedNotebook = try self.annotationStore.addNotebook(uniqueID: uniqueID, name: name, description: description, status: status, lastModified: lastModified, source: self.source)
                            }
                            downloadedNotebooks.append(downloadedNotebook)
                        case .Trash, .Delete:
                            if let existingNotebookID = self.annotationStore.notebookWithUniqueID(uniqueID)?.id {
                                // Don't store trashed or deleted notebooks, just delete them from the db
                                try self.annotationStore.deleteNotebookWithID(existingNotebookID, source: self.source)
                            } else {
                                // If the notebook doesn't exist there's no need to delete it
                            }
                        }
                    }
                } catch let error as NSError where Error.Code(rawValue: error.code) == .SyncDeserializationFailed {
                    deserializationErrors.append(error)
                }
            }
            
            self.downloadedNotebooks = downloadedNotebooks
            self.notebookAnnotationIDs = notebookAnnotationIDs
        }
        
        // Cleanup any notebooks with the 'trashed' or 'deleted' status after they've been sync'ed successfully, there's no benefit to storing them locally anymore
        let notebooksToDelete = annotationStore.allNotebooks(lastModifiedOnOrBefore: onOrBefore).filter { $0.status != .Active }
        for notebook in notebooksToDelete {
            try annotationStore.deleteNotebookWithID(notebook.id, source: source)
        }
    }
    
}
