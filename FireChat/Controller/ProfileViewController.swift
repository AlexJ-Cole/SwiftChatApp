//
//  ProfileViewController.swift
//  FireChat
//
//  Created by Alex Cole on 9/27/20.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn

///Controller to present profile information for current user
final class ProfileViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    private var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ProfileTableViewCell.self,
                           forCellReuseIdentifier: ProfileTableViewCell.identifier)
        
        addTableElements()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableHeaderView = createTableHeader()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.tableHeaderView = createTableHeader()
        
        if data.isEmpty {
            addTableElements()
            tableView.reloadData()
        }
        
        if let name = UserDefaults.standard.value(forKey: "name") as? String {
            navigationItem.title = "Hi, \(name)!"
        }
    }
    
    func addTableElements() {
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "dirtyEmail") as? String ?? "No Email")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout,
                                     title: "Log Out",
                                     handler: { [weak self] in
                                        guard let strongSelf = self else { return }
                                        let ac = UIAlertController(title: "",
                                                                   message: "",
                                                                   preferredStyle: .actionSheet)
                                        ac.addAction(UIAlertAction(title: "Log Out",
                                                                   style: .destructive) { [weak self] _ in
                                            //Remove profileVC table elements & reload
                                            self?.data.removeAll()
                                            self?.navigationItem.title = "Profile"
                                            
                                            DispatchQueue.main.async {
                                                self?.tableView.reloadData()
                                            }
                                            
                                            //Set user defaults email & name to nil
                                            UserDefaults.standard.setValue(nil, forKey: "email")
                                            UserDefaults.standard.setValue(nil, forKey: "dirtyEmail")
                                            UserDefaults.standard.setValue(nil, forKey: "name")
                                            
                                            //Log out Facebook
                                            FBSDKLoginKit.LoginManager().logOut()
                                            
                                            //Log out Google
                                            GIDSignIn.sharedInstance()?.signOut()
                                            
                                            //Log out Firebase
                                            do {
                                                try FirebaseAuth.Auth.auth().signOut()
                                                let vc = LoginViewController()
                                                let nav = UINavigationController(rootViewController: vc)
                                                nav.modalPresentationStyle = .fullScreen
                                                strongSelf.present(nav, animated: true)
                                            } catch {
                                                print("failed to logout")
                                            }
                                        })
                                        ac.addAction(UIAlertAction(title: "Cancel",
                                                                   style: .cancel,
                                                                   handler: nil))
                                        strongSelf.present(ac, animated: true)
                                     }))
    }
    
    /// Returns a UIView object with user's profile picture to be used as the `tableView` header
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            print("No email saved in user defaults for user")
            return nil
        }
        
        let fileName = email + "_profile_picture.png"
        let path = "images/" + fileName
        
        let headerView = UIView(frame: CGRect(x: 0,
                                              y: 0,
                                              width: view.width,
                                              height: 300))
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (view.width - 150) / 2,
                                                  y: 75,
                                                  width: 150,
                                                  height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.backgroundColor = .white
        imageView.layer.borderWidth = 3
        imageView.layer.cornerRadius = imageView.width / 2
        imageView.layer.masksToBounds = true
        
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("Failed to get download URL - \(error)")
            }
        })
        
        return headerView
    }
    
    // This is not necessary anymore, but I am leaving it in for learning purposes
    // NOW using SDWebImage for caching purposes
    //
    //    func downloadImage(imageView: UIImageView, url: URL) {
    //        URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
    //            guard let data = data, error == nil else { return }
    //
    //            DispatchQueue.main.async {
    //                let image = UIImage(data: data)
    //                imageView.image = image
    //            }
    //        }).resume()
    //    }
}

//MARK: - UITableView Protocols Extension

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        
        cell.setUp(with: viewModel)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let handler = data[indexPath.row].handler else {
            return
        }
        
        handler()
    }
}
