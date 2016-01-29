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

extension NSMutableURLRequest {
    
    func setAnnotationServiceHeadersWithSession(session: Session, clientUsername: String, clientPassword: String) throws {
        guard let authData = "\(clientUsername):\(clientPassword)".dataUsingEncoding(NSUTF8StringEncoding) else {
            throw Error.errorWithCode(.Unknown, failureReason: "Failed to encode authorization header")
        }
        
        setValue("Basic \(authData.base64EncodedStringWithOptions([]))", forHTTPHeaderField: "Authorization")
        
        setValue(session.userAgent, forHTTPHeaderField: "User-Agent")
        setValue(session.clientVersion, forHTTPHeaderField: "client-app-version")
        setValue("application/json", forHTTPHeaderField: "Accept")
        setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    }
    
    func setBodyWithJSONObject(jsonObject: AnyObject) throws {
        let data = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: [])
        HTTPBody = data
        setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
    }
    
}
