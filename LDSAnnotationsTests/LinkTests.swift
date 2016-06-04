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

class LinkTests: XCTestCase {
    
    func testLinkMissingPID() {
        let input = [
            "$": "name",
            "@docId": "1",
            "@contentVersion": "1",
        ]
        do {
            let _ = try Link(jsonObject: input, annotationID: 1)
            XCTFail("Expected an error")
        } catch let error as NSError where Error.Code(rawValue: error.code) == .InvalidParagraphAID {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testLink() {
        let input = [
            "$": "name",
            "@docId": "1",
            "@contentVersion": "1",
            "@pid": "20527924",
        ]
        let expected = Link(id: nil, name: "name", docID: "1", docVersion: 1, paragraphAIDs: ["20527924"], annotationID: 1)
        let actual = try! Link(jsonObject: input, annotationID: 1)
        XCTAssertEqual(actual, expected)
        let output = actual.jsonObject() as! [String: NSObject]
        XCTAssertEqual(output, expectedOutputFromInput(input))
    }
    
    private func expectedOutputFromInput(input: [String: AnyObject]) -> [String: NSObject] {
        return input.mapValues { key, value in
            switch key {
            case "@contentVersion":
                return Int(value as! String)!
            default:
                return value as! NSObject
            }
        }
    }
    
}
