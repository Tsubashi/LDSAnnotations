//
//  HighlightColor.swift
//  LDSAnnotations
//
//  Created by Stephan Heilner on 2/28/17.
//  Copyright © 2017 Hilton Campbell. All rights reserved.
//

import Foundation
import SQLite

public enum HighlightColor: String {

    public static let `default`: HighlightColor = .yellow
    
    case yellow = "yellow"
    case red = "red"
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case pink = "pink"
    case gray = "gray"
    case brown = "brown"
    case darkBlue = "dark_blue"
    case clear = "clear"
    
    static func highlightColor(from string: String) -> HighlightColor? {
        let colorString = string.lowercased()
        
        if let highlightColor = HighlightColor(rawValue: colorString) {
            return highlightColor
        }
        
        // Old Gospel Library 2.x color values
        let gospelLibraryColors: [String: HighlightColor] = [
            "fff8aa": .yellow,
            "ffc2e9": .pink,
            "aaf6ff": .blue,
            "d6ffaa": .green,
            "clear": .clear
        ]
        
        if let highlightColor = gospelLibraryColors[colorString] {
            return highlightColor
        }
        
        // Old Gospel Library 3.x color values
        let legacyColors: [String: HighlightColor] = [
            "fff200": .yellow,
            "ed1b24": .red,
            "00aeef": .blue,
            "8dc63f": .green,
            "8560a8": .purple,
            "ff6a0f": .orange,
            "f49ac1": .pink,
            "b7b7b7": .gray,
            "c69c6d": .brown,
            "0054a6": .darkBlue
        ]
        
        if let highlightColor = legacyColors[colorString] {
            return highlightColor
        }
        
        return nil
    }
    
}

extension HighlightColor: Value {
    
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    
    public static func fromDatatypeValue(_ stringValue: String) -> HighlightColor {
        return HighlightColor(rawValue: stringValue) ?? .default
    }
    
    public var datatypeValue: String {
        return rawValue
    }
    
}
