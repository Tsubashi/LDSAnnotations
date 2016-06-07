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

import UIKit
import Swiftification
import LDSAnnotations

class AccountsViewController: UIViewController {
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        title = "Accounts"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(add))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .Grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: AccountsViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        AccountController.sharedController.addAccountObservers.add(self, self.dynamicType.didAddAccount)
        AccountController.sharedController.deleteAccountObservers.add(self, self.dynamicType.didDeleteAccount)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.flashScrollIndicators()
    }
    
    var usernames = [String]()
    
    func reloadData() {
        usernames = AccountController.sharedController.usernames
    }
    
    func didAddAccount(username: String) {
        reloadData()
        tableView.reloadData()
    }
    
    func didDeleteAccount(username: String) {
        reloadData()
        tableView.reloadData()
    }
    
}

// MARK: - Add account

extension AccountsViewController {

    func add() {
        let alertController = UIAlertController(title: "Add Account", message: "Enter the username and password for your LDS Account.", preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler { textField in
            textField.placeholder = "Username"
            textField.addTarget(self, action: #selector(AccountsViewController.textFieldDidChange(_:)), forControlEvents: .EditingChanged)
        }
        alertController.addTextFieldWithConfigurationHandler { textField in
            textField.placeholder = "Password"
            textField.addTarget(self, action: #selector(AccountsViewController.textFieldDidChange(_:)), forControlEvents: .EditingChanged)
            textField.secureTextEntry = true
        }
        
        let doneAction = UIAlertAction(title: "OK", style: .Default, handler: { _ in
            let username = alertController.textFields?[safe: 0]?.text ?? ""
            let password = alertController.textFields?[safe: 1]?.text ?? ""
            self.addAccountWithUsername(username, password: password)
        })
        doneAction.enabled = false
        alertController.addAction(doneAction)
        alertController.preferredAction = doneAction
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    func textFieldDidChange(textField: UITextField) {
        if let alertController = presentedViewController as? UIAlertController {
            let username = alertController.textFields?[safe: 0]?.text ?? ""
            let password = alertController.textFields?[safe: 1]?.text ?? ""
            alertController.preferredAction?.enabled = (username.length > 0 && password.length > 0)
        }
    }
    
    func addAccountWithUsername(username: String, password: String) {
        
        let session = SessionController.sharedController.sessionForUsername(username) ?? Session(username: username, password: password)
        session.authenticate { error in
            if let error = error {
                NSLog("Failed to authenticate account: %@", error)
                
                dispatch_async(dispatch_get_main_queue()) {
                    let alertController = UIAlertController(title: "Unable to Add Account", message: "Failed to sign in with the given username and password.", preferredStyle: .Alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                    
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    SessionController.sharedController.addSession(session, withUsername: username)
                    
                    do {
                        try AccountController.sharedController.addOrUpdateAccountWithUsername(username, password: password)
                    } catch {
                        NSLog("Failed to add account: %@", "\(error)")
                    
                        let alertController = UIAlertController(title: "Unable to Add Account", message: "Failed to save account to keychain.", preferredStyle: .Alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                        
                        self.presentViewController(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
    }

}

// MARK: - UITableViewDataSource

extension AccountsViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return usernames.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(AccountsViewController.CellIdentifier, forIndexPath: indexPath)
        
        let username = usernames[indexPath.row]
        cell.textLabel?.text = username
        cell.accessoryType = .DisclosureIndicator
        
        return cell
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let username = usernames[indexPath.row]
            do {
                try AccountController.sharedController.deleteAccountWithUsername(username)
            } catch {
                NSLog("Failed to delete account: %@", "\(error)")
            }
        }
    }
    
}

// MARK: - UITableViewDelegate

extension AccountsViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let username = usernames[indexPath.row]
        if let password = AccountController.sharedController.passwordForUsername(username), annotationStore = AnnotationStore.annotationStoreForUsername(username) {
            let viewController = AccountViewController(session: Session(username: username, password: password), annotationStore: annotationStore)
            
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
}
