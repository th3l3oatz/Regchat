//
//  HomeViewController.swift
//  RegDemo
//
//  Created by B13 on 6/22/2560 BE.
//  Copyright © 2560 Apptitude. All rights reserved.
//

import UIKit
import AlamofireImage
import Alamofire

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    
    var subjectItems: [Subject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let token = AuthenticationManager.token() {
            API.subjects(token: token, completion: { (result) in
                if case let .success(items) = result {
                    self.subjectItems = items
                    self.tableView.reloadData()
                } else {
                    print("Error")
                    print(result.error!)
                }
            })
        }
        showInfomation()
    }
    
    func showInfomation () {
        if let token = AuthenticationManager.token(), let request = API.profileImageURLRequest(token: token) {
           profileImageView.af_setImage(withURLRequest: request)
        }
        usernameLabel.text = AuthenticationManager.user()?.uid
        nameLabel.text = AuthenticationManager.user()?.name
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subjectItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let item = subjectItems[indexPath.row]
        cell.textLabel?.text = item.nameTH
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let indexPath = tableView.indexPathForSelectedRow {
            let enrollController = segue.destination as? EnrollViewController
            enrollController?.subjectID = subjectItems[indexPath.row].subjectID
            enrollController?.year = subjectItems[indexPath.row].year
            enrollController?.semester = subjectItems[indexPath.row].semester
        }
    }

}
