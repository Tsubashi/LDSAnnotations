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

enum SyncAnnotationsOperationError: Error {
    case notebookSyncFailed(String)
}

class SyncAnnotationsOperation: Procedure, ResultInjection {
    
    var result: PendingValue<Void> = .void
    var requirement: PendingValue<SyncNotebooksResult> = .pending
    
    let session: Session
    let annotationStore: AnnotationStore
    let previousLocalSyncAnnotationsDate: Date?
    let previousServerSyncAnnotationsDate: Date?
    
    var localSyncAnnotationsDate: Date?
    var serverSyncAnnotationsDate: Date?

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
    var deserializationErrors = [Error]()
    
    private let source: NotificationSource = .sync
    
    init(session: Session, annotationStore: AnnotationStore, localSyncAnnotationsDate: Date?, serverSyncAnnotationsDate: Date?, completion: @escaping (SyncAnnotationsResult) -> Void) {
        self.session = session
        self.annotationStore = annotationStore
        self.previousLocalSyncAnnotationsDate = localSyncAnnotationsDate
        self.previousServerSyncAnnotationsDate = serverSyncAnnotationsDate
        
        super.init()
        
        add(condition: AuthenticateCondition(session: session))
        add(observer: BlockObserver(didFinish: { operation, errors in
            if errors.isEmpty, let localSyncAnnotationsDate = self.localSyncAnnotationsDate, let serverSyncAnnotationsDate = self.serverSyncAnnotationsDate, let notebooksResult = self.requirement.value {
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
                completion(.success(notebooksResult: notebooksResult, localSyncAnnotationsDate: localSyncAnnotationsDate, serverSyncAnnotationsDate: serverSyncAnnotationsDate, changes: changes, deserializationErrors: self.deserializationErrors))
            } else {
                completion(.error(errors: errors))
            }
        }))
    }
    
    override func execute() {
        guard requirement.value != nil else {
            finish(withError: SyncAnnotationsOperationError.notebookSyncFailed("Sync notebooks failed, cannot sync annotations."))
            return
        }
        
        let localSyncDate = Date()
        let localChanges = localChangesAfter(previousLocalSyncAnnotationsDate, onOrBefore: localSyncDate)
        
        self.localSyncAnnotationsDate = localSyncDate
        
        var syncAnnotations: [String: Any] = [
            "since": (previousServerSyncAnnotationsDate ?? Date(timeIntervalSince1970: 0)).formattedISO8601,
            "clientTime": Date().formattedISO8601,
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
            case .success(let payload):
                let syncAnnotationsIds = payload["syncAnnotationsIds"] as? [String: Any]
                if let errorsJSON = syncAnnotationsIds?["errors"] as? [[String: Any]], !errorsJSON.isEmpty {
                    // Server returned errors, fail
                    
                    let errors = errorsJSON.map { AnnotationError.errorWithCode(.syncFailed, failureReason: String(format: "Failed to sync annotation with unique ID \"%@\": %@", $0["id"] as? String ?? "Unknown", $0["msg"] as? String ?? "Unknown")) }
                    self.finish(withErrors: errors)
                    
                } else {
                    // No errors, sync is good
                    if (syncAnnotationsIds?["syncIds"] as? [[String: Any]])?.isEmpty == true, let rawServerSyncDate = syncAnnotationsIds?["before"] as? String, let serverSyncDate = Date.parseFormattedISO8601(rawServerSyncDate) {
                        // If there are no syncIds, don't bother requesting versioned annotations, nothing has changed
                        do {
                            self.serverSyncAnnotationsDate = serverSyncDate
                            try self.annotationStore.inTransaction(notificationSource: self.source) {
                                try self.applyServerChanges(payload, onOrBefore: localSyncDate)
                            }
                            self.finish()
                        } catch let error as NSError {
                            self.finish(withError: error)
                        }
                    } else {
                        do {
                            try self.requestVersionedAnnotations(payload, onOrBefore: localSyncDate)
                        } catch let error as NSError {
                            self.finish(withError: error)
                        }
                    }
                }
            case .failure(let payload):
                self.finish(withError: AnnotationError.errorWithCode(.unknown, failureReason: "Failure response: \(payload)"))
            case .error(let error):
                self.finish(withError: error)
            }
        }
    }
    
    func localChangesAfter(_ after: Date?, onOrBefore: Date) -> [[String: Any]] {
        let modifiedAnnotations = annotationStore.allAnnotations(lastModifiedAfter: after, lastModifiedOnOrBefore: onOrBefore)
        
        uploadAnnotationCount = modifiedAnnotations.count
        
        let localChanges = modifiedAnnotations.map { annotation -> [String: Any] in
            var result: [String: Any] = [
                "changeType": ChangeType(status: annotation.status).rawValue,
                "annotationId": annotation.uniqueID,
                "timestamp": annotation.lastModified.formattedISO8601,
            ]
            
            if annotation.status == .active {
                result["annotation"] = annotation.jsonObject(annotationStore: annotationStore)
            }
            
            return result
        }
        
        for change in localChanges {
            guard let annotation = change["annotation"] as? [String: Any] else { continue }
        
            uploadNoteCount += (annotation["note"] != nil) ? 1 : 0
            uploadBookmarkCount += (annotation["bookmark"] != nil) ? 1 : 0
            if let highlights = annotation["highlights"] as? [String: [[String: Any]]], let count = highlights["highlight"]?.count {
                uploadHighlightCount += count
            }
            if let links = annotation["references"] as? [String: [[String: Any]]], let count = links["reference"]?.count {
                uploadLinkCount += count
            }
            if let tags = annotation["tags"] as? [String: [[String: Any]]], let count = tags["tag"]?.count {
                uploadTagCount += count
            }
        }
        
        return localChanges
    }
    
    func requestVersionedAnnotations(_ payload: [String: Any], onOrBefore: Date) throws {
        guard let syncAnnotations = payload["syncAnnotationsIds"] as? [String: Any] else {
            throw AnnotationError.errorWithCode(.unknown, failureReason: "Missing syncAnnotationsIds")
        }
        
        guard let rawServerSyncDate = syncAnnotations["before"] as? String, let serverSyncDate = Date.parseFormattedISO8601(rawServerSyncDate) else {
            throw AnnotationError.errorWithCode(.unknown, failureReason: "Missing before")
        }
        
        self.serverSyncAnnotationsDate = serverSyncDate
        
        guard let syncIDs = syncAnnotations["syncIds"] as? [[String: Any]] else {
            throw AnnotationError.errorWithCode(.unknown, failureReason: "Missing syncIds")
        }
                
        let docIDs = syncIDs.flatMap { $0["docId"] as? String }
        let docIDsAndVersions = session.docVersionsForDocIDs?(docIDs)
        
        let annotationIDsAndVersions = syncIDs.flatMap { syncID -> [String: Any]? in
            guard let annotationID = syncID["aid"] as? String else { return nil }
            
            if let docID = syncID["docId"] as? String, let version = docIDsAndVersions?[docID] {
                return ["aid": annotationID, "ver": version]
            }
            return ["aid": annotationID]
        }
        
        executeVersionedAnnotationsRequest(annotationIDsAndVersions, onOrBefore: onOrBefore)
    }
    
    func executeVersionedAnnotationsRequest(_ annotationIDsAndVersions: [[String: Any]], onOrBefore: Date) {
        let annotationVersions: [String: Any] = [
            "clientTime": Date().formattedISO8601,
            "annoVers": annotationIDsAndVersions
        ]
        let payload = [
            "xformAnnoVers": annotationVersions
        ]
        
        session.put("/ws/annotation/v1.4/Services/rest/xform/annotations?xver=2", payload: payload) { response in
            switch response {
            case .success(let payload):
                do {
                    try self.annotationStore.inTransaction(notificationSource: self.source) {
                        try self.applyServerChanges(payload, onOrBefore: onOrBefore)
                    }
                    self.finish()
                } catch let error as NSError {
                    self.finish(withError: error)
                }
            case .failure(let payload):
                self.finish(withError: AnnotationError.errorWithCode(.unknown, failureReason: "Failure response: \(payload)"))
            case .error(let error):
                self.finish(withError: error)
            }
        }
    }
    
    func applyServerChanges(_ payload: [String: Any], onOrBefore: Date) throws {
        let syncAnnotations = payload["syncAnnotations"] as? [String: Any] ?? [:]
        let notebookAnnotationIDs = requirement.value?.changes.notebookAnnotationIDs
        
        if let remoteChanges = syncAnnotations["changes"] as? [[String: Any]] {
            var changedAnnotationIDs: [Int64] = []
            var changedNotebookIDs: [Int64] = []
            
            var noteByAnnotationID = [Int64: Note]()
            var bookmarkByAnnotationID = [Int64: Bookmark]()
            var highlightsByAnnotationID = [Int64: [Highlight]]()
            var linksByAnnotationID = [Int64: [Link]]()
            var annotationByUniqueID = [String: Annotation]()
            let annotationUniqueIDs = remoteChanges.flatMap { $0["annotationId"] as? String }
            let annotations = annotationStore.annotationsWithUniqueIDsIn(annotationUniqueIDs)
            let annotationIDs = annotations.map { $0.id }
            
            for annotation in annotations {
                annotationByUniqueID[annotation.uniqueID] = annotation
            }
            for note in annotationStore.notesWithAnnotationIDsIn(annotationIDs) {
                noteByAnnotationID[note.annotationID] = note
            }
            for bookmark in annotationStore.bookmarksWithAnnotationIDsIn(annotationIDs) {
                bookmarkByAnnotationID[bookmark.annotationID] = bookmark
            }
            for hightlight in annotationStore.highlightsWithAnnotationIDsIn(annotationIDs) {
                if highlightsByAnnotationID[hightlight.annotationID] != nil {
                    highlightsByAnnotationID[hightlight.annotationID]?.append(hightlight)
                } else {
                    highlightsByAnnotationID[hightlight.annotationID] = [hightlight]
                }
            }
            for link in annotationStore.linksWithAnnotationIDsIn(annotationIDs) {
                if linksByAnnotationID[link.annotationID] != nil {
                    linksByAnnotationID[link.annotationID]?.append(link)
                } else {
                    linksByAnnotationID[link.annotationID] = [link]
                }
            }
            
            let notebookIDsByAnnotationID = annotationStore.notebookIDsWithAnnotationIDsIn(annotationIDs)
            let tagsIDsByAnnotationID = annotationStore.tagIDsWithAnnotationIDsIn(annotationIDs)
            
            for change in remoteChanges {
                do {
                    try annotationStore.db.savepoint {
                        guard let uniqueID = change["annotationId"] as? String else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Missing annotationId")
                        }
                        guard let rawChangeType = change["changeType"] as? String, let changeType = ChangeType(rawValue: rawChangeType) else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Annotation with uniqueID '\(uniqueID)' is missing changeType")
                        }
                        guard let rawAnnotation = change["annotation"] as? [String: Any] else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Annotation with uniqueID '\(uniqueID)' is missing annotation")
                        }
                        guard let rawLastModified = rawAnnotation["timestamp"] as? String, let lastModified = Date.parseFormattedISO8601(rawLastModified) else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Annotation with uniqueID '\(uniqueID)' is missing last modified date")
                        }
                        guard let appSource = rawAnnotation["source"] as? String else {
                            throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Annotation with uniqueID '\(uniqueID)' is missing source")
                        }
                        
                        switch changeType {
                        case .new:
                            let docID = rawAnnotation["@docId"] as? String
                            let docVersion = (rawAnnotation["@contentVersion"] as? String).flatMap { Int($0) }
                            let created = (rawAnnotation["created"] as? String).flatMap { Date.parseFormattedISO8601($0) }
                            let status = (rawAnnotation["@status"] as? String).flatMap { AnnotationStatus(rawValue: $0) } ?? .active
                            let device = rawAnnotation["device"] as? String ?? "iphone"
                            
                            let databaseAnnotation: Annotation
                            if var existingAnnotation = annotationByUniqueID[uniqueID] {
                                existingAnnotation.appSource = appSource
                                existingAnnotation.device = device
                                existingAnnotation.docID = docID
                                existingAnnotation.docVersion = docVersion
                                existingAnnotation.created = created
                                existingAnnotation.lastModified = lastModified
                                existingAnnotation.status = status
                                databaseAnnotation = try self.annotationStore.updateAnnotation(existingAnnotation, source: self.source)
                            } else {
                                databaseAnnotation = try self.annotationStore.addAnnotation(uniqueID: uniqueID, docID: docID, docVersion: docVersion, created: created, lastModified: lastModified, appSource: appSource, device: device, source: self.source)
                            }
                            
                            let annotationID = databaseAnnotation.id
                            changedAnnotationIDs.append(annotationID)
                            
                            // MARK: Note
                            if let note = rawAnnotation["note"] as? [String: Any] {
                                let title = note["title"] as? String
                                let content = note["content"] as? String ?? ""
                                if var existingNote = noteByAnnotationID[annotationID] {
                                    existingNote.title = title
                                    existingNote.content = content
                                    try self.annotationStore.updateNote(existingNote, source: self.source)
                                } else {
                                    try self.annotationStore.addNote(title: title, content: content, annotationID: annotationID, source: self.source)
                                }
                                self.downloadNoteCount += 1
                            } else if let noteID = noteByAnnotationID[annotationID]?.id {
                                // The service says that the note has been deleted
                                
                                try self.annotationStore.deleteNoteWithID(noteID, source: self.source)
                            }
                            
                            // MARK: Bookmark
                            if let bookmark = rawAnnotation["bookmark"] as? [String: Any] {
                                if bookmark["@pid"] == nil && bookmark["uri"] != nil {
                                    // Bookmark has a URI, but no @pid so its invalid. If both are nil, its a valid chapter-level bookmark
                                    throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Bookmark with annotation uniqueID '\(uniqueID)' is missing paragraphAID")
                                }
                                
                                let name = bookmark["name"] as? String
                                let paragraphAID = bookmark["@pid"] as? String
                                let displayOrder = bookmark["sort"] as? Int
                                let offset = (bookmark["@offset"] as? String).flatMap { Int($0) } ?? Bookmark.Offset
                                
                                if var databaseBookmark = bookmarkByAnnotationID[annotationID] {
                                    databaseBookmark.name = name
                                    databaseBookmark.paragraphAID = paragraphAID
                                    databaseBookmark.displayOrder = displayOrder
                                    databaseBookmark.offset = offset
                                    
                                    try self.annotationStore.updateBookmark(databaseBookmark, source: self.source)
                                } else {
                                    try self.annotationStore.addBookmark(name: name, paragraphAID: paragraphAID, displayOrder: displayOrder, annotationID: annotationID, offset: offset, source: self.source)
                                }
                                
                                self.downloadBookmarkCount += 1
                            } else if let bookmarkID = bookmarkByAnnotationID[annotationID]?.id {
                                // The service says that the bookmark has been deleted
                                
                                try self.annotationStore.deleteBookmarkWithID(bookmarkID, source: self.source)
                            }
                            
                            // MARK: Notebooks
                            
                            var notebookIDsToDelete = notebookIDsByAnnotationID[annotationID] ?? []
                            changedNotebookIDs.append(contentsOf: notebookIDsToDelete)
                            if let folders = rawAnnotation["folders"] as? [String: [[String: Any]]] {
                                for folder in folders["folder"] ?? [] {
                                    guard let notebookUniqueID = (folder["@uri"] as? NSString)?.lastPathComponent else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Notebook is missing uniqueID: \(folder)")
                                    }
                                    
                                    guard let notebookID = self.annotationStore.notebookWithUniqueID(notebookUniqueID)?.id else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Cannot associate annotation with uniqueID '\(uniqueID)' to notebook with uniqueID '\(notebookUniqueID)'")
                                    }
                                    
                                    if let index = notebookIDsToDelete.index(of: notebookID) {
                                        // This notebook is still connected to the annotation, so remove it from the list of notebook IDs to delete
                                        notebookIDsToDelete.remove(at: index)
                                    }
                                    
                                    // Don't fail if we don't get a display order from the syncFolders, just put it at the end
                                    let displayOrder = notebookAnnotationIDs?[notebookUniqueID]?.index(of: uniqueID) ?? .max
                                    
                                    try self.annotationStore.addOrUpdateAnnotationNotebook(annotationID: annotationID, notebookID: notebookID, displayOrder: displayOrder, source: self.source)
                                }
                            }
                            for notebookID in notebookIDsToDelete {
                                // Any notebook IDs left in `databaseNotebookIDs` should be deleted because the service says they aren't connected anymore
                                try self.annotationStore.removeAnnotation(annotationID: annotationID, fromNotebook: notebookID, source: self.source)
                            }
                            
                            // MARK: Highlights
                            
                            // Delete any existing highlights and then we'll just create new ones with what the server gives us
                            if let highlights = highlightsByAnnotationID[annotationID] {
                                for highlightID in highlights.map({ $0.id }) {
                                    try self.annotationStore.deleteHighlightWithID(highlightID, source: self.source)
                                }
                            }
                            
                            
                            // Add new highlights
                            if let highlights = rawAnnotation["highlights"] as? [String: [[String: Any]]] {
                                for highlight in highlights["highlight"] ?? [] {
                                    guard let offsetStartString = highlight["@offset-start"] as? String, let offsetStart = Int(offsetStartString) else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Highlight with annotation uniqueID '\(uniqueID)' is missing offset-start")
                                    }
                                    guard let offsetEndString = highlight["@offset-end"] as? String, let offsetEnd = Int(offsetEndString) else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Highlight with annotation uniqueID '\(uniqueID)' is missing offset-end")
                                    }
                                    guard let colorName = highlight["@color"] as? String else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Highlight with annotation uniqueID '\(uniqueID)' is missing color")
                                    }
                                    guard let paragraphAID = highlight["@pid"] as? String else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Highlight with annotation uniqueID '\(uniqueID)' is missing paragraphAID")
                                    }
                                    
                                    let paragraphRange = ParagraphRange(paragraphAID: paragraphAID, startWordOffset: offsetStart, endWordOffset: offsetEnd)
                                    let style = (highlight["@style"] as? String).flatMap { HighlightStyle(rawValue: $0) } ?? .highlight
                                    
                                    try self.annotationStore.addHighlight(paragraphRange: paragraphRange, colorName: colorName, style: style, annotationID: annotationID, source: self.source)
                                    self.downloadHighlightCount += 1
                                }
                            }
                            
                            // MARK: Links
                            
                            // Delete any existing links and then we'll just create new ones with what the server gives us
                            if let links = linksByAnnotationID[annotationID] {
                                for linkID in links.map({ $0.id }) {
                                    // Any link IDs left in `linksIDsToDelete` should be deleted because the service says they are gone
                                    try self.annotationStore.deleteLinkWithID(linkID, source: self.source)
                                }
                            }
                            
                            // Add new links now
                            if let links = rawAnnotation["refs"] as? [String: [[String: Any]]] {
                                for link in links["ref"] ?? [] {
                                    guard let name = link["$"] as? String else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Link with annotation uniqueID '\(uniqueID)' is missing name")
                                    }
                                    guard let paragraphAIDs = link["@pid"] as? String else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Link with annotation uniqueID '\(uniqueID)' is missing paragraphAIDs")
                                    }
                                    guard let docID = link["@docId"] as? String else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Link with annotation uniqueID '\(uniqueID)' is missing docId")
                                    }
                                    guard let docVersionString = link["@contentVersion"] as? String, let docVersion = Int(docVersionString) else {
                                        throw AnnotationError.errorWithCode(.syncDeserializationFailed, failureReason: "Link with annotation uniqueID '\(uniqueID)' is missing docVersion")
                                    }
                                    
                                    try self.annotationStore.addLink(name: name, docID: docID, docVersion: docVersion, paragraphAIDs: paragraphAIDs.components(separatedBy: ",").map { $0.trimmed() }, annotationID: annotationID, source: self.source)
                                    self.downloadLinkCount += 1
                                }
                            }
                            
                            // MARK: Tags
                            
                            // Remove any existings tags from the annotation and then we'll re-added what the server sends us
                            let tagIDs = tagsIDsByAnnotationID[annotationID] ?? []
                            for tagID in tagIDs {
                                try self.annotationStore.deleteTag(tagID: tagID, fromAnnotation: annotationID, source: self.source)
                            }
                            if let tags = rawAnnotation["tags"] as? [String: [String]] {
                                for tagName in tags["tag"] ?? [] {
                                    try self.annotationStore.addTag(name: tagName, annotationID: annotationID, source: self.source)
                                    self.downloadTagCount += 1
                                }
                            }
                            
                            self.downloadAnnotationCount += 1
                        case .trash, .delete:
                            if let existingAnnotationID = annotationByUniqueID[uniqueID]?.id {
                                // Don't store trashed or deleted annotations, just delete them from the db
                                try self.annotationStore.deleteAnnotationWithID(existingAnnotationID, source: self.source)
                            } else {
                                // If the annotation doesn't exist there's no need to delete it
                            }
                        }
                    }
                } catch let error as NSError where AnnotationError.Code(rawValue: error.code) == .syncDeserializationFailed {
                    deserializationErrors.append(error)
                }
            }
            
            try annotationStore.notifyModifiedAnnotationsWithIDs(changedAnnotationIDs, source: source)
            try annotationStore.notifyModifiedNotebooksWithIDs(changedNotebookIDs, source: source)
        }
        
        // Cleanup any annotations with the 'trashed' or 'deleted' status after they've been sync'ed successfully, there's no benefit to storing them locally anymore
        let annotationsToDelete = annotationStore.allAnnotations(lastModifiedOnOrBefore: onOrBefore).filter { $0.status != .active }
        for annotation in annotationsToDelete {
            try annotationStore.deleteAnnotationWithID(annotation.id, source: self.source)
        }
    }
    
}
