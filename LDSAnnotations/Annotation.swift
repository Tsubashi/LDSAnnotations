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
public struct Annotation {
    
    /// Local ID.
    public internal(set) var id: Int64?
    
    /// Annotation Unique ID.
    public let uniqueID: String
    
    /// Document ID.
    public var docID: String
    
    /// Document version.
    public var docVersion: Int

    /// ISO639-3 Language Code.
    public var iso639_3Code: String

    /// Annotation Type.
    public var type: AnnotationType
    
    /// Whether the annotation is active, trashed, or deleted.
    public internal(set) var status: AnnotationStatus
    
    /// When the annotation was created in local time.
    public internal(set) var created: NSDate?

    /// When the annotation was last modified in local time.
    public internal(set) var lastModified: NSDate

    /// ID of associated note. This is a one-to-one relationship
    public var noteID: Int64?

    /// ID of associated bookmark. This is a one-to-one relationship
    public var bookmarkID: Int64?
    
    public var source: String?
    
    public var device: String?
    
    init(id: Int64?, uniqueID: String, iso639_3Code: String, docID: String, docVersion: Int, type: AnnotationType, status: AnnotationStatus, created: NSDate?, lastModified: NSDate, noteID: Int64?, bookmarkID: Int64?, source: String?, device: String?) {
        self.id = id
        self.uniqueID = uniqueID
        self.type = type
        self.iso639_3Code = iso639_3Code
        self.docID = docID
        self.docVersion = docVersion
        self.status = status
        self.created = created
        self.lastModified = lastModified
        self.noteID = noteID
        self.bookmarkID = bookmarkID
        self.source = source
        self.device = device
    }
    
    init?(jsonObject: [String: AnyObject]) {
        guard let uniqueID = jsonObject["@id"] as? String,
            type = jsonObject["@type"] as? String,
            annotationType = AnnotationType(rawValue: type),
            rawLastModified = jsonObject["timestamp"] as? String,
            lastModified = NSDate.parseFormattedISO8601(rawLastModified),
            docID = jsonObject["@docId"] as? String where !docID.isEmpty || (docID.isEmpty && annotationType == .Journal),
            let docVersionString = jsonObject["@contentVersion"] as? String,
            docVersion = Int(docVersionString) else {
                return nil
        }
        
        self.id = nil
        self.uniqueID = uniqueID
        self.type = annotationType
        self.lastModified = lastModified
        self.docID = docID
        self.docVersion = docVersion
        self.iso639_3Code = jsonObject["@locale"] as? String ?? "eng"
        self.source = jsonObject["source"] as? String
        self.device = jsonObject["device"] as? String
        self.created = (jsonObject["created"] as? String).flatMap { NSDate.parseFormattedISO8601($0) }
        self.status = (jsonObject["@status"] as? String).flatMap { AnnotationStatus(rawValue: $0) } ?? .Active
    }
    
    func jsonObject(annotationStore: AnnotationStore) -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            "@id": uniqueID,
            "@locale": iso639_3Code,
            "@type": type.rawValue,
            "timestamp": lastModified.formattedISO8601,
            "@docId": docID,
            "@contentVersion": docVersion
        ]
        
        if let created = created {
            result["created"] = created.formattedISO8601
        }
        if status != .Active {
            result["@status"] = status.rawValue
        }
        if let source = source {
            result["source"] = source
        }
        if let device = device {
            result["device"] = device
        }
        
        if let noteID = noteID, note = annotationStore.noteWithID(noteID) {
            result["note"] = note.jsonObject()
        }

        if let bookmarkID = bookmarkID, bookmark = annotationStore.bookmarkWithID(bookmarkID) {
            result["bookmark"] = bookmark.jsonObject()
        }
        
        if let id = id  {
            let highlights = annotationStore.highlightsWithAnnotationID(id)
            if !highlights.isEmpty {
                result["highlights"] = ["highlight": highlights.map({ $0.jsonObject() })]
            }
            
            let tags = annotationStore.tagsWithAnnotationID(id)
            if !tags.isEmpty {
                result["tags"] = ["tag": tags.map({ $0.jsonObject() })]
            }
            
            let links = annotationStore.linksWithAnnotationID(id)
            if !links.isEmpty {
                result["references"] = ["reference": links.map({ $0.jsonObject() })]
            }
            
            let notebooks = annotationStore.notebooksWithAnnotationID(id)
            if !notebooks.isEmpty {
                result["folders"] = ["folder": notebooks.map({ $0.annotationNotebookJsonObject() })]
            }
        }
        
        return result
    }
}
