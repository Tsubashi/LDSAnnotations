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
import Swiftification

/// Token which is returned from a successful sync and should be used for the next sync.
public struct SyncToken {
    
    let localSyncNotebooksDate: Date
    let serverSyncNotebooksDate: Date
    let localSyncAnnotationsDate: Date
    let serverSyncAnnotationsDate: Date
    
    /// Constructs a token from an encoded string.
    public init?(rawValue: String) {
        let scanner = Scanner(string: rawValue)
        
        if !scanner.scanString("1:", into: nil) {
            return nil
        }
        
        var localSyncNotebooksTimeInterval: Double = 0
        if !scanner.scanDouble(&localSyncNotebooksTimeInterval) {
            return nil
        }
        localSyncNotebooksDate = Date(timeIntervalSince1970: localSyncNotebooksTimeInterval)
        
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        
        var serverSyncNotebooksTimeInterval: Double = 0
        if !scanner.scanDouble(&serverSyncNotebooksTimeInterval) {
            return nil
        }
        serverSyncNotebooksDate = Date(timeIntervalSince1970: serverSyncNotebooksTimeInterval)
        
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        
        var localSyncAnnotationsTimeInterval: Double = 0
        if !scanner.scanDouble(&localSyncAnnotationsTimeInterval) {
            return nil
        }
        localSyncAnnotationsDate = Date(timeIntervalSince1970: localSyncAnnotationsTimeInterval)
        
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        
        var serverSyncAnnotationsTimeInterval: Double = 0
        if !scanner.scanDouble(&serverSyncAnnotationsTimeInterval) {
            return nil
        }
        serverSyncAnnotationsDate = Date(timeIntervalSince1970: serverSyncAnnotationsTimeInterval)
    }
    
    init(localSyncNotebooksDate: Date, serverSyncNotebooksDate: Date, localSyncAnnotationsDate: Date, serverSyncAnnotationsDate: Date) {
        self.localSyncNotebooksDate = localSyncNotebooksDate
        self.serverSyncNotebooksDate = serverSyncNotebooksDate
        self.localSyncAnnotationsDate = localSyncAnnotationsDate
        self.serverSyncAnnotationsDate = serverSyncAnnotationsDate
    }
    
    /// An encoded value which can be persisted.
    public var rawValue: String {
        return "1:\(localSyncNotebooksDate.timeIntervalSince1970):\(serverSyncNotebooksDate.timeIntervalSince1970):\(localSyncAnnotationsDate.timeIntervalSince1970):\(serverSyncAnnotationsDate.timeIntervalSince1970)"
    }
    
    /// Last sync date
    public var lastLocalSyncDate: Date {
        return localSyncNotebooksDate > localSyncAnnotationsDate ? localSyncNotebooksDate : localSyncAnnotationsDate
    }
    
}
