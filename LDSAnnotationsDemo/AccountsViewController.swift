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
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    fileprivate static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: AccountsViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: [], metrics: nil, views: views))
        
        reloadData()
        
        AccountController.sharedController.addAccountObservers.add(self, type(of: self).didAddAccount)
        AccountController.sharedController.deleteAccountObservers.add(self, type(of: self).didDeleteAccount)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.flashScrollIndicators()
    }
    
    var usernames = [String]()
    
    func reloadData() {
        usernames = AccountController.sharedController.usernames
    }
    
    func didAddAccount(_ username: String) {
        reloadData()
        tableView.reloadData()
    }
    
    func didDeleteAccount(_ username: String) {
        reloadData()
        tableView.reloadData()
    }
    
}

// MARK: - Add account

extension AccountsViewController {

    func add() {
        let alertController = UIAlertController(title: "Add Account", message: "Enter the username and password for your LDS Account.", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Username"
            textField.addTarget(self, action: #selector(AccountsViewController.textFieldDidChange(_:)), for: .editingChanged)
        }
        alertController.addTextField { textField in
            textField.placeholder = "Password"
            textField.addTarget(self, action: #selector(AccountsViewController.textFieldDidChange(_:)), for: .editingChanged)
            textField.isSecureTextEntry = true
        }
        
        let doneAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
            let username = alertController.textFields?[0].text ?? ""
            let password = alertController.textFields?[1].text ?? ""
            self.addAccountWithUsername(username, password: password)
        })
        doneAction.isEnabled = false
        alertController.addAction(doneAction)
        alertController.preferredAction = doneAction
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        if let alertController = presentedViewController as? UIAlertController {
            let username = alertController.textFields?[0].text ?? ""
            let password = alertController.textFields?[1].text ?? ""
            alertController.preferredAction?.isEnabled = (username.length > 0 && password.length > 0)
        }
    }
    
    func addAccountWithUsername(_ username: String, password: String) {
        
        let session = SessionController.sharedController.session(forUsername: username) ?? Session(username: username, password: password)
        session.authenticate { error in
            if let error = error {
                NSLog("Failed to authenticate account: \(error)")
                
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Unable to Add Account", message: "Failed to sign in with the given username and password.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    SessionController.sharedController.addSession(session, withUsername: username)
                    
                    do {
                        try AccountController.sharedController.addOrUpdateAccount(withUsername: username, password: password)
                    } catch {
                        NSLog("Failed to add account: %@", "\(error)")
                    
                        let alertController = UIAlertController(title: "Unable to Add Account", message: "Failed to save account to keychain.", preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
    }

}

// MARK: - UITableViewDataSource

extension AccountsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return usernames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AccountsViewController.CellIdentifier, for: indexPath)
        
        let username = usernames[indexPath.row]
        cell.textLabel?.text = username
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let username = usernames[indexPath.row]
            do {
                try AccountController.sharedController.deleteAccount(username: username)
            } catch {
                NSLog("Failed to delete account: %@", "\(error)")
            }
        }
    }
    
}

// MARK: - UITableViewDelegate

extension AccountsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let username = usernames[indexPath.row]
        if let password = AccountController.sharedController.password(forUsername: username), let annotationStore = AnnotationStore.annotationStoreForUsername(username) {
            let viewController = AccountViewController(session: Session(username: username, password: password), annotationStore: annotationStore)
            
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
}
