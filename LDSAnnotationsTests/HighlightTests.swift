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

import XCTest
@testable import LDSAnnotations
import Swiftification

class HighlightTests: XCTestCase {
    
    func testHighlightMissingPID() {
        let input = [
            "@offset-start": "3",
            "@offset-end": "7",
            "@color": "yellow",
        ]
        do {
            let _ = try Highlight(jsonObject: input, annotationID: 1)
            XCTFail("Expected an error")
        } catch let error as NSError where Error.Code(rawValue: error.code) == .InvalidParagraphAID {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testHighlightWithOffset() {
        let input = [
            "@offset-start": "3",
            "@offset-end": "7",
            "@pid": "20527924",
            "@color": "yellow",
        ]
        let expected = Highlight(id: nil, paragraphAID: "20527924", offsetStart: 2, offsetEnd: 6, colorName: "yellow", style: .Highlight, annotationID: 1)
        let actual = try! Highlight(jsonObject: input, annotationID: 1)
        XCTAssertEqual(actual, expected)
        let output = actual.jsonObject() as! [String: NSObject]
        XCTAssertEqual(output, expectedOutputFromInput(input))
    }
    
    func testHighlightWithSentinelOffset() {
        let input = [
            "@offset-start": "-1",
            "@offset-end": "-1",
            "@pid": "20527924",
            "@color": "yellow",
        ]
        let expected = Highlight(id: nil, paragraphAID: "20527924", offsetStart: 0, offsetEnd: nil, colorName: "yellow", style: .Highlight, annotationID: 1)
        let actual = try! Highlight(jsonObject: input, annotationID: 1)
        XCTAssertEqual(actual, expected)
        let output = actual.jsonObject() as! [String: NSObject]
        XCTAssertEqual(output, expectedOutputFromInput(input))
    }
    
    private func expectedOutputFromInput(input: [String: AnyObject]) -> [String: NSObject] {
        return input.mapValues { key, value in
            switch key {
            case "@offset-start", "@offset-end":
                return Int(value as! String)!
            default:
                return value as! NSObject
            }
        }
    }
    
}
