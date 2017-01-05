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
public struct Highlight: Equatable {
    
    /// Local ID.
    public internal(set) var id: Int64

    /// Paragraph Range (AID, start & end word offsets)
    public let paragraphRange: ParagraphRange
    
    /// Color of the highlight.
    public var colorName: String
    
    /// Highlight Style.
    public var style: HighlightStyle
    
    /// ID of annotation.
    public var annotationID: Int64
    
    public init(id: Int64, paragraphRange: ParagraphRange, colorName: String, style: HighlightStyle?, annotationID: Int64) {
        self.id = id
        self.paragraphRange = paragraphRange
        self.colorName = colorName
        self.style = style ?? .highlight
        self.annotationID = annotationID
    }
    
    func jsonObject() -> [String: Any] {
        var result: [String: Any] = [
            "@color": colorName,
            "@pid": paragraphRange.paragraphAID,
        ]
        
        result["@offset-start"] = paragraphRange.startWordOffset
        result["@offset-end"] = paragraphRange.endWordOffset ?? -1
        
        if style == .underline || style == .clear {
            result["@style"] = style.rawValue
        }
        
        return result
    }
    
}

extension Highlight: Hashable {
    
    public var hashValue: Int {
        return id.hashValue
            ^ paragraphRange.hashValue
            ^ colorName.hashValue
            ^ style.rawValue.hashValue
            ^ annotationID.hashValue
    }
    
}

public func == (lhs: Highlight, rhs: Highlight) -> Bool {
    return lhs.id == rhs.id
        && lhs.paragraphRange == rhs.paragraphRange
        && lhs.colorName == rhs.colorName
        && lhs.style == rhs.style
        && lhs.annotationID == rhs.annotationID
}
