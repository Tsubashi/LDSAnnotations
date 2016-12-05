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
import ProcedureKit
import Swiftification

/// Communicates with the annotation service.
///
/// Instances are lightweight; construct a new instance whenever the user's credentials change.
public class Session: NSObject {
    
    public let statusObservers = ObserverSet<Status>()
    public let networkActivityObservers = ObserverSet<NetworkActivity>()
    
    public enum Status {
        case none
        case syncInProgress
        case syncSuccessful
        case syncFailed
    }
    
    public enum NetworkActivity {
        case start
        case stop
    }
    
    /// The username used to authenticate this session.
    public let username: String
    
    /// The password used to authenticate this session.
    public let password: String
    
    let userAgent: String
    let clientVersion: String
    let clientUsername: String
    let clientPassword: String
    let authenticationURL: URL?
    let domain: String
    let trustPolicy: TrustPolicy
    
    static let sessionCookieName = "ObSSOCookie"
    var sessionCookieValue: String?
    
    public var obSSOCookieHeader: (name: String, value: String)? {
        guard let sessionCookieValue = sessionCookieValue else { return nil }
        return (name: "Cookie", value: String(format: "%@=%@", Session.sessionCookieName, sessionCookieValue))
    }
    
    public private(set) var status: Status = .none {
        didSet {
            statusObservers.notify(status)
        }
    }
    
    /// Callback to get the local doc version of the given doc IDs.
    ///
    /// Returns a dictionary of doc IDs to doc versions.
    public var docVersionsForDocIDs: ((_ docIDs: [String]) -> ([String: Int]))?
    
    /// Constructs a session.
    public init(username: String, password: String, userAgent: String, clientVersion: String, clientUsername: String, clientPassword: String, authenticationURL: URL? = URL(string: "https://beta.lds.org/login.html"), domain: String = "beta.lds.org", trustPolicy: TrustPolicy = .trust) {
        self.username = username
        self.password = password
        self.userAgent = userAgent
        self.clientVersion = clientVersion
        self.clientUsername = clientUsername
        self.clientPassword = clientPassword
        self.authenticationURL = authenticationURL
        self.domain = domain
        self.trustPolicy = trustPolicy
    }
    
    lazy var urlSession: Foundation.URLSession = {
        return Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()
    
    let procedureQueue = ProcedureQueue()
    private let dataQueue = DispatchQueue(label: "LDSAnnotations.session.syncqueue", attributes: [])
    
    var lastSuccessfulAuthenticationDate: Date?
    
    private var syncQueued = false
    
    var authenticated: Bool {
        let gracePeriod: TimeInterval = 15 * 60
        if let lastSuccessfulAuthenticationDate = lastSuccessfulAuthenticationDate, Date().timeIntervalSince(lastSuccessfulAuthenticationDate) < gracePeriod {
            return true
        } else {
            return false
        }
    }
    
    /// Authenticates against the server.
    public func authenticate(_ completion: @escaping (Error?) -> Void) {
        let operation = AuthenticateOperation(session: self)
        operation.add(observer: BlockObserver(didFinish: { operation, errors in
            completion(errors.first)
        }))
        procedureQueue.addOperation(operation)
    }
    
    /// Uploads all local annotations modifications made since the last sync, then downloads and stores all annotation modifications made after the last sync.
    ///
    /// Upon a successful sync, the result includes a `token` which should be used for the next sync.
    public func sync(annotationStore: AnnotationStore, token: SyncToken?, completion: @escaping (SyncResult) -> Void) {
        dataQueue.async {
            switch self.status {
            case .syncInProgress:
                self.syncQueued = true
            case .syncSuccessful, .syncFailed, .none:
                break
            }

            guard !self.syncQueued else {
                // Next sync already queued, just return
                return
            }
            
            self.status = .syncInProgress
            
            let syncOperation = SyncOperation(session: self, annotationStore: annotationStore, token: token) { result in
                self.dataQueue.async {
                    switch result {
                    case let .success(token, _, _):
                        self.status = .syncSuccessful
                    case .error:
                        self.status = .syncFailed
                    }

                    // Trigger next sync if one is queued
                    if self.syncQueued {
                        self.syncQueued = false
                        self.sync(annotationStore: annotationStore, token: token, completion: completion)
                    }

                    completion(result)
                }
            }
            
            self.procedureQueue.addOperation(syncOperation)
        }
    }

}

// MARK: - Networking primitives

extension Session {
    
    func put(_ endpoint: String, payload: [String: Any], completion: @escaping (Response) -> Void) {
        guard let url = URL(string: "https://\(domain)\(endpoint)") else {
            completion(.error(AnnotationError.errorWithCode(.unknown, failureReason: "Malformed URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        if let obSSOCookieHeader = obSSOCookieHeader {
            request.addValue(obSSOCookieHeader.value, forHTTPHeaderField: obSSOCookieHeader.name)
        }
        
        do {
            try request.setAnnotationServiceHeadersWithSession(self, clientUsername: clientUsername, clientPassword: clientPassword)
            try request.setBodyWithJSONObject(payload as AnyObject)
        } catch let error as NSError {
            completion(.error(error))
            return
        }
        
        let task = urlSession.dataTask(with: request, completionHandler: { data, response, error in
            self.networkActivityObservers.notify(.stop)
            if let error = error {
                completion(.error(error))
                return
            }
            
            guard let data = data, let response = response as? HTTPURLResponse else {
                completion(.error(AnnotationError.errorWithCode(.unknown, failureReason: "Missing response")))
                return
            }
            
            let jsonObject: Any
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            } catch let error as NSError {
                completion(.error(error))
                return
            }
            
            guard let jsonDictionary = jsonObject as? [String: Any] else {
                completion(.error(AnnotationError.errorWithCode(.unknown, failureReason: "Unexpected JSON response")))
                return
            }
            
            if response.statusCode == 200 {
                completion(.success(jsonDictionary))
            } else {
                guard let errorsWrapper = jsonDictionary["errors"] as? [String: Any], let errors = errorsWrapper["error"] as? [[String: String]], !errors.isEmpty else {
                    completion(.error(AnnotationError.errorWithCode(.unknown, failureReason: "Unexpected JSON response")))
                    return
                }
                
                completion(.failure(errors))
            }
        }) 
        networkActivityObservers.notify(.start)
        task.resume()
    }
    
}

// MARK: - NSURLSessionDelegate

extension Session: URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        switch trustPolicy {
        case .validate:
            completionHandler(.performDefaultHandling, nil)
        case .trust:
            completionHandler(.useCredential, challenge.protectionSpace.serverTrust.flatMap { URLCredential(trust: $0) })
        }
    }
    
}

// MARK: - Auth redirection

extension Session: URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if response.statusCode == 302 {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
    
}
