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
import Operations

class AuthenticateOperation: Operation {
    
    let session: Session
    
    init(session: Session) {
        self.session = session
        
        super.init()
        
        addCondition(MutuallyExclusive<AuthenticateOperation>())
    }
    
    override func execute() {
        if session.authenticated {
            finish()
            return
        }
        
        guard let url = session.authenticationURL else {
            finish(Error.errorWithCode(.Unknown, failureReason: "Missing authentication URL"))
            return
        }
        
        let request = NSMutableURLRequest(URL: url)
        
        guard let cookieValue = "wh=\(session.domain) wu=/header wo=1 rh=http://\(session.domain) ru=/header".stringByAddingPercentEscapesForQueryValue(), let cookie = NSHTTPCookie(properties: [
            NSHTTPCookieName: "ObFormLoginCookie",
            NSHTTPCookieValue: cookieValue,
            NSHTTPCookieDomain: ".lds.org",
            NSHTTPCookiePath : "/login.html",
            NSHTTPCookieExpires: NSDate(timeIntervalSinceNow: 60 * 60),
        ]) else {
            finish(Error.errorWithCode(.Unknown, failureReason: "Malformed authentication domain"))
            return
        }
        request.allHTTPHeaderFields = NSHTTPCookie.requestHeaderFieldsWithCookies([cookie])
        
        request.timeoutInterval = 90
        request.HTTPMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        guard let body = [
            "username": session.username,
            "password": session.password,
        ].map({ key, value in
            return "\(key)=\(value.stringByAddingPercentEscapesForQueryValue()!)"
        }).joinWithSeparator("&").dataUsingEncoding(NSUTF8StringEncoding) else {
            finish(Error.errorWithCode(.Unknown, failureReason: "Malformed parameter"))
            return
        }
        
        request.HTTPBody = body
        request.setValue("\(body.length)", forHTTPHeaderField: "Content-Length")
        
        let authenticationDate = NSDate()
        
        let task = session.urlSession.dataTaskWithRequest(request) { data, response, error in
            Session.networkIndicatorStop?()
            if let error = error {
                self.finish(error)
                return
            }
            
            guard let httpResponse = response as? NSHTTPURLResponse, responseHeaderFields = httpResponse.allHeaderFields as? [String: String], responseURL = httpResponse.URL else {
                self.finish(Error.errorWithCode(.Unknown, failureReason: "Unexpected response"))
                return
            }
            
            let cookies = NSHTTPCookie.cookiesWithResponseHeaderFields(responseHeaderFields, forURL: responseURL)
            if cookies.contains({ $0.name == "ObFormLoginCookie" && $0.value == "done" }) {
                self.session.lastSuccessfulAuthenticationDate = authenticationDate
                self.finish()
                return
            }
            
            let errorKey: String
            if let locationValue = responseHeaderFields["Location"], errorRange = locationValue.rangeOfString("error=") {
                errorKey = locationValue.substringFromIndex(errorRange.endIndex)
            } else {
                errorKey = "unknown"
            }
            
            switch errorKey {
            case "authfailed":
                self.finish(Error.errorWithCode(.AuthenticationFailed, failureReason: "Incorrect username and/or password."))
            case "lockout":
                self.finish(Error.errorWithCode(.LockedOut, failureReason: "Account is locked."))
            case "pwdexpired":
                self.finish(Error.errorWithCode(.PasswordExpired, failureReason: "Password is expired."))
            default:
                self.finish(Error.errorWithCode(.Unknown, failureReason: "Authentication for an unknown reason."))
            }
        }
        Session.networkIndicatorStart()
        task.resume()
    }
    
}
