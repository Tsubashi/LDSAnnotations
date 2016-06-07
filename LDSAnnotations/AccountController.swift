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
import Swiftification
import Locksmith

public class AccountController {
    
    public static let sharedController = AccountController()
    
    public var addAccountObservers = ObserverSet<String>()
    public var deleteAccountObservers = ObserverSet<String>()
    
    private static let service = "LDSAccount"
    
    public func addOrUpdateAccountWithUsername(username: String, password: String) throws {
        try Locksmith.updateData(["password": password], forUserAccount: username, inService: AccountController.service)
        
        if !usernames.contains(username) {
            usernames.append(username)
        }
        
        addAccountObservers.notify(username)
    }
    
    public func deleteAccountWithUsername(username: String) throws {
        do {
            try Locksmith.deleteDataForUserAccount(username, inService: AccountController.service)
        } catch {
            // It's not catastrophic if the password cannot be deleted
        }
        
        usernames = usernames.filter { $0 != username }
        
        deleteAccountObservers.notify(username)
    }
    
    private static let usernamesKey = "usernames"
    
    private(set) public var usernames: [String] {
        get {
            return (NSUserDefaults.standardUserDefaults().arrayForKey(AccountController.usernamesKey) as? [String] ?? []).sort()
        }
        set {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: AccountController.usernamesKey)
        }
    }
    
    public func passwordForUsername(username: String) -> String? {
        return Locksmith.loadDataForUserAccount(username, inService: AccountController.service)?["password"] as? String
    }
    
    private static let tokensKey = "tokens"
    
    public func syncTokenForUsername(username: String) -> SyncToken? {
        guard let tokens = NSUserDefaults.standardUserDefaults().objectForKey(AccountController.tokensKey) as? [String: String], rawToken = tokens[username] else { return nil }
        
        return SyncToken(rawValue: rawToken)
    }
    
    public func setSyncToken(token: SyncToken?, forUsername username: String) {
        var tokens = NSUserDefaults.standardUserDefaults().objectForKey(AccountController.tokensKey) as? [String: String] ?? [:]
        tokens[username] = token?.rawValue
        NSUserDefaults.standardUserDefaults().setObject(tokens, forKey: AccountController.tokensKey)
    }
    
}
