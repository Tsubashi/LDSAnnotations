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
import ProcedureKit

class SyncNotebooksOperation: Procedure, ResultInjection {
    
    let session: Session
    let annotationStore: AnnotationStore
    let previousLocalSyncNotebooksDate: Date?
    let previousServerSyncNotebooksDate: Date?
    
    var result: PendingValue<SyncNotebooksResult> = .pending
    var requirement: PendingValue<Void> = .void
    
    private let source: NotificationSource = .sync
    
    init(session: Session, annotationStore: AnnotationStore, localSyncNotebooksDate: Date?, serverSyncNotebooksDate: Date?) {
        self.session = session
        self.annotationStore = annotationStore
        self.previousLocalSyncNotebooksDate = localSyncNotebooksDate
        self.previousServerSyncNotebooksDate = serverSyncNotebooksDate
        
        super.init()
        
        add(condition: AuthenticateCondition(session: session))
    }
    
    override func execute() {
        let localSyncDate = Date()
        let (localChanges, uploadedNotebooks) = localChangesAfter(previousLocalSyncNotebooksDate, onOrBefore: localSyncDate)
        
        var syncFolders: [String: Any] = [
            "since": (previousServerSyncNotebooksDate ?? Date(timeIntervalSince1970: 0)).formattedISO8601,
            "clientTime": Date().formattedISO8601,
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
            case .success(let payload):
                do {
                    let (serverSyncNotebooksDate, notebookAnnotationIDs, downloadedNotebooks, deserializationErrors) = try self.annotationStore.inTransaction(notificationSource: .sync) {
                        return try self.applyServerChanges(payload, onOrBefore: localSyncDate)
                    }
                    let changes = SyncNotebooksChanges(notebookAnnotationIDs: notebookAnnotationIDs, uploadedNotebooks: uploadedNotebooks, downloadedNotebooks: downloadedNotebooks)
                    self.result = .ready(SyncNotebooksResult(localSyncNotebooksDate: localSyncDate, serverSyncNotebooksDate: serverSyncNotebooksDate, changes: changes, deserializationErrors: deserializationErrors))
                    self.finish()
                } catch {
                    self.finish(withError: error)
                }
            case .failure(let payload):
                self.finish(withError: AnnotationError.errorWithCode(.unknown, failureReason: "Failure response: \(payload)"))
            case .error(let error):
                self.finish(withError: error)
            }
        }
    }
    
    func localChangesAfter(_ after: Date?, onOrBefore: Date) -> ([[String: Any]], [Notebook]) {
        let modifiedNotebooks = annotationStore.allNotebooks(lastModifiedAfter: after, lastModifiedOnOrBefore: onOrBefore)
        
        let localChanges = modifiedNotebooks.map { notebook -> [String: Any] in
            var result: [String: Any] = [
                "changeType": ChangeType(status: notebook.status).rawValue,
                "folderId": notebook.uniqueID,
                "timestamp": notebook.lastModified.formattedISO8601,
            ]
            
            if notebook.status == .active {
                result["folder"] = notebook.jsonObject(annotationStore)
            }
            
            return result
        }
        
        return (localChanges, modifiedNotebooks)
    }
    
    func applyServerChanges(_ payload: [String: Any], onOrBefore: Date) throws -> (Date, [String: [String]], [Notebook], [Error]) {
        guard let syncFolders = payload["syncFolders"] as? [String: Any] else {
            throw AnnotationError.errorWithCode(.unknown, failureReason: "Missing syncFolders")
        }
        
        guard let rawServerSyncDate = syncFolders["before"] as? String, let serverSyncDate = Date.parseFormattedISO8601(rawServerSyncDate) else {
            throw AnnotationError.errorWithCode(.unknown, failureReason: "Missing before")
        }
        
        var notebookAnnotationIDs = [String: [String]]()
        var downloadedNotebooks = [Notebook]()
        var deserializationErrors = [Error]()
        
        if let remoteChanges = syncFolders["changes"] as? [[String: Any]] {
            for change in remoteChanges {
                do {
                    try annotationStore.db.savepoint {
                        guard let uniqueID = change["folderId"] as? String else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Notebook is missing missing folderId")
                        }
                        guard let rawChangeType = change["changeType"] as? String, let changeType = ChangeType(rawValue: rawChangeType) else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing changeType")
                        }
                        guard let rawNotebook = change["folder"] as? [String: Any] else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing folder")
                        }
                        
                        let displayOrders = rawNotebook["order"] as? [String: [String]]
                        let annotationUniqueIDs = displayOrders?["id"]
                        notebookAnnotationIDs[uniqueID] = annotationUniqueIDs ?? []
                        
                        switch changeType {
                        case .new:
                            guard let rawLastModified = rawNotebook["timestamp"] as? String, let lastModified = Date.parseFormattedISO8601(rawLastModified) else {
                                throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing last modified date")
                            }
                            guard let name = rawNotebook["label"] as? String else {
                                throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Notebook with uniqueID '\(uniqueID)' is missing name")
                            }
                            
                            let description = rawNotebook["desc"] as? String
                            let status = (rawNotebook["@status"] as? String).flatMap { AnnotationStatus(rawValue: $0) } ?? .active
                            
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
                            
                            // If the annotations have been reordered, but nothing else within the annotation has changed, we'll only get the order change here in the notebooks sync, so store the order
                            for annotationUniqueID in annotationUniqueIDs ?? [] {
                                guard let annotation = self.annotationStore.annotationWithUniqueID(annotationUniqueID) else { continue }
                                
                                let displayOrder = annotationUniqueIDs?.index(of: annotationUniqueID) ?? .max
                                try self.annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotation.id, notebookID: downloadedNotebook.id, displayOrder: displayOrder, source: self.source)
                            }
                        case .trash, .delete:
                            if let existingNotebookID = self.annotationStore.notebookWithUniqueID(uniqueID)?.id {
                                // Don't store trashed or deleted notebooks, just delete them from the db
                                try self.annotationStore.deleteNotebookWithID(existingNotebookID, source: self.source)
                            } else {
                                // If the notebook doesn't exist there's no need to delete it
                            }
                        }
                    }
                } catch let error as NSError where AnnotationError.Code(rawValue: error.code) == .syncDeserializationFailed {
                    deserializationErrors.append(error)
                }
            }
        }
        
        // Cleanup any notebooks with the 'trashed' or 'deleted' status after they've been sync'ed successfully, there's no benefit to storing them locally anymore
        let notebooksToDelete = annotationStore.allNotebooks(lastModifiedOnOrBefore: onOrBefore).filter { $0.status != .active }
        for notebook in notebooksToDelete {
            try annotationStore.deleteNotebookWithID(notebook.id, source: source)
        }
        
        return (serverSyncDate, notebookAnnotationIDs, downloadedNotebooks, deserializationErrors)
    }
    
}
