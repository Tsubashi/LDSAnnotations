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

/// A Link.
public struct Link {

    /// Local ID.
    public internal(set) var id: Int64?

    public var name: String
    
    /// Destination Doc ID
    public var docID: String

    /// Destination Doc Version
    public var docVersion: Int
    
    /// ID of annotation
    public var annotationID: Int64
    
    /// Destination Paragraph Annotation IDs
    public var paragraphAIDs: [String]

    init(id: Int64?, name: String, docID: String, docVersion: Int, paragraphAIDs: [String], annotationID: Int64) {
        self.id = id
        self.name = name
        self.docID = docID
        self.docVersion = docVersion
        self.paragraphAIDs = paragraphAIDs
        self.annotationID = annotationID
    }
    
    init(jsonObject: [String: AnyObject], annotationID: Int64) throws {
        guard let name = jsonObject["$"] as? String, docID = jsonObject["@docId"] as? String, docVersionString = jsonObject["@contentVersion"] as? String, docVersion = Int(docVersionString) else {
            throw Error.errorWithCode(.InvalidHighlight, failureReason: "Failed to deserialize highlight: \(jsonObject)")
        }
        
        guard let paragraphAIDs = jsonObject["@pid"] as? String else {
            throw Error.errorWithCode(.InvalidParagraphAID, failureReason: "Failed to deserialize link, missing PID: \(jsonObject)")
        }
        
        self.id = nil
        self.name = name
        self.docID = docID
        self.docVersion = docVersion
        self.paragraphAIDs = paragraphAIDs.componentsSeparatedByString(",").map { $0.stringByTrimmingCharactersInSet(.whitespaceCharacterSet()) }
        self.annotationID = annotationID
    }
    
    func jsonObject() -> [String: AnyObject] {
        return [
            "$": name,
            "@docId": docID,
            "@contentVersion":  docVersion,
            "@pid": paragraphAIDs.joinWithSeparator(",")
        ]
    }
    
}
