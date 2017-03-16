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
    
    public func addOrUpdateAccount(withUsername username: String, password: String) throws {
        try Locksmith.updateData(data: ["password": password], forUserAccount: username, inService: AccountController.service)
        
        if !usernames.contains(username) {
            usernames.append(username)
        }
        
        addAccountObservers.notify(username)
    }
    
    public func deleteAccount(username: String) throws {
        do {
            try Locksmith.deleteDataForUserAccount(userAccount: username, inService: AccountController.service)
        } catch {
            // It's not catastrophic if the password cannot be deleted
        }
        
        // Get rid of sync tokens when user signs out
        deleteSyncToken(forUsername: username)
        
        usernames = usernames.filter { $0 != username }
        
        deleteAccountObservers.notify(username)
    }
    
    private static let usernamesKey = "usernames"
    
    private(set) public var usernames: [String] {
        get {
            return (UserDefaults.standard.array(forKey: AccountController.usernamesKey) as? [String] ?? []).sorted()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AccountController.usernamesKey)
        }
    }
    
    public func password(forUsername username: String) -> String? {
        return Locksmith.loadDataForUserAccount(userAccount: username, inService: AccountController.service)?["password"] as? String
    }
    
    private static let tokensKey = "tokens"
    
    public func syncToken(forUsername username: String) -> SyncToken? {
        guard let tokens = UserDefaults.standard.object(forKey: AccountController.tokensKey) as? [String: String], let rawToken = tokens[username] else { return nil }
        
        return SyncToken(rawValue: rawToken)
    }
    
    public func setSyncToken(_ token: SyncToken?, forUsername username: String) {
        var tokens = UserDefaults.standard.object(forKey: AccountController.tokensKey) as? [String: String] ?? [:]
        tokens[username] = token?.rawValue
        UserDefaults.standard.set(tokens, forKey: AccountController.tokensKey)
    }
    
    public func deleteSyncToken(forUsername username: String) {
        var tokens = UserDefaults.standard.object(forKey: AccountController.tokensKey) as? [String: String] ?? [:]
        tokens.removeValue(forKey: username)
        UserDefaults.standard.set(tokens, forKey: AccountController.tokensKey)
    }
    
}
