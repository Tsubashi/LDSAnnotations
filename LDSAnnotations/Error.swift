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

public enum SyncErrorType {
    case length
    case deserialization
    case unknown
}

public struct SyncError: Error {
    let id: String?
    let username: String?
    let message: String
    let json: Any?
    let type: SyncErrorType
}

public struct AnnotationError {
    
    public static let Domain = "com.crosswaterbridge.LDSAnnotations"
    
    public enum Code: Int {
        case unknown = -1000
        case authenticationFailed = -1001
        case lockedOut = -1002
        case passwordExpired = -1003
        case saveAnnotationFailed = -3000
        case saveHighlightFailed = -3001
        case requiredFieldMissing = -3008
        case syncFailed = -4000
        case transactionError = -5000
    }
    
    static func errorWithCode(_ code: AnnotationError.Code, failureReason: String) -> NSError {
        let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
        return NSError(domain: AnnotationError.Domain, code: code.rawValue, userInfo: userInfo)
    }
    
}
