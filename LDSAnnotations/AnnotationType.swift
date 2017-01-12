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

import Foundation

public enum AnnotationType: Equatable {
    case link
    case linkDestination(Link)
    case multiple
    case note
    case notebook
    case tag
    
    public func isLinkDestination() -> Bool {
        if case .linkDestination = self {
            return true
        } else {
            return false
        }
    }
    
    public func accessibilityIdentifier() -> String {
        switch self {
        case .link:
            return "link"
        case .linkDestination:
            return "link destination"
        case .multiple:
            return "multiple"
        case .note:
            return "note"
        case .tag:
            return "tag"
        case .notebook:
            return "notebook"
        }
    }
    
}

public func ==(lhs: AnnotationType, rhs: AnnotationType) -> Bool {
    switch (lhs, rhs) {
    case (.link, .link), (.multiple, .multiple), (.note, .note), (.notebook, .notebook), (.tag, .tag):
        return true
    case let (.linkDestination(leftLink), .linkDestination(rightLink)):
        return leftLink == rightLink
    default:
        return false
    }
}
