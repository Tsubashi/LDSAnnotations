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

class SetBox<T>: NSObject where T: Hashable {
    
    var set = Set<T>()
    
}

/// A local annotation store backed by a SQLite database.
public class AnnotationStore {
    
    private static let currentVersion = 1
    
    let db: Connection
    
    lazy var inSyncTransactionKey: String = {
        return "sync-txn:\(Unmanaged.passUnretained(self).toOpaque())"
    }()
    
    lazy var inLocalTransactionKey: String = {
        return "local-txn:\(Unmanaged.passUnretained(self).toOpaque())"
    }()
    
    private var changedAnnotationIDSetBox: SetBox<Int64> {
        set {
            Thread.current.threadDictionary["annotation-ids:\(Unmanaged.passUnretained(self).toOpaque())"] = newValue
        }
        get {
            return Thread.current.threadDictionary["annotation-ids:\(Unmanaged.passUnretained(self).toOpaque())"] as? SetBox<Int64> ?? SetBox()
        }
    }
    
    private var changedNotebookIDSetBox: SetBox<Int64> {
        set {
            Thread.current.threadDictionary["notebook-ids:\(Unmanaged.passUnretained(self).toOpaque())"] = newValue
        }
        get {
            return Thread.current.threadDictionary["notebook-ids:\(Unmanaged.passUnretained(self).toOpaque())"] as? SetBox<Int64> ?? SetBox()
        }
    }
    
    var changedNotebookIDs: Set<Int64> {
        set {
            let setBox = changedNotebookIDSetBox
            setBox.set.formUnion(newValue)
            changedNotebookIDSetBox = setBox
        }
        get {
            return changedNotebookIDSetBox.set
        }
    }
    
    var changedAnnotationIDs: Set<Int64> {
        set {
            let setBox = changedAnnotationIDSetBox
            setBox.set.formUnion(newValue)
            changedAnnotationIDSetBox = setBox
        }
        get {
            return changedAnnotationIDSetBox.set
        }
    }
    
    /// Constructs a local annotation store at `path`; if `path` is `nil` or empty, the annotation store is held in memory.
    ///
    /// Returns `nil` if a database connection to the annotation store cannot be opened.
    public init?(path: String? = nil) {
        do {
            db = try Connection(path ?? "")
            db.busyHandler { _ in
                // Keep retrying if database is locked
                return true
            }
            if databaseVersion < type(of: self).currentVersion {
                upgradeDatabase(fromVersion: databaseVersion)
            }
        } catch {
            return nil
        }
    }
    
    var databaseVersion: Int {
        get {
            do {
                return try Int(db.scalar("PRAGMA user_version") as? Int64 ?? 0)
            } catch {
                return 0
            }
        }
        set {
            do {
                try db.run("PRAGMA user_version = \(newValue)")
            } catch {}
        }
    }
    
    private func upgradeDatabase(fromVersion: Int) {
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
    public let notebookObservers = ObserverSet<(source: NotificationSource, notebookIDs: Set<Int64>)>()

    /// Registration point for notifications when notebooks are added, updated, trashed, and deleted.
    public let annotationObservers = ObserverSet<(source: NotificationSource, annotationIDs: Set<Int64>)>()
    
    /// Makes multiple queries or modifications in a single transaction.
    ///
    /// This method is reentrant.
    @discardableResult func inTransaction<T>(notificationSource source: NotificationSource, closure: @escaping (() throws -> T)) throws -> T {
        let inTransactionKey: String
        
        switch source {
        case .local:
            inTransactionKey = inLocalTransactionKey
            guard Thread.current.threadDictionary[inSyncTransactionKey] == nil else {
                throw AnnotationError.errorWithCode(.transactionError, failureReason: "A local transaction cannot be started in a sync transaction")
            }
        case .sync:
            inTransactionKey = inSyncTransactionKey
            guard Thread.current.threadDictionary[inLocalTransactionKey] == nil else {
                throw AnnotationError.errorWithCode(.transactionError, failureReason: "A sync transaction cannot be started in a local transaction")
            }
        }
        
        var element: T?
        if Thread.current.threadDictionary[inTransactionKey] != nil {
            element = try closure()
        } else {
            Thread.current.threadDictionary[inTransactionKey] = true
            defer {
                Thread.current.threadDictionary.removeObject(forKey: inTransactionKey)
            }
            
            try db.transaction {
                element = try closure()
            }
            
            // Batch notify about any notebooks modified in this transaction
            if !self.changedNotebookIDs.isEmpty {
                self.notebookObservers.notify((source: source, notebookIDs: self.changedNotebookIDs))
            }
            
            // Batch notify about any annotations modified in this transaction
            if !self.changedAnnotationIDs.isEmpty {
                self.annotationObservers.notify((source: source, annotationIDs: self.changedAnnotationIDs))
            }
        }
        
        if let element = element {
            return element
        }
        
        throw AnnotationError.errorWithCode(.transactionError, failureReason: "inTransaction has incorrect return type")
    }
    
}
