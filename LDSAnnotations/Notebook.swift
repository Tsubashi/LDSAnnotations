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
public struct Notebook: Equatable {

    /// Local ID.
    public internal(set) var id: Int64
    
    /// Display name.
    public var name: String
    
    /// Whether the notebook is active, trashed, or deleted.
    public internal(set) var status: AnnotationStatus
    
    /// When the notebook was last modified in local time.
    public internal(set) var lastModified: Date
    
    /// Unique Identifier for a notebook across devices
    public var uniqueID: String
    
    var description: String?
    
    init(id: Int64, uniqueID: String, name: String, description: String?, status: AnnotationStatus, lastModified: Date) {
        self.id = id
        self.uniqueID = uniqueID
        self.name = name
        self.description = description
        self.status = status
        self.lastModified = lastModified
    }
    
    func jsonObject(_ annotationStore: AnnotationStore) -> [String: Any] {
        var result: [String: Any] = [
            "@guid": uniqueID,
            "label": name,
            "timestamp": lastModified.formattedISO8601,
        ]
        
        if let description = description {
            result["desc"] = description
        }
        if status != .active {
            result["@status"] = status.rawValue
        }
        
        let annotations = annotationStore.annotationsWithNotebookID(id)
        if !annotations.isEmpty {
            result["order"] = ["id": annotations.map { $0.uniqueID }]
        }
        
        return result
    }
    
    func annotationNotebookJsonObject() -> [String: Any] {
        // The Annotation Service requires we send a URI with the @guid in it in the format below. The 'x' used to be the person-id value, but the service automatically populates that  now, so we just put a placeholder there instead.
        return ["@uri": String(format: "/study-tools/folders/x/%@", uniqueID)]
    }

}

public func == (lhs: Notebook, rhs: Notebook) -> Bool {
    return lhs.id == rhs.id
        && lhs.uniqueID == rhs.uniqueID
        && lhs.name == rhs.name
        && lhs.description == rhs.description
        && lhs.status == rhs.status
        && lhs.lastModified == rhs.lastModified
}
