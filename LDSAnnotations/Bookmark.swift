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
public struct Bookmark: Equatable {
    
    /// Local ID.
    public internal(set) var id: Int64?
    
    /// The name.
    public var name: String?
    
    /// Paragraph Annotation ID.
    public var paragraphAID: String?
    
    /// Display order.
    public internal(set) var displayOrder: Int?
    
    /// ID of annotation.
    public var annotationID: Int64
    
    /// The zero-based word offset of this bookmark location.
    public internal(set) var offset: Int
    
    init(id: Int64?, name: String?, paragraphAID: String?, displayOrder: Int?, annotationID: Int64, offset: Int) {
        self.id = id
        self.name = name
        self.paragraphAID = paragraphAID
        self.displayOrder = displayOrder
        self.annotationID = annotationID
        self.offset = offset
    }
    
    init?(jsonObject: [String: AnyObject], annotationID: Int64) {
        if jsonObject["@pid"] == nil && jsonObject["uri"] != nil {
            // Bookmark has a URI, but no @pid so its invalid
            return nil
        }
        
        self.id = nil
        self.name = jsonObject["name"] as? String
        self.paragraphAID = jsonObject["@pid"] as? String
        self.displayOrder = jsonObject["sort"] as? Int
        self.annotationID = annotationID
        
        if let offset = jsonObject["@offset"] as? Int where offset >= 1 {
            self.offset = offset - 1
        } else {
            self.offset = 0
        }
    }
    
    func jsonObject() -> [String: AnyObject] {
        var result = [String: AnyObject]()
        
        if offset <= 0 {
            result["@offset"] = -1
        } else {
            result["@offset"] = offset + 1
        }
        
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

public func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
    return lhs.id == rhs.id
        && lhs.name == rhs.name
        && lhs.paragraphAID == rhs.paragraphAID
        && lhs.displayOrder == rhs.displayOrder
        && lhs.annotationID == rhs.annotationID
        && lhs.offset == rhs.offset
}
