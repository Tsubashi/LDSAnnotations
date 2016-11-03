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

/// A note.
public struct Note: Equatable {
    
    public static let MaxLength = 20000
    
    /// Local ID.
    public internal(set) var id: Int64
    
    /// Note title
    public var title: String?
    
    /// Note content
    public var content: String
    
    /// ID of annotation
    public var annotationID: Int64
    
    init(id: Int64, title: String?, content: String, annotationID: Int64) {
        self.id = id
        self.title = title
        self.content = content
        self.annotationID = annotationID
    }
    
    func jsonObject() -> [String: Any] {
        var result = ["content": content]
        if let title = title {
            result["title"] = title
        }
        return result
    }
    
}

public func == (lhs: Note, rhs: Note) -> Bool {
    return lhs.id == rhs.id
        && lhs.title == rhs.title
        && lhs.content == rhs.content
        && lhs.annotationID == rhs.annotationID
}
