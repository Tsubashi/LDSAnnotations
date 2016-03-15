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
import SQLite
import Swiftification

class SetBox<T where T: Hashable>: NSObject {
    
    var set = Set<T>()
    
}

/// A local annotation store backed by a SQLite database.
public class AnnotationStore {
    
    let db: Connection!
    
    private static let currentVersion = 1
    
    /// Constructs a local annotation store at `path`; if `path` is `nil` or empty, the annotation store is held in memory.
    ///
    /// Returns `nil` if a database connection to the annotation store cannot be opened.
    public init?(path: String? = nil) {
        db = try? Connection(path ?? "")
        if db == nil {
            return nil
        }
        
        if databaseVersion < self.dynamicType.currentVersion {
            upgradeDatabaseFromVersion(databaseVersion)
        }
    }
    
    var databaseVersion: Int {
        get {
            return Int(db.scalar("PRAGMA user_version") as? Int64 ?? 0)
        }
        set {
            do {
                try db.run("PRAGMA user_version = \(newValue)")
            } catch {}
        }
    }
    
    private func upgradeDatabaseFromVersion(fromVersion: Int) {
        if fromVersion < 1 {
            do {
                try db.transaction {
                    try self.createNotebookTable()
                    try self.createAnnotationTable()
                    try self.createHighlightTable()
                    try self.createTagTable()
                    try self.createNoteTable()
                    try self.createLinkTable()
                    try self.createBookmarkTable()
                    try self.createAnnotationTagTable()
                    try self.createAnnotationNotebookTable()
                    
                    self.databaseVersion = 1
                }
            } catch {}
        }
    }
    
    /// Registration point for notifications when notebooks are added, updated, trashed, and deleted.
    public let notebookObservers = ObserverSet<(source: NotificationSource, notebooks: [Notebook])>()

    /// Registration point for notifications when notebooks are added, updated, trashed, and deleted.
    public let annotationObservers = ObserverSet<(source: NotificationSource, annotations: [Annotation])>()
    
    /// Makes multiple queries or modifications in a single transaction.
    ///
    /// This method is reentrant.
    public func inTransaction(closure: () throws -> Void) throws {
        let inSyncTransactionKey = "sync-txn:\(unsafeAddressOf(self))"
        guard NSThread.currentThread().threadDictionary[inSyncTransactionKey] == nil else {
            fatalError("A local transaction cannot be started in a sync transaction")
        }
        
        let inTransactionKey = "txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[inTransactionKey] != nil {
            try closure()
        } else {
            NSThread.currentThread().threadDictionary[inTransactionKey] = true
            defer { NSThread.currentThread().threadDictionary.removeObjectForKey(inTransactionKey) }
            try db.transaction {
                try closure()
                
                // Batch notify about any notebooks modified in this transaction
                let notebookIDsKey = "notebookIDs:\(unsafeAddressOf(self))"
                if let notebookIDs = NSThread.currentThread().threadDictionary[notebookIDsKey] as? SetBox<Int64> {
                    self.notebookObservers.notify((source: .Local, notebooks: self.allNotebooks(ids: Array(notebookIDs.set))))
                }
                
                // Batch notify about any annotations modified in this transaction
                let annotationIDsKey = "annotationIDs:\(unsafeAddressOf(self))"
                if let annotationIDs = NSThread.currentThread().threadDictionary[annotationIDsKey] as? SetBox<Int64> {
                    self.annotationObservers.notify((source: .Local, annotations: self.allAnnotations(ids: Array(annotationIDs.set))))
                }
            }
        }
    }
    
    func inSyncTransaction(closure: () throws -> Void) throws {
        let inTransactionKey = "txn:\(unsafeAddressOf(self))"
        guard NSThread.currentThread().threadDictionary[inTransactionKey] == nil else {
            fatalError("A sync transaction cannot be started in a local transaction")
        }
        
        let inSyncTransactionKey = "sync-txn:\(unsafeAddressOf(self))"
        if NSThread.currentThread().threadDictionary[inSyncTransactionKey] != nil {
            try closure()
        } else {
            NSThread.currentThread().threadDictionary[inSyncTransactionKey] = true
            defer { NSThread.currentThread().threadDictionary[inSyncTransactionKey] = false }
            try db.transaction {
                try closure()
                
                // Batch notify about any notebooks modified in this transaction
                let notebookIDsKey = "notebookIDs:\(unsafeAddressOf(self))"
                if let notebookIDs = NSThread.currentThread().threadDictionary[notebookIDsKey] as? SetBox<Int64> {
                    self.notebookObservers.notify((source: .Sync, notebooks: self.allNotebooks(ids: Array(notebookIDs.set))))
                }
                
                // Batch notify about any annotations modified in this transaction
                let annotationIDsKey = "annotationIDs:\(unsafeAddressOf(self))"
                if let annotationIDs = NSThread.currentThread().threadDictionary[annotationIDsKey] as? SetBox<Int64> {
                    self.annotationObservers.notify((source: .Sync, annotations: self.allAnnotations(ids: Array(annotationIDs.set))))
                }
            }
        }
    }

    
}
