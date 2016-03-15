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
import PSOperations

/// Communicates with the annotation service.
///
/// Instances are lightweight; construct a new instance whenever the user's credentials change.
public class Session: NSObject {
    
    /// The username used to authenticate this session.
    public let username: String
    
    /// The password used to authenticate this session.
    public let password: String
    
    let userAgent: String
    let clientVersion: String
    let clientUsername: String
    let clientPassword: String
    let authenticationURL: NSURL?
    let domain: String
    let source: String
    
    var docVersionsForDocIDs: ((docIDs: [String]) -> ([String: Int]))?
    
    /// Constructs a session.
    public init(username: String, password: String, userAgent: String, clientVersion: String, clientUsername: String, clientPassword: String, authenticationURL: NSURL? = NSURL(string: "https://beta.lds.org/login.html"), domain: String = "beta.lds.org", source: String) {
        self.username = username
        self.password = password
        self.userAgent = userAgent
        self.clientVersion = clientVersion
        self.clientUsername = clientUsername
        self.clientPassword = clientPassword
        self.authenticationURL = authenticationURL
        self.domain = domain
        self.source = source
    }
    
    lazy var urlSession: NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration(), delegate: self, delegateQueue: nil)
    }()
    
    let operationQueue = OperationQueue()
    
    var lastSuccessfulAuthenticationDate: NSDate?
    
    var authenticated: Bool {
        let gracePeriod: NSTimeInterval = 15 * 60
        if let lastSuccessfulAuthenticationDate = lastSuccessfulAuthenticationDate where NSDate().timeIntervalSinceDate(lastSuccessfulAuthenticationDate) < gracePeriod {
            return true
        } else {
            return false
        }
    }
    
    /// Authenticates against the server.
    public func authenticate(completion: (NSError?) -> Void) {
        let operation = AuthenticateOperation(session: self)
        operation.addObserver(BlockObserver(startHandler: nil, produceHandler: nil, finishHandler: { operation, errors in
            completion(errors.first)
        }))
        operationQueue.addOperation(operation)
    }
    
    /// Uploads all local annotations modifications made since the last sync, then downloads and stores all annotation modifications made after the last sync.
    ///
    /// Upon a successful sync, the result includes a `token` which should be used for the next sync.
    public func syncAnnotations(annotationStore annotationStore: AnnotationStore, token: SyncToken?, completion: (SyncNotebooksResult, SyncAnnotationsResult) -> Void) {
        let syncNotebooksOperation = SyncNotebooksOperation(session: self, annotationStore: annotationStore, token: token) { syncNotebooksResult in
            switch syncNotebooksResult {
            case let .Success(localSyncDate: localSyncDate, serverSyncDate: serverSyncDate, notebookAnnotationIDs: notebookAnnotationIDs, uploadCount: _, downloadCount: _):
                let syncAnnotationsOperation = SyncAnnotationsOperation(session: self, annotationStore: annotationStore, token: token, localSyncDate: localSyncDate, serverSyncDate: serverSyncDate, notebookAnnotationIDs: notebookAnnotationIDs) { syncAnnotationsResult in
                    completion(syncNotebooksResult, syncAnnotationsResult)
                }
                self.operationQueue.addOperation(syncAnnotationsOperation)
            case .Error(errors: _):
                completion(syncNotebooksResult, SyncAnnotationsResult.Error(errors: []))
            }
        }
        operationQueue.addOperation(syncNotebooksOperation)
    }

}

// MARK: - Networking primitives

extension Session {
    
    func put(endpoint: String, payload: [String: AnyObject], completion: (Response) -> Void) {
        guard let url = NSURL(string: "https://\(domain)\(endpoint)") else {
            completion(.Error(Error.errorWithCode(.Unknown, failureReason: "Malformed URL")))
            return
        }
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "PUT"
        
        do {
            try request.setAnnotationServiceHeadersWithSession(self, clientUsername: clientUsername, clientPassword: clientPassword)
            try request.setBodyWithJSONObject(payload)
        } catch let error as NSError {
            completion(.Error(error))
            return
        }
        
        let task = urlSession.dataTaskWithRequest(request) { data, response, error in
            if let error = error {
                completion(.Error(error))
                return
            }
            
            guard let data = data, response = response as? NSHTTPURLResponse else {
                completion(.Error(Error.errorWithCode(.Unknown, failureReason: "Missing response")))
                return
            }
            
            let jsonObject: AnyObject
            do {
                jsonObject = try NSJSONSerialization.JSONObjectWithData(data, options: [])
            } catch let error as NSError {
                completion(.Error(error))
                return
            }
            
            guard let jsonDictionary = jsonObject as? [String: AnyObject] else {
                completion(.Error(Error.errorWithCode(.Unknown, failureReason: "Unexpected JSON response")))
                return
            }
            
            if response.statusCode == 200 {
                completion(.Success(jsonDictionary))
            } else {
                guard let errorsWrapper = jsonDictionary["errors"] as? [String: AnyObject], errors = errorsWrapper["error"] as? [[String: String]] where !errors.isEmpty else {
                    completion(.Error(Error.errorWithCode(.Unknown, failureReason: "Unexpected JSON response")))
                    return
                }
                
                completion(.Failure(errors))
            }
        }
        task.resume()
    }
    
}

// MARK: - Auth redirection

extension Session: NSURLSessionTaskDelegate {

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, willPerformHTTPRedirection response: NSHTTPURLResponse, newRequest request: NSURLRequest, completionHandler: (NSURLRequest?) -> Void) {
        if response.statusCode == 302 {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
    
}
