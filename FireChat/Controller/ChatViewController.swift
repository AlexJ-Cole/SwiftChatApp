//
//  ChatViewController.swift
//  FireChat
//
//  Created by Alex Cole on 9/28/20.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

/// Controller to present a conversation between current user and a recipient. Presented when a conversation is tapped in `ConversationsViewController` or when a new conversation is started from `NewConversationViewController`
final class ChatViewController: MessagesViewController {
    
    private var senderPhotoURL: URL?
    
    private var otherUserPhotoURL: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String
    
    private var conversationId: String?
    
    public var isNewConversation = false
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String,
              let name = UserDefaults.standard.value(forKey: "name") as? String else {
            return nil
        }
        
        return Sender(photoURL: "",
                      senderId: email,
                      displayName: name)
    }
    
    init(with email: String, id: String?) {
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .cyan
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside({ [weak self] _ in
            self?.presentInputActionsheet()
        })
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionsheet() {
        let ac = UIAlertController(title: "Attach Media",
                                   message: "What would you like to attach?",
                                   preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        ac.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        ac.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(ac, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            guard let strongSelf = self,
                  let messageId = strongSelf.createMessageId(),
                  let name = strongSelf.title,
                  let selfSender = strongSelf.selfSender else {
                return
            }
            
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
            print("long: \(longitude), lat: \(latitude)")
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                                         size: .zero)
            
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
            //Creates new convo if convo does not currently exist
            if strongSelf.isNewConversation {
                //create the convo in database
                DatabaseManager.shared.createNewConversation(with: strongSelf.otherUserEmail, otherUserName: strongSelf.title ?? "User", firstMessage: message, completion: { success in
                    if success {
                        print("message sent")
                        strongSelf.isNewConversation = false
                    } else {
                        print("failed to send message")
                    }
                })
            }
            //Otherwise, send message to current convo
            else {
                guard let conversationId = strongSelf.conversationId else {
                    print("No conversation ID found when trying to start a new convo with location")
                    return
                }
                DatabaseManager.shared.sendMessage(conversationId: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                    if success {
                        print("sent location message")
                    } else {
                        print("failed to send location message")
                    }
                    
                })
            }
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        let ac = UIAlertController(title: "Attach Video",
                                   message: "Where would you like to attach a video from?",
                                   preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            picker.sourceType = .camera
            self?.present(picker, animated: true)
        }))
        ac.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            picker.sourceType = .photoLibrary
            self?.present(picker, animated: true)
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(ac, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let ac = UIAlertController(title: "Attach Photo",
                                   message: "Where would you like to attach a photo from?",
                                   preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = true
            picker.sourceType = .camera
            self?.present(picker, animated: true)
        }))
        ac.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = true
            picker.sourceType = .photoLibrary
            self?.present(picker, animated: true)
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(ac, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(conversationId: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                print("success in getting messages: \(messages)")
                guard !messages.isEmpty else {
                    print("messages are empty")
                    return
                }
                
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }
            case .failure(let error):
                print("failed to get messages for conversation - \(error)")
            }
        })
    }
    
}

//MARK: - Text Input Bar Delegate

extension ChatViewController: InputBarAccessoryViewDelegate {
    /// Called when input bar's send button is tapped
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = selfSender,
              let messageId = createMessageId() else {
            return
        }
        
        print("sending text: \(text)")
        messageInputBar.inputTextView.text = ""
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        
        //Send the message ;)
        if isNewConversation {
            //create the convo in database
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, otherUserName: title ?? "User", firstMessage: message, completion: { [weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation: \(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                } else {
                    print("failed to send message")
                }
            })
        } else {
            guard let conversationId = conversationId,
                  let name = title else {
                return
            }
            //append message to existing conversation data
            DatabaseManager.shared.sendMessage(conversationId: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("message sent")
                    
                } else {
                    print("failed to send")
                }
            })
        }
    }
    
    /// Returns a unique identifier for a message using both user's emails and the current date
    private func createMessageId() -> String? {
        //date, otherUserEmail, senderEmail
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }

        let dateString = ChatViewController.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(currentUserEmail)_\(dateString)"
        
        print("created message id: \(newIdentifier)")
        
        return newIdentifier
    }
}

//MARK: - Messages Delegates

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            //Our message
            return .link
        } else {
            //received message
            return .secondarySystemBackground
        }
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId {
            //show our image
            if let currentUserPhotoURL = senderPhotoURL {
                avatarView.sd_setImage(with: currentUserPhotoURL, completed: nil)
            } else {
                //fetch the url
                fetchAvatarImage(for: avatarView, with: sender)
            }
        } else {
            //show other user's image
            if let otherUserPhotoURL = otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUserPhotoURL, completed: nil)
            } else {
                //fetch the url
                fetchAvatarImage(for: avatarView, with: sender)
            }
        }
    }
    
    private func fetchAvatarImage(for avatarView: AvatarView, with sender: SenderType) {
        StorageManager.shared.downloadURL(for: "images/\(sender.senderId)_profile_picture.png", completion: { [weak self] result in
            switch result {
            case .success(let url):
                if sender.senderId == self?.selfSender?.senderId {
                    self?.senderPhotoURL = url
                } else {
                    self?.otherUserPhotoURL = url
                }
                
                DispatchQueue.main.async {
                    avatarView.sd_setImage(with: url, completed: nil)
                }
            case .failure(let error):
                print("\(error)")
            }
            
        })
    }
    
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        
        fatalError("Self sender is nil, email should be cached :/")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    //Loads image from media messages
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
}

//MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    /// Sends media selected from image picker as a message to the current conversation
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageId = createMessageId(),
              let name = title,
              let selfSender = selfSender else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName = "photo_message_\(messageId.replacingOccurrences(of: " ", with: "-")).png"
            
            //Upload image
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success(let urlString):
                    //Ready to send message to other user
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    
                    print("uploaded message photo: \(urlString)")
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    //Creates new convo if convo does not exist
                    if strongSelf.isNewConversation {
                        //create the convo in database
                        DatabaseManager.shared.createNewConversation(with: strongSelf.otherUserEmail, otherUserName: strongSelf.title ?? "User", firstMessage: message, completion: { [weak self] success in
                            if success {
                                print("message sent")
                                self?.isNewConversation = false
                            } else {
                                print("failed to send message")
                            }
                        })
                    }
                    //Otherwise, send message to current convo
                    else {
                        guard let conversationId = self?.conversationId else {
                            print("No conversation ID found when trying to start a new convo with image")
                            return
                        }
                        DatabaseManager.shared.sendMessage(conversationId: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                            if success {
                                print("sent photo message")
                            } else {
                                print("failed to send photo message")
                            }
                            
                        })
                    }
                case .failure(let error):
                    print("Failed to upload message photo - \(error)")
                }
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
            let fileName = "video_message_\(messageId.replacingOccurrences(of: " ", with: "-")).mov"
            //Upload video
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success(let urlString):
                    //Ready to send message to other user
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    print("uploaded message video: \(urlString)")
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    //Creates new convo if convo does not exist
                    if strongSelf.isNewConversation {
                        //create the convo in database
                        DatabaseManager.shared.createNewConversation(with: strongSelf.otherUserEmail, otherUserName: strongSelf.title ?? "User", firstMessage: message, completion: { [weak self] success in
                            if success {
                                print("message sent")
                                self?.isNewConversation = false
                            } else {
                                print("failed to send message")
                            }
                        })
                    }
                    //Otherwise, send message to current convo
                    else {
                        guard let conversationId = self?.conversationId else {
                            print("Failed to find convo id when creating new convo w video")
                            return
                        }
                        DatabaseManager.shared.sendMessage(conversationId: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                            if success {
                                print("sent video message")
                            } else {
                                print("failed to send video message")
                            }
                            
                        })
                    }
                case .failure(let error):
                    print("Failed to upload message video - \(error)")
                }
            })
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

//MARK: - MessageCellDelegate (Message tap handlers)

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            
            let vc = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            vc.player?.playImmediately(atRate: 1)
            present(vc, animated: true)
        default:
            break
        }
    }
}
