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

/// A highlight.
public struct Highlight {
    
    /// Local ID.
    public internal(set) var id: Int64?
    
    /// Paragraph Annotation ID
    public let paragraphAID: String
    
    /// The word offset that marks the start of this highlight range. It is one based, so zero is not allowed. A value of -1 means the beginning of the paragraph.
    public var offsetStart: Int
    
    /// The word offset that marks the end of this highlight range. It is one based, so zero is not allowed. A value of -1 means the end of the paragraph.
    public var offsetEnd: Int
    
    /// Color of the highlight
    public var colorName: String
    
    /// Highlight Style.
    public var style: HighlightStyle?
    
    /// ID of annotation
    public var annotationID: Int64
    
    init(id: Int64?, paragraphAID: String, offsetStart: Int, offsetEnd: Int, colorName: String, style: HighlightStyle?, annotationID: Int64) {
        self.id = id
        self.paragraphAID = paragraphAID
        self.offsetStart = offsetStart
        self.offsetEnd = offsetEnd
        self.colorName = colorName
        self.style = style
        self.annotationID = annotationID
    }
    
    init?(jsonObject: [String: AnyObject], annotationID: Int64) {
        guard let paragraphAID = jsonObject["@pid"] as? String, offsetStartString = jsonObject["@offset-start"] as? String, offsetStart = Int(offsetStartString), offsetEndString = jsonObject["@offset-end"] as? String, offsetEnd = Int(offsetEndString), colorName = jsonObject["@color"] as? String else {
            return nil
        }
        
        self.id = nil
        self.paragraphAID = paragraphAID
        self.offsetStart = offsetStart
        self.offsetEnd = offsetEnd
        self.colorName = colorName
        self.annotationID = annotationID
        
        if let rawStyle = jsonObject["@style"] as? String, style = HighlightStyle(rawValue: rawStyle) {
            self.style = style
        } else {
            self.style = .Highlight
        }
    }
    
    func jsonObject() -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            "@offset-start": offsetStart,
            "@offset-end": offsetEnd,
            "@color": colorName,
            "@pid": paragraphAID
        ]
        
        if let style = style where style == .Underline {
            result["@style"] = style.rawValue
        }
        
        return result
    }
    
}
