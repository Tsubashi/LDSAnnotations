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
import LDSAnnotations

class AuthenticationTests: XCTestCase {
    
    func testSuccess() {
        let expectation = expectationWithDescription("Successfully signed in")
        
        let session = createSession()
        session.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testFailure() {
        let expectation = expectationWithDescription("Failed to sign in")
        
        let session = createSession(useIncorrectPassword: true)
        session.authenticate { error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error!.domain, Error.Domain)
            XCTAssertEqual(error!.code, Error.Code.AuthenticationFailed.rawValue)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func createSession(useIncorrectPassword useIncorrectPassword: Bool = false) -> Session {
        guard let username = NSUserDefaults.standardUserDefaults().stringForKey("TestAccountUsername") else {
            XCTFail("Missing TestAccountUsername")
            fatalError()
        }
        guard let password = NSUserDefaults.standardUserDefaults().stringForKey("TestAccountPassword") else {
            XCTFail("Missing TestAccountPassword")
            fatalError()
        }
        guard let clientUsername = NSUserDefaults.standardUserDefaults().stringForKey("ClientUsername") else {
            XCTFail("Missing ClientUsername")
            fatalError()
        }
        guard let clientPassword = NSUserDefaults.standardUserDefaults().stringForKey("ClientPassword") else {
            XCTFail("Missing ClientPassword")
            fatalError()
        }
        
        let userAgent = "LDSAnnotations unit tests"
        let clientVersion = "1"
        
        return Session(username: username, password: useIncorrectPassword ? "wrong-\(password)" : password, userAgent: userAgent, clientVersion: clientVersion, clientUsername: clientUsername, clientPassword: clientPassword)
    }
    
}
