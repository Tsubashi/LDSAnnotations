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
    public internal(set) var id: Int64?
    
    /// Annotation Unique ID.
    public let uniqueID: String
    
    /// Document ID.
    public var docID: String?
    
    /// Document version.
    public var docVersion: Int?

    /// ISO639-3 Language Code.
    public var iso639_3Code: String

    /// Whether the annotation is active, trashed, or deleted.
    public internal(set) var status: AnnotationStatus
    
    /// When the annotation was created in local time.
    public internal(set) var created: NSDate?

    /// When the annotation was last modified in local time.
    public internal(set) var lastModified: NSDate

    public var source: String?
    
    public var device: String?
    
    init(id: Int64?, uniqueID: String, iso639_3Code: String, docID: String?, docVersion: Int?, status: AnnotationStatus, created: NSDate?, lastModified: NSDate, source: String?, device: String?) {
        self.id = id
        self.uniqueID = uniqueID
        self.iso639_3Code = iso639_3Code
        self.docID = docID
        self.docVersion = docVersion
        self.status = status
        self.created = created
        self.lastModified = lastModified
        self.source = source
        self.device = device
    }
    
    init?(jsonObject: [String: AnyObject]) {
        guard let uniqueID = jsonObject["@id"] as? String, rawLastModified = jsonObject["timestamp"] as? String, lastModified = NSDate.parseFormattedISO8601(rawLastModified) else { return nil }
        
        self.id = nil
        self.uniqueID = uniqueID
        self.lastModified = lastModified
        self.iso639_3Code = jsonObject["@locale"] as? String ?? "eng"
        self.source = jsonObject["source"] as? String
        self.device = jsonObject["device"] as? String
        self.docID = jsonObject["@docId"] as? String
        self.docVersion = (jsonObject["@contentVersion"] as? String).flatMap { Int($0) }
        self.created = (jsonObject["created"] as? String).flatMap { NSDate.parseFormattedISO8601($0) }
        self.status = (jsonObject["@status"] as? String).flatMap { AnnotationStatus(rawValue: $0) } ?? .Active
    }
    
    func jsonObject(annotationStore: AnnotationStore) -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            "@id": uniqueID,
            "@locale": iso639_3Code,
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
        if let source = source {
            result["source"] = source
        }
        if let device = device {
            result["device"] = device
        }
        
        if let id = id, note = annotationStore.noteWithAnnotationID(id) {
            result["note"] = note.jsonObject()
        }

        // Derive the annotation type
        var type: AnnotationType?
        
        if let id = id, bookmark = annotationStore.bookmarkWithAnnotationID(id) {
            type = .Bookmark
            result["bookmark"] = bookmark.jsonObject()
        }
        
        if let id = id  {
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
            
            let notebooks = annotationStore.notebooksWithAnnotationID(id)
            if !notebooks.isEmpty {
                result["folders"] = ["folder": notebooks.map({ $0.annotationNotebookJsonObject() })]
                type = .Journal
            }
        }
        
        if let type = type {
            result["@type"] = type.rawValue
        }
        
        return result
    }
}

extension Annotation: Hashable {
    
    public var hashValue: Int {
        return id?.hashValue ?? 0 ^ uniqueID.hashValue ^ iso639_3Code.hashValue ^ (docID ?? "").hashValue ^ (docVersion ?? 0).hashValue ^ status.hashValue ^ lastModified.hashValue
    }
    
}

public func == (lhs: Annotation, rhs: Annotation) -> Bool {
    return lhs.id == rhs.id
        && lhs.uniqueID == rhs.uniqueID
        && lhs.iso639_3Code == rhs.iso639_3Code
        && lhs.docID == rhs.docID
        && lhs.docVersion == rhs.docVersion
        && lhs.status == rhs.status
        && lhs.created == rhs.created
        && lhs.lastModified == rhs.lastModified
        && lhs.source == rhs.source
        && lhs.device == rhs.device
}

private enum AnnotationType: String {

    case Bookmark = "bookmark"
    case Highlight = "highlight"
    case Journal = "journal"
    case Link = "reference"
    
}

