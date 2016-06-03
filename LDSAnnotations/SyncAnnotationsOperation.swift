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
    let notebookAnnotationIDs: [String: [String]]
    let previousLocalSyncAnnotationsDate: NSDate?
    let previousServerSyncAnnotationsDate: NSDate?
    
    var localSyncAnnotationsDate: NSDate?
    var serverSyncAnnotationsDate: NSDate?

    var uploadAnnotationCount = 0
    var uploadHighlightCount = 0
    var uploadBookmarkCount = 0
    var uploadNoteCount = 0
    var uploadLinkCount = 0
    var uploadTagCount = 0
    
    var downloadAnnotationCount = 0
    var downloadHighlightCount = 0
    var downloadBookmarkCount = 0
    var downloadNoteCount = 0
    var downloadLinkCount = 0
    var downloadTagCount = 0
    
    init(session: Session, annotationStore: AnnotationStore, notebookAnnotationIDs: [String: [String]], localSyncAnnotationsDate: NSDate?, serverSyncAnnotationsDate: NSDate?, completion: (SyncAnnotationsResult) -> Void) {
        self.session = session
        self.annotationStore = annotationStore
        self.notebookAnnotationIDs = notebookAnnotationIDs
        self.previousLocalSyncAnnotationsDate = localSyncAnnotationsDate
        self.previousServerSyncAnnotationsDate = serverSyncAnnotationsDate
        
        super.init()
        
        addCondition(AuthenticateCondition(session: session))
        addObserver(BlockObserver(startHandler: nil, produceHandler: nil, finishHandler: { operation, errors in
            if errors.isEmpty, let localSyncAnnotationsDate = self.localSyncAnnotationsDate, serverSyncAnnotationsDate = self.serverSyncAnnotationsDate {
                let changes = SyncAnnotationsChanges(uploadAnnotationCount: self.uploadAnnotationCount,
                    uploadNoteCount: self.uploadNoteCount,
                    uploadBookmarkCount: self.uploadBookmarkCount,
                    uploadHighlightCount: self.uploadHighlightCount,
                    uploadTagCount: self.uploadTagCount,
                    uploadLinkCount: self.uploadLinkCount,
                    downloadAnnotationCount: self.downloadAnnotationCount,
                    downloadNoteCount: self.downloadNoteCount,
                    downloadBookmarkCount: self.downloadBookmarkCount,
                    downloadHighlightCount: self.downloadHighlightCount,
                    downloadTagCount: self.downloadTagCount,
                    downloadLinkCount: self.downloadLinkCount)
                completion(.Success(localSyncAnnotationsDate: localSyncAnnotationsDate, serverSyncAnnotationsDate: serverSyncAnnotationsDate, changes: changes))
            } else {
                completion(.Error(errors: errors))
            }
        }))
    }
    
    override func execute() {
        let localSyncDate = NSDate()
        let localChanges = localChangesAfter(previousLocalSyncAnnotationsDate, onOrBefore: localSyncDate)
        
        self.localSyncAnnotationsDate = localSyncDate
        
        var syncAnnotations: [String: AnyObject] = [
            "since": (previousServerSyncAnnotationsDate ?? NSDate(timeIntervalSince1970: 0)).formattedISO8601,
            "clientTime": NSDate().formattedISO8601,
        ]
        
        if !localChanges.isEmpty {
            syncAnnotations["changes"] = localChanges
        }
        
        if previousServerSyncAnnotationsDate == nil {
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
        
        uploadAnnotationCount = modifiedAnnotations.count
        
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
        
        guard let rawServerSyncDate = syncAnnotations["before"] as? String, serverSyncDate = NSDate.parseFormattedISO8601(rawServerSyncDate) else {
            throw Error.errorWithCode(.Unknown, failureReason: "Missing before")
        }
        
        self.serverSyncAnnotationsDate = serverSyncDate
        
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
                        if let localSyncDate = self.localSyncAnnotationsDate {
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
                
                guard let rawAnnotation = change["annotation"] as? [String: AnyObject] else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Missing annotation")
                }
                
                guard let downloadedAnnotation = Annotation(jsonObject: rawAnnotation) else {
                    throw Error.errorWithCode(.Unknown, failureReason: "Failed to deserialize annotation: \(rawAnnotation)")
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
                    downloadAnnotationCount += 1
                    
                    if let annotationID = databaseAnnotation?.id, annotationUniqueID = databaseAnnotation?.uniqueID {
                        
                        // Note
                        if let note = rawAnnotation["note"] as? [String: AnyObject] {
                            let downloadedNote = try Note(jsonObject: note, annotationID: annotationID)
                            try annotationStore.addOrUpdateNote(downloadedNote)
                            downloadNoteCount += 1
                        }
                        
                        // Bookmark
                        if let bookmark = rawAnnotation["bookmark"] as? [String: AnyObject] {
                            let downloadedBookmark: Bookmark
                            
                            do {
                                downloadedBookmark = try Bookmark(jsonObject: bookmark, annotationID: annotationID)
                            } catch let error as NSError where Error.Code(rawValue: error.code) == .InvalidParagraphAID {
                                // This will eventually come down from the service correctly once the HTML5 version is available, so just skip it for now
                                continue
                            }
                            
                            try annotationStore.addOrUpdateBookmark(downloadedBookmark)
                            downloadBookmarkCount += 1
                        }
                        
                        // Annotation order within notebook
                        if let folders = rawAnnotation["folders"] as? [String: [[String: AnyObject]]] {
                            for folder in folders["folder"] ?? [] {
                                guard let notebookUniqueID = folder["@uri"]?.lastPathComponent else {
                                    throw Error.errorWithCode(.Unknown, failureReason: "Failed to deserialize notebook: \(folder)")
                                }

                                guard let notebookID = annotationStore.notebookWithUniqueID(notebookUniqueID)?.id else {
                                    throw Error.errorWithCode(.Unknown, failureReason: "Cannot find notebook with uniqueID \(notebookUniqueID)")
                                }
                                
                                // Don't fail if we don't get a display order from the syncFolders, just put it at the end
                                let displayOrder = notebookAnnotationIDs[notebookUniqueID]?.indexOf(annotationUniqueID)?.advancedBy(0) ?? .max

                                try annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder)
                            }
                        }
                        
                        if let highlights = rawAnnotation["highlights"] as? [String: [[String: AnyObject]]] {
                            for highlight in highlights["highlight"] ?? [] {
                                let downloadedHighlight: Highlight
                                
                                do {
                                    downloadedHighlight = try Highlight(jsonObject: highlight, annotationID: annotationID)
                                } catch let error as NSError where Error.Code(rawValue: error.code) == .InvalidParagraphAID {
                                    // This will eventually come down from the service correctly once the HTML5 version is available, so just skip it for now
                                    continue
                                }

                                try annotationStore.addOrUpdateHighlight(downloadedHighlight)
                                downloadHighlightCount += 1
                            }
                        }
                        
                        if let links = rawAnnotation["refs"] as? [String: [[String: AnyObject]]] {
                            for link in links["ref"] ?? [] {
                                let downloadedLink: Link

                                do {
                                    downloadedLink = try Link(jsonObject: link, annotationID: annotationID)
                                } catch let error as NSError where Error.Code(rawValue: error.code) == .InvalidParagraphAID {
                                    // This will eventually come down from the service correctly once the HTML5 version is available, so just skip it for now
                                    continue
                                }
                                
                                try annotationStore.addOrUpdateLink(downloadedLink)
                                downloadLinkCount += 1
                            }
                        }
                        
                        if let tags = rawAnnotation["tags"] as? [String: [String]] {
                            for tagName in tags["tag"] ?? [] {
                                let downloadedTag = try Tag(name: tagName)
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
