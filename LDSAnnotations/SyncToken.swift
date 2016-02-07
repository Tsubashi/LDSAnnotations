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

/// Token which is returned from a successful sync and should be used for the next sync.
public struct SyncToken {
    
    let localSyncDate: NSDate
    let serverSyncDate: NSDate
    
    /// Constructs a token from an encoded string.
    public init?(rawValue: String) {
        let scanner = NSScanner(string: rawValue)
        
        if !scanner.scanString("1:", intoString: nil) {
            return nil
        }
        
        var localSyncTimeInterval: Double = 0
        if !scanner.scanDouble(&localSyncTimeInterval) {
            return nil
        }
        localSyncDate = NSDate(timeIntervalSince1970: localSyncTimeInterval)
        
        if !scanner.scanString(":", intoString: nil) {
            return nil
        }
        
        var serverSyncTimeInterval: Double = 0
        if !scanner.scanDouble(&serverSyncTimeInterval) {
            return nil
        }
        serverSyncDate = NSDate(timeIntervalSince1970: serverSyncTimeInterval)
    }
    
    init(localSyncDate: NSDate, serverSyncDate: NSDate) {
        self.localSyncDate = localSyncDate
        self.serverSyncDate = serverSyncDate
    }
    
    /// An encoded value which can be persisted.
    public var rawValue: String {
        return "1:\(localSyncDate.timeIntervalSince1970):\(serverSyncDate.timeIntervalSince1970)"
    }
    
}
