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
import SQLite

/// The status of an annotation.
public enum AnnotationStatus: String {
    
    /// An active annotation.
    case active = ""
    
    /// A trashed annotation is not normally shown to the user, but can still be accessed. A trashed annotation can become active again.
    case trashed = "trashed"
    
    /// A deleted annotation is considered annihilated.
    case deleted = "deleted"

}

extension AnnotationStatus: Value {
    
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    
    public static func fromDatatypeValue(_ stringValue: String) -> AnnotationStatus {
        return AnnotationStatus(rawValue: stringValue) ?? .active
    }
    
    public var datatypeValue: String {
        return rawValue
    }
    
}
