//
//  ChatViewController.swift
//  RegDemo
//
//  Created by B13 on 7/20/2560 BE.
//  Copyright © 2560 Apptitude. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MobileCoreServices
import AVKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth

class ChatViewController: JSQMessagesViewController {
    
    var chatroomID = ""
    var name = ""
    var messages = [JSQMessage]()
    
    var messageRef: DatabaseReference?
    var chatRef: DatabaseReference?
    var members: [String] = []
    
    private var photoMessageMap = [String: JSQPhotoMediaItem]()
    private var avatars = [String: JSQMessagesAvatarImage]()
    private let imageURLNotSetKey = "NOTSET"
    private let messageQueryLimit: UInt = 25
    var avatarString: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        senderId = AuthenticationManager.user()?.uid
        senderDisplayName = AuthenticationManager.user()?.name
        
        Database.database().reference().child("users").child(senderId).child("name").observeSingleEvent(of: .value, with: { (snapshot) in
            if let name = snapshot.value as? String {
                self.senderDisplayName = name
            }
        })
 
        messageRef = Database.database().reference().child("chatrooms").child(chatroomID).child("messages")
        observeMessages()
        
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize(width: kJSQMessagesCollectionViewAvatarSizeDefault, height: kJSQMessagesCollectionViewCellLabelHeightDefault)
        collectionView.collectionViewLayout.outgoingAvatarViewSize = .zero
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        observeMembers()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editVC = segue.destination as? EditViewController {
            editVC.chatroomID = chatroomID
        }
    }
    
    func observeMembers() {
        Database.database().reference().child("chatrooms").child(chatroomID).child("members").observeSingleEvent(of: .value, with: { (snapshot) in
            if let dictionary = snapshot.value as? [String: AnyObject] {
                self.members = [String](dictionary.keys)
                self.navigationItem.title = "\(self.name)(\(self.members.count))"
            }
        })
        Database.database().reference().child("chatrooms").child(chatroomID).child("name").observeSingleEvent(of: .value, with: { (snapshot) in
            if let name = snapshot.value as? String{
                self.name = name
                self.navigationItem.title = "\(self.name) (\(self.members.count))"
            }
        })
    }
    
    func observeMessages() {
        messageRef!.observe(.childAdded, with: { snapshot in
            //print(snapshot.value!)
            if let dict = snapshot.value as? [String: AnyObject] {
                let mediaType = dict["mediaType"] as! String
                let senderId = dict["senderID"] as! String
                let senderName = dict["senderName"] as! String
                
                switch mediaType {
                    
                case "TEXT":
                    
                    let text = dict["text"] as? String
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, text: text))
                    
                case "PHOTO":
                    
                    let fileUrl = dict["fileUrl"] as! String
                    let url = NSURL(string: fileUrl)
                    let data = NSData(contentsOf: url! as URL)
                    let picture = UIImage(data: data as! Data)
                    let photo = JSQPhotoMediaItem(image: picture)
                    self.messages.append(JSQMessage(senderId: senderId, displayName: self.senderDisplayName, media: photo))
                    
                    if self.senderId == senderId {
                        photo?.appliesMediaViewMaskAsOutgoing = true
                    } else {
                        photo?.appliesMediaViewMaskAsOutgoing = false
                    }
                    
                    
                case "VIDEO":
                    
                    let fileUrl = dict["fileUrl"] as! String
                    let video = NSURL(string: fileUrl)
                    let videoItem = JSQVideoMediaItem(fileURL: video as URL!, isReadyToPlay: true)
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, media: videoItem))

                    if self.senderId == senderId {
                        videoItem?.appliesMediaViewMaskAsOutgoing = true
                    } else {
                        videoItem?.appliesMediaViewMaskAsOutgoing = false
                    }

                default :
                    print("unknown data type")
                }
                
                self.collectionView.reloadData()
            }

        })
    }
    
    //sender TextMessages
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
//        messages.append(JSQMessage(senderId: senderId, displayName: senderDisplayName, text: text))
//        collectionView.reloadData()
//        print(messages)
        let newMessage = messageRef!.childByAutoId()
        let messageData = ["text": text, "senderID": senderId, "senderName": senderDisplayName, "mediaType": "TEXT"]
        newMessage.setValue(messageData)
        self.finishSendingMessage()
    }
    
    //Sender MediaMessages
    override func didPressAccessoryButton(_ sender: UIButton!) {
        print("didPressAccessoryButton")
        
        
        let sheet = UIAlertController(title: "Media Messages", message: "Please select a media", preferredStyle: UIAlertControllerStyle.actionSheet)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (alert : UIAlertAction) in
            
        }
        let photoLibrary = UIAlertAction(title: "Photo Library", style: .default) { (alert : UIAlertAction) in
            self.getMediaFrom(type: kUTTypeImage)
        }
        let videoLibrary = UIAlertAction(title: "Video Library", style: .default) { (alert : UIAlertAction) in
            self.getMediaFrom(type: kUTTypeMovie)
        }
        
        sheet.addAction(photoLibrary)
        sheet.addAction(videoLibrary)
        sheet.addAction(cancel)
        self.present(sheet, animated: true, completion: nil)
        
//        let imagePicker = UIImagePickerController()
//        imagePicker.delegate = self
//        self.present(imagePicker, animated: true, completion: nil)
    }
    
    func getMediaFrom(type: CFString) {
        let mediaPicker = UIImagePickerController()
        mediaPicker.delegate = self
        mediaPicker.mediaTypes = [type as String]
        self.present(mediaPicker, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    //Display Messages
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        
        if message.senderId == self.senderId {
            let bubbleFactory = JSQMessagesBubbleImageFactory()
            return bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor.blue)
        } else {
            let bubbleFactory = JSQMessagesBubbleImageFactory()
            return bubbleFactory?.incomingMessagesBubbleImage(with: UIColor.lightGray)
        }
    }
    
    //MARK setting messageBubbletopLabel about name
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.item]

        if message.senderId == senderId {
            return nil
        } else {
            guard let senderDisplayName = message.senderDisplayName else {
                return nil
            }
            return NSAttributedString(string: senderDisplayName)

        }
    }

    
    //messageBubbleTopLabel hight
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        if messages.count == 0 {
            return 0.0
        }
        if messages[indexPath.item].senderId == senderId {
            return 8.0
        }

        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    
    //messageBubbleTopLabel text about Date
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        if messages.count == 0 {
            return nil
        }

        let message = messages[indexPath.item]

        if message.senderId == senderId {
            return nil
        }
        return NSAttributedString()
        //return NSAttributedString(string: "Date 05/10/2017")

    }
    
    //set hight toplabel
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAt indexPath: IndexPath!) -> CGFloat {
        if indexPath.item % 3 == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }

        return 0.0
    }

    
    //Show user's pic in chatroom for each message
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        return self.avatars[message.senderId]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }

    //set text color -> toplabel in bubble
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]

        if message.senderId != senderId {
            cell.messageBubbleTopLabel.textColor = UIColor.darkGray
        }

        cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0, kJSQMessagesCollectionViewAvatarSizeDefault+8, 10, 0)
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        print("didTapMessageBubbleAt indexPath: \(indexPath.item)")
        let message = messages[indexPath.item]
        if message.isMediaMessage {
            if let mediaItem = message.media as? JSQVideoMediaItem {
            let player = AVPlayer(url: mediaItem.fileURL)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player //command to play video
            self.present(playerViewController, animated: true, completion: nil)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func sendMedia(picture: UIImage?, video: NSURL?) {

        print(Storage.storage().reference())
        if let picture = picture {
            let filePath = "\(Auth.auth().currentUser!)/\(Date.timeIntervalSinceReferenceDate)"
            print(filePath)
            let data = UIImageJPEGRepresentation(picture, 0.1)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpg"
            Storage.storage().reference().child(filePath).putData(data!, metadata: metadata) { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription as Any)
                    return
                }
                
                let fileUrl = metadata!.downloadURLs![0].absoluteString
                
                let newMessage = self.messageRef!.childByAutoId()
                let messageData = ["fileUrl": fileUrl, "senderID": self.senderId, "senderName": self.senderDisplayName, "mediaType": "PHOTO"]
                newMessage.setValue(messageData)
                
            }
            
        } else if let video = video {
            let filePath = "\(Auth.auth().currentUser!)/\(NSDate.timeIntervalSinceReferenceDate)"
            print(filePath)
            let data = NSData(contentsOf: video as URL)
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            Storage.storage().reference().child(filePath).putData(data! as Data, metadata: metadata) { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription as Any)
                    return
                }
                
                let fileUrl = metadata!.downloadURLs![0].absoluteString
                
                let newMessage = self.messageRef!.childByAutoId()
                let messageData = ["fileUrl": fileUrl, "senderID": self.senderId, "senderName": self.senderDisplayName, "mediaType": "VIDEO"]
                newMessage.setValue(messageData)
                
            }
        }
      
    }
    
    private func fetchImageDataAtURL(_ photoURL: String, forMediaItem mediaItem: JSQPhotoMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?) {
        
        ImageDownloadManager.shared.fetchImage(with: photoURL) { (image: UIImage?) in
            if let image = image {
                mediaItem.image = image
            }
            
            self.finishReceivingMessage()
            guard let key = key else { return }
            self.photoMessageMap.removeValue(forKey: key)
        }
    }
    
//    fileprivate func setImageURL(_ url: String, forPhotoMessageWithKey key: String) {
//        // TODO: - Update existing image when generate image url successfully.
//        let itemRef = messageRef?.child(key)
//        itemRef.updateChildValues(["data": url])
//    }
    
    private func downloadCircleAvatar(with imageUrl: String, avatarImage: JSQMessagesAvatarImage) {
        ImageDownloadManager.shared.fetchImage(with: imageUrl, completion: { (image: UIImage?) in
            if let image = image {
                avatarImage.avatarImage = JSQMessagesAvatarImageFactory.circularAvatarImage(image, withDiameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
            }
        })
    }
    
    private func prepareAvatarImage(with id: String) -> JSQMessagesAvatarImage! {
        if (self.avatars[id] == nil) {
            let avartarImage = JSQMessagesAvatarImageFactory.avatarImage(withUserInitials: "F", backgroundColor: UIColor.groupTableViewBackground, textColor: UIColor.lightGray, font: UIFont.systemFont(ofSize: 17), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
            self.avatars[id] = avartarImage
        }
        
        return self.avatars[id]
    }
    
//    @IBAction func DidPreessed(_ sender: Any) {
//        if let tabbarVC = self.tabBarController, let vc = self.storyboard?.instantiateViewController(withIdentifier: "contactVC") {
//            if (tabbarVC.viewControllers?.count ?? 0) < 2 { return }
//            guard let desMavVC = tabbarVC.viewControllers?[1] as? UINavigationController else { return }
//            vc.hidesBottomBarWhenPushed = true
//            desMavVC.pushViewController(vc, animated: true)
//            self.navigationController?.popToRootViewController(animated: false)
//            tabbarVC.selectedIndex = 1
//        }
//
//    }
 
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        print("did finish picking")
        //get the image
        print(info)
        if let picture = info[UIImagePickerControllerOriginalImage] as? UIImage {
            //photo
            sendMedia(picture: picture, video: nil)

        } else if let video = info[UIImagePickerControllerMediaURL] as? NSURL {
            //video
            sendMedia(picture: nil, video: video)
        }
        
        self.dismiss(animated: true, completion: nil)
        collectionView.reloadData()
        
        
        
     
    }
}
