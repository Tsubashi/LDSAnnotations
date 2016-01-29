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

/// A notebook.
public struct Notebook {

    /// Local ID.
    public internal(set) var id: Int64?
    
    /// Display name.
    public var name: String
    
    /// Whether the notebook is active, trashed, or deleted.
    public internal(set) var status: AnnotationStatus
    
    /// When the notebook was last modified in local time.
    public internal(set) var lastModified: NSDate
    
    var uniqueID: String
    var description: String?
    
    init(id: Int64?, uniqueID: String, name: String, description: String?, status: AnnotationStatus, lastModified: NSDate) {
        self.id = id
        self.uniqueID = uniqueID
        self.name = name
        self.description = description
        self.status = status
        self.lastModified = lastModified
    }
    
    init?(jsonObject: [String: AnyObject]) {
        guard let uniqueID = jsonObject["@guid"] as? String, name = jsonObject["label"] as? String, rawLastModified = jsonObject["timestamp"] as? String, lastModified = NSDate.parseFormattedISO8601(rawLastModified) else {
            return nil
        }
        
        self.id = nil
        self.uniqueID = uniqueID
        self.name = name
        self.lastModified = lastModified
        
        if let description = jsonObject["desc"] as? String {
            self.description = description
        } else {
            self.description = nil
        }
        
        if let rawStatus = jsonObject["status"] as? String, status = AnnotationStatus(rawValue: rawStatus) {
            self.status = status
        } else {
            self.status = .Active
        }
    }
    
    func jsonObject() -> [String: AnyObject] {
        var result = [
            "@guid": uniqueID,
            "label": name,
            "timestamp": lastModified.formattedISO8601,
            "status": status.rawValue,
        ]
        
        if let description = description {
            result["desc"] = description
        }
        
        return result
    }

}
