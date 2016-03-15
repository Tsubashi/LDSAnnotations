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

/// A Bookmark.
public struct Bookmark {
    
    /// Local ID.
    public internal(set) var id: Int64?
    
    /// Name
    public var name: String?
    
    /// Paragraph Annotation ID
    public var paragraphAID: String?
    
    /// Display order
    public internal(set) var displayOrder: Int?
    
    /// ID of annotation
    public var annotationID: Int64
    
    /// The word offset that marks the word for this bookmark. It is one based, so zero is not allowed. A value of -1 means the beginning of the paragraph.
    public internal(set) var offset: Int?
    
    init(id: Int64?, name: String?, paragraphAID: String?, displayOrder: Int?, annotationID: Int64) {
        self.id = id
        self.name = name
        self.paragraphAID = paragraphAID
        self.displayOrder = displayOrder
        self.annotationID = annotationID
    }
    
    init?(jsonObject: [String: AnyObject], annotationID: Int64) {
        guard let name = jsonObject["name"] as? String else { return nil }
        
        self.id = nil
        self.name = name
        self.annotationID = annotationID
        
        if let offset = jsonObject["@offset"] as? Int {
            self.offset = offset
        } else {
            self.offset = nil
        }
        
        if let displayOrder = jsonObject["sort"] as? Int {
            self.displayOrder = displayOrder
        } else {
            self.displayOrder = nil
        }
    }
    
    func jsonObject() -> [String: AnyObject] {
        var result: [String: AnyObject] = ["@offset": offset ?? -1]
        
        if let name = name {
            result["name"] = name
        }
        if let paragraphAID = paragraphAID {
            result["@pid"] = paragraphAID
        }
        if let displayOrder = displayOrder {
            result["sort"] = displayOrder
        }
        
        return result
    }
    
}
