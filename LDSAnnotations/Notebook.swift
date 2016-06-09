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
public class Notebook {

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
        self.description = jsonObject["desc"] as? String
        self.status = (jsonObject["@status"] as? String).flatMap { AnnotationStatus(rawValue: $0) } ?? .Active
    }
    
    func jsonObject(annotationStore: AnnotationStore) -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            "@guid": uniqueID,
            "label": name,
            "timestamp": lastModified.formattedISO8601,
        ]
        
        if let description = description {
            result["desc"] = description
        }
        if status != .Active {
            result["@status"] = status.rawValue
        }
        
        if let id = id {
            let annotations = annotationStore.annotationsWithNotebookID(id)
            if !annotations.isEmpty {
                result["order"] = ["id": annotations.map { $0.uniqueID }]
            }
        }
        
        return result
    }
    
    func annotationNotebookJsonObject() -> [String: AnyObject] {
        // The Annotation Service requires we send a URI with the @guid in it in the format below. The 'x' used to be the person-id value, but the service automatically populates that  now, so we just put a placeholder there instead.
        return ["@uri": String(format: "/study-tools/folders/x/%@", uniqueID)]
    }

}
