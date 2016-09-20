//
//  SyncOperation.swift
//  LDSAnnotations
//
//  Created by Nick Shelley on 9/9/16.
//  Copyright © 2016 Hilton Campbell. All rights reserved.
//

import Foundation
import Operations

class SyncOperation: GroupOperation {
    
    init(session: Session, annotationStore: AnnotationStore, token: SyncToken?, completion: (SyncResult) -> Void) {
        let syncNotebooks = SyncNotebooksOperation(session: session, annotationStore: annotationStore, localSyncNotebooksDate: token?.localSyncNotebooksDate, serverSyncNotebooksDate: token?.serverSyncNotebooksDate)
        let syncAnnotations = SyncAnnotationsOperation(session: session, annotationStore: annotationStore, localSyncAnnotationsDate: token?.localSyncAnnotationsDate, serverSyncAnnotationsDate: token?.serverSyncAnnotationsDate) { syncAnnotationsResult in
            switch syncAnnotationsResult {
            case let .Success(notebooksResult: notebooksResult, localSyncAnnotationsDate: localSyncAnnotationsDate, serverSyncAnnotationsDate: serverSyncAnnotationsDate, changes: syncAnnotationsChanges, deserializationErrors: syncAnnotationsDeserializationErrors):
                let token = SyncToken(localSyncNotebooksDate: notebooksResult.localSyncNotebooksDate, serverSyncNotebooksDate: notebooksResult.serverSyncNotebooksDate, localSyncAnnotationsDate: localSyncAnnotationsDate, serverSyncAnnotationsDate: serverSyncAnnotationsDate)
                let changes = SyncChanges(
                    uploadedNotebooks: notebooksResult.changes.uploadedNotebooks,
                    uploadAnnotationCount: syncAnnotationsChanges.uploadAnnotationCount,
                    uploadNoteCount: syncAnnotationsChanges.uploadNoteCount,
                    uploadBookmarkCount: syncAnnotationsChanges.uploadBookmarkCount,
                    uploadHighlightCount: syncAnnotationsChanges.uploadHighlightCount,
                    uploadTagCount: syncAnnotationsChanges.uploadTagCount,
                    uploadLinkCount: syncAnnotationsChanges.uploadLinkCount,
                    downloadedNotebooks: notebooksResult.changes.downloadedNotebooks,
                    downloadAnnotationCount: syncAnnotationsChanges.downloadAnnotationCount,
                    downloadNoteCount: syncAnnotationsChanges.downloadNoteCount,
                    downloadBookmarkCount: syncAnnotationsChanges.downloadBookmarkCount,
                    downloadHighlightCount: syncAnnotationsChanges.downloadHighlightCount,
                    downloadTagCount: syncAnnotationsChanges.downloadTagCount,
                    downloadLinkCount: syncAnnotationsChanges.downloadLinkCount)
                completion(SyncResult.Success(token: token, changes: changes, deserializationErrors: (notebooksResult.deserializationErrors + syncAnnotationsDeserializationErrors)))
            case let .Error(errors: errors):
                completion(SyncResult.Error(errors: errors))
            }
            
            // The annotation service team asked that we have a grace period between syncs. Just sleeping at the end of this mutually exclusive operation provides that functionality without holding anything else up (since the completions have already been called)
            NSThread.sleepForTimeInterval(5)
        }
        
        syncAnnotations.injectResultFromDependency(syncNotebooks)
        
        super.init(operations: [syncNotebooks, syncAnnotations])
        
        name = "Sync"
        
        addCondition(MutuallyExclusive<SyncOperation>())
    }
    
}
