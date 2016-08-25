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

/// An annotation.
public struct Annotation: Equatable {
    
    /// Local ID.
    public internal(set) var id: Int64
    
    /// Annotation Unique ID.
    public let uniqueID: String
    
    /// Document ID.
    public var docID: String?
    
    /// Document version.
    public var docVersion: Int?

    /// Whether the annotation is active, trashed, or deleted.
    public internal(set) var status: AnnotationStatus
    
    /// When the annotation was created in local time.
    public internal(set) var created: NSDate?

    /// When the annotation was last modified in local time.
    public internal(set) var lastModified: NSDate

    public var appSource: String?
    
    public var device: String?
    
    init(id: Int64, uniqueID: String, docID: String?, docVersion: Int?, status: AnnotationStatus, created: NSDate?, lastModified: NSDate, appSource: String?, device: String?) {
        self.id = id
        self.uniqueID = uniqueID
        self.docID = docID
        self.docVersion = docVersion
        self.status = status
        self.created = created
        self.lastModified = lastModified
        self.appSource = appSource
        self.device = device
    }
    
    func jsonObject(annotationStore: AnnotationStore) -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            "@id": uniqueID,
            "timestamp": lastModified.formattedISO8601
        ]
        
        if let docID = docID {
            result["@docId"] = docID
        }
        if let docVersion = docVersion {
            result["@contentVersion"] = docVersion
        }
        if status != .Active {
            result["@status"] = status.rawValue
        }
        if let created = created {
            result["created"] = created.formattedISO8601
        }
        if let appSource = appSource {
            result["source"] = appSource
        }
        if let device = device {
            result["device"] = device
        }
        
        if let note = annotationStore.noteWithAnnotationID(id) {
            result["note"] = note.jsonObject()
        }

        // Derive the annotation type, this is a required field
        var type: AnnotationType = .Journal
        
        if let bookmark = annotationStore.bookmarkWithAnnotationID(id) {
            // If the annotation has a bookmark, it should never have highlights, tags, links, etc
            type = .Bookmark
            result["bookmark"] = bookmark.jsonObject()
        } else {
            let notebooks = annotationStore.notebooksWithAnnotationID(id)
            if !notebooks.isEmpty {
                result["folders"] = ["folder": notebooks.map({ $0.annotationNotebookJsonObject() })]
            }
            
            let highlights = annotationStore.highlightsWithAnnotationID(id)
            if !highlights.isEmpty {
                result["highlights"] = ["highlight": highlights.map({ $0.jsonObject() })]
                type = .Highlight
            }
            
            let tags = annotationStore.tagsWithAnnotationID(id)
            if !tags.isEmpty {
                result["tags"] = ["tag": tags.map({ $0.jsonObject() })]
            }
            
            let links = annotationStore.linksWithAnnotationID(id)
            if !links.isEmpty {
                result["refs"] = ["ref": links.map({ $0.jsonObject() })]
                type = .Link // If there are 1 or more links, it MUST be a .Link type
            }
        }
        
        result["@type"] = type.rawValue
        
        return result
    }
}

extension Annotation: Hashable {
    
    public var hashValue: Int {
        return id.hashValue ^ uniqueID.hashValue ^ (docID ?? "").hashValue ^ (docVersion ?? 0).hashValue ^ status.hashValue ^ lastModified.hashValue
    }
    
}

public func == (lhs: Annotation, rhs: Annotation) -> Bool {
    return lhs.id == rhs.id
        && lhs.uniqueID == rhs.uniqueID
        && lhs.docID == rhs.docID
        && lhs.docVersion == rhs.docVersion
        && lhs.status == rhs.status
        && lhs.created == rhs.created
        && lhs.lastModified == rhs.lastModified
        && lhs.appSource == rhs.appSource
        && lhs.device == rhs.device
}

private enum AnnotationType: String {

    case Bookmark = "bookmark"
    case Highlight = "highlight"
    case Journal = "journal"
    case Link = "reference"
    
}

