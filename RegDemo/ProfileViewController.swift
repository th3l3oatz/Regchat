//
//  SettingViewController.swift
//  RegDemo
//
//  Created by B13 on 7/27/2560 BE.
//  Copyright © 2560 Apptitude. All rights reserved.
//

import UIKit
import FirebaseAuth
import AlamofireImage
import Alamofire
import FirebaseDatabase

class ProfileViewController: UIViewController {
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var facultyLabel: UILabel!
    @IBOutlet weak var programLabel: UILabel!
    @IBOutlet weak var gpaLabel: UILabel!
    @IBOutlet weak var notificationSwitch: UISwitch!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var editNickname: UIButton!
    
    var nickname = ""
    override func viewDidLoad() {
        self.hideKeyboardOnTap(#selector(self.dismissKeyboard))
        editNickname.semanticContentAttribute = .forceRightToLeft
        editNickname.setTitle("Edit Nickname ", for: .normal)
        self.nicknameLabel.text = AuthenticationManager.user()?.name
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showInfomation()
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
        // do aditional stuff
    }
    
    func showInfomation () {
        guard let uid = AuthenticationManager.user()?.uid else { return }

        Database.database().reference().child("users").child(uid).child("data").child("nickname").observeSingleEvent(of: .value, with: { (snapshot) in
            if let nicknamesanpshot = snapshot.value as? String {
                self.nickname = nicknamesanpshot
                if self.nickname == "" {
                    self.nicknameLabel.text = AuthenticationManager.user()?.name
                } else {
                    self.nicknameLabel.text = self.nickname
                }
            }
        })
       
        
        if let token = AuthenticationManager.token(), let request = API.profileImageURLRequest(token: token) {
            profileImage.af_setImage(withURLRequest: request)
            profileImage.layer.borderWidth = 1
            profileImage.layer.masksToBounds = false
            profileImage.layer.borderColor = UIColor.white.cgColor
            profileImage.layer.cornerRadius = profileImage.frame.height/2
            profileImage.clipsToBounds = true
        }
        usernameLabel.text = AuthenticationManager.user()?.uid
        nameLabel.text = AuthenticationManager.user()?.name
        statusLabel.text = AuthenticationManager.user()?.status
        facultyLabel.text = AuthenticationManager.user()?.facultyName
        programLabel.text = AuthenticationManager.user()?.programName
        gpaLabel.text = "\(AuthenticationManager.user()?.latestGPA)"
    }
    
    @IBAction func editNickname(_ sender: Any) {
        presentAlert()
    }
    
    func presentAlert() {
        guard let uid = AuthenticationManager.user()?.uid else { return }
        
        let alertController = UIAlertController(title: "Nickname", message: "Please input your nickname", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { (_) in
            if let field = alertController.textFields?[0] {
                self.nicknameLabel.text = field.text
                self.nickname = field.text!
                let dataRef = Database.database().reference().child("users").child(uid).child("data")
                
                dataRef.child("nickname").setValue(self.nickname)
            } else {
                // user did not fill field
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Nickname"
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func logout() {
        do {
            try Auth.auth().signOut()
        } catch let error {
            print(error)
        }
        AuthenticationManager.clear()
        Helper.helper.switchToLoginViewController()
    }
    
    
}

