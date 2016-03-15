//
//  HighlightStyle.swift
//  LDSAnnotations
//
//  Created by Stephan Heilner on 3/14/16.
//  Copyright © 2016 Hilton Campbell. All rights reserved.
//

import Foundation
import SQLite

/// The style of a highlight.
public enum HighlightStyle: String {
    
    /// Plain block highlight style
    case Highlight = ""
    
    /// Underline style
    case Underline = "red-underline"
    
}

extension HighlightStyle: Value {
    
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    
    public static func fromDatatypeValue(stringValue: String) -> HighlightStyle {
        return HighlightStyle(rawValue: stringValue) ?? .Highlight
    }
    
    public var datatypeValue: String {
        return rawValue
    }
    
}

