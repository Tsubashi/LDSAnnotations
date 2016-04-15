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

class SyncAnnotationsOperation: Operation {
    
    let session: Session
    let annotationStore: AnnotationStore
    let token: SyncToken?
    let localSyncNotebooksDate: NSDate?
    let serverSyncNotebooksDate: NSDate?
    var localSyncAnnotationsDate: NSDate?
    var serverSyncAnnotationsDate: NSDate?
    
    let notebookAnnotationIDs: [String: [String]]

    var uploadCount = 0
    var uploadHighlightCount = 0
    var uploadBookmarkCount = 0
    var uploadNoteCount = 0
    var uploadLinkCount = 0
    var uploadTagCount = 0
    
    var downloadCount = 0
    var downloadHighlightCount = 0
    var downloadBookmarkCount = 0
    var downloadNoteCount = 0
    var downloadLinkCount = 0
    var downloadTagCount = 0
    
    init(session: Session, annotationStore: AnnotationStore, token: SyncToken?, localSyncNotebooksDate: NSDate?, serverSyncNotebooksDate: NSDate?, notebookAnnotationIDs: [String: [String]]?, completion: (SyncAnnotationsResult) -> Void) {
        self.session = session
        self.annotationStore = annotationStore
        self.token = token
        self.notebookAnnotationIDs = notebookAnnotationIDs ?? [:]
        self.localSyncNotebooksDate = localSyncNotebooksDate
        self.serverSyncNotebooksDate = serverSyncNotebooksDate
        
        super.init()
        
        addCondition(AuthenticateCondition(session: session))
        addObserver(BlockObserver(startHandler: nil, produceHandler: nil, finishHandler: { operation, errors in
            if errors.isEmpty, let localSyncNotebooksDate = self.localSyncNotebooksDate, serverSyncNotebooksDate = self.serverSyncNotebooksDate, localSyncAnnotationsDate = self.localSyncAnnotationsDate, serverSyncAnnotationsDate = self.serverSyncAnnotationsDate {
                completion(.Success(token: SyncToken(localSyncNotebooksDate: localSyncNotebooksDate, serverSyncNotebooksDate: serverSyncNotebooksDate, localSyncAnnotationsDate: localSyncAnnotationsDate, serverSyncAnnotationsDate: serverSyncAnnotationsDate),
                    uploadCount: self.uploadCount,
                    uploadNoteCount: self.uploadNoteCount,
                    uploadBookmarkCount: self.uploadBookmarkCount,
                    uploadHighlightCount: self.uploadHighlightCount,
                    uploadTagCount: self.uploadTagCount,
                    uploadLinkCount: self.uploadLinkCount,
                    downloadCount: self.downloadCount,
                    downloadNoteCount: self.downloadNoteCount,
                    downloadBookmarkCount: self.downloadBookmarkCount,
                    downloadHighlightCount: self.downloadHighlightCount,
                    downloadTagCount: self.downloadTagCount,
                    downloadLinkCount: self.downloadLinkCount))
            } else {
                completion(.Error(errors: errors))
            }
        }))
    }
    
    override func execute() {
        let localSyncDate = NSDate()
        let localChanges = localChangesAfter(token?.localSyncAnnotationsDate, onOrBefore: localSyncDate)
        
        var syncAnnotations: [String: AnyObject] = [
            "since": (token?.serverSyncAnnotationsDate ?? NSDate(timeIntervalSince1970: 0)).formattedISO8601,
            "clientTime": NSDate().formattedISO8601,
        ]
        
        if !localChanges.isEmpty {
            syncAnnotations["changes"] = localChanges
        }
        
        if token?.serverSyncAnnotationsDate == nil {
            syncAnnotations["syncStatus"] = "notdeleted"
        }
        
        let payload = ["syncAnnotations": syncAnnotations]
        
        session.put("/ws/annotation/v1.4/Services/rest/sync/annotations-ids?xver=2", payload: payload) { response in
            switch response {
            case .Success(let payload):
                do {
                    try self.requestVersionedAnnotations(payload)
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
        let modifiedAnnotations = annotationStore.allAnnotations(lastModifiedAfter: after, lastModifiedOnOrBefore: onOrBefore)
        
        uploadCount = modifiedAnnotations.count
        
        let localChanges = modifiedAnnotations.map { annotation -> [String: AnyObject] in
            var result: [String: AnyObject] = [
                "changeType": ChangeType(status: annotation.status).rawValue,
                "annotationId": annotation.uniqueID,
                "timestamp": annotation.lastModified.formattedISO8601,
            ]
            
            if annotation.status != .Deleted {
                result["annotation"] = annotation.jsonObject(annotationStore)
            }
            
            return result
        }
        
        for change in localChanges {
            guard let annotation = change["annotation"] as? [String: AnyObject] else { continue }
        
            uploadNoteCount += (annotation["note"] != nil) ? 1 : 0
            uploadBookmarkCount += (annotation["bookmark"] != nil) ? 1 : 0
            if let highlights = annotation["highlights"] as? [String: [[String: AnyObject]]], count = highlights["highlight"]?.count {
                uploadHighlightCount += count
            }
            if let links = annotation["references"] as? [String: [[String: AnyObject]]], count = links["reference"]?.count {
                uploadLinkCount += count
            }
            if let tags = annotation["tags"] as? [String: [[String: AnyObject]]], count = tags["tag"]?.count {
                uploadTagCount += count
            }
        }
        
        return localChanges
    }
    
    func requestVersionedAnnotations(payload: [String: AnyObject]) throws {
        guard let syncAnnotations = payload["syncAnnotationsIds"] as? [String: AnyObject] else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing syncAnnotationsIds")
        }
        
        guard let syncIDs = syncAnnotations["syncIds"] as? [[String: AnyObject]] else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing syncIds")
        }
                
        let docIDs = syncIDs.flatMap { $0["docId"] as? String }
        let docIDsAndVersions = session.docVersionsForDocIDs?(docIDs: docIDs)
        
        let annotationIDsAndVersions = syncIDs.flatMap { syncID -> [String: AnyObject]? in
            guard let annotationID = syncID["aid"] as? String, docID = syncID["docId"] as? String else { return nil }
            
            if let version = docIDsAndVersions?[docID] {
                return ["aid": annotationID, "ver": version]
            }
            return ["aid": annotationID]
        }
        
        executeVersionedAnnotationsRequest(annotationIDsAndVersions)
    }
    
    func executeVersionedAnnotationsRequest(annotationIDsAndVersions: [[String: AnyObject]]) {
        let annotationVersions: [String: AnyObject] = [
            "clientTime": NSDate().formattedISO8601,
            "annoVers": annotationIDsAndVersions
        ]
        let payload = [
            "xformAnnoVers": annotationVersions
        ]
        
        session.put("/ws/annotation/v1.4/Services/rest/xform/annotations?xver=2", payload: payload) { response in
            switch response {
            case .Success(let payload):
                do {
                    try self.annotationStore.inSyncTransaction {
                        if let localSyncDate = self.token?.localSyncAnnotationsDate {
                            let deletedAnnotations = self.annotationStore.deletedAnnotations(lastModifiedOnOrBefore: localSyncDate)
                            // TODO: Do we need to actually delete these?
                            print(deletedAnnotations)
                        }
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
    
    func applyServerChanges(payload: [String: AnyObject]) throws {
        guard let syncAnnotations = payload["syncAnnotations"] as? [String: AnyObject] else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing syncAnnotations")
        }
        
        if let remoteChanges = syncAnnotations["changes"] as? [[String: AnyObject]] {
            for change in remoteChanges {
                guard let rawChangeType = change["changeType"] as? String, changeType = ChangeType(rawValue: rawChangeType) else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Missing changeType")
                }
                
                guard let uniqueID = change["annotationId"] as? String else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Missing annotationId")
                }
                
                guard let annotation = change["annotation"] as? [String: AnyObject], downloadedAnnotation = Annotation(jsonObject: annotation) else {
                    NSLog("Unable to deserialize annotation: %@", change)
                    continue
                }
                
                switch changeType {
                case .New, .Trash:
                    let databaseAnnotation: Annotation?
                    if let existingAnnotation = annotationStore.annotationWithUniqueID(uniqueID) {
                        var mergedAnnotation = downloadedAnnotation
                        mergedAnnotation.id = existingAnnotation.id
                        databaseAnnotation = annotationStore.addOrUpdateAnnotation(mergedAnnotation)
                    } else {
                        databaseAnnotation = annotationStore.addOrUpdateAnnotation(downloadedAnnotation)
                    }
                    downloadCount += 1
                    
                    if let annotationID = databaseAnnotation?.id, annotationUniqueID = databaseAnnotation?.uniqueID {
                        
                        // Note
                        if let note = annotation["note"] as? [String: AnyObject] {
                            if let downloadedNote = Note(jsonObject: note, annotationID: annotationID) {
                                try annotationStore.addOrUpdateNote(downloadedNote)
                                downloadNoteCount += 1
                            } else {
                                NSLog("Failed to deserialize note: %@", note)
                            }
                        }
                        
                        // Bookmark
                        if let bookmark = annotation["bookmark"] as? [String: AnyObject] {
                            if let downloadedBookmark = Bookmark(jsonObject: bookmark, annotationID: annotationID) {
                                try annotationStore.addOrUpdateBookmark(downloadedBookmark)
                                downloadBookmarkCount += 1
                            } else {
                                NSLog("Failed to deserialize bookmark: %@", bookmark)
                            }
                        }
                        
                        // Annotation order within notebook
                        if let folders = annotation["folders"] as? [String: [[String: AnyObject]]] {
                            for folder in folders["folder"] ?? [] {
                                guard let notebookUniqueID = folder["@uri"]?.lastPathComponent else {
                                    NSLog("Failed to deserialize folder: %@", folder)
                                    continue
                                }

                                guard let notebookID = annotationStore.notebookWithUniqueID(notebookUniqueID)?.id else {
                                    NSLog("No notebook with uniqueID found in database: %@", notebookUniqueID)
                                    continue
                                }
                                
                                // Don't fail if we don't get a display order from the syncFolders, just put it at the end
                                let displayOrder = notebookAnnotationIDs[notebookUniqueID]?.indexOf(annotationUniqueID)?.advancedBy(0) ?? .max

                                try annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder)
                            }
                        }
                        
                        if let highlights = annotation["highlights"] as? [String: [[String: AnyObject]]] {
                            for highlight in highlights["highlight"] ?? [] {
                                guard let downloadedHighlight = Highlight(jsonObject: highlight, annotationID: annotationID) else {
                                    NSLog("Failed to deserialize highlight: %@", highlight)
                                    continue
                                }
                                
                                try annotationStore.addOrUpdateHighlight(downloadedHighlight)
                                downloadHighlightCount += 1
                            }
                        }
                        
                        if let links = annotation["refs"] as? [String: [[String: AnyObject]]] {
                            for link in links["ref"] ?? [] {
                                guard let downloadedLink = Link(jsonObject: link, annotationID: annotationID) else {
                                    NSLog("Failed to deserialize link: %@", link)
                                    continue
                                }
                                
                                try annotationStore.addOrUpdateLink(downloadedLink)
                                downloadLinkCount += 1
                            }
                        }
                        
                        if let tags = annotation["tags"] as? [String: [String]] {
                            for tagName in tags["tag"] ?? [] {
                                guard let downloadedTag = Tag(name: tagName) else {
                                    NSLog("Failed to deserialize tag: %@", tagName)
                                    continue
                                }
                                
                                let tag = try annotationStore.addOrUpdateTag(downloadedTag)
                                downloadTagCount += 1
                                
                                if let tagID = tag?.id {
                                    try annotationStore.addOrUpdateAnnotationTag(annotationID: annotationID, tagID: tagID)
                                }
                            }
                        }
                    }
                    
                case .Delete:
                    if let existingAnnotation = annotationStore.annotationWithUniqueID(uniqueID), existingAnnotationID = existingAnnotation.id {
                        annotationStore.deleteAnnotationWithID(existingAnnotationID)
                    } else {
                        // If the annotation doesn't exist there's no need to delete it
                    }
                }
            }
        }
    }
    
}
