//
//  ChatViewController.swift
//  FireChat
//
//  Created by Alex Cole on 9/28/20.
//

import UIKit
import MessageKit

struct Message: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}

struct Sender: SenderType {
    var photoURL: String
    var senderId: String
    var displayName: String
}

class ChatViewController: MessagesViewController {
    
    private var messages = [Message]()
    
    private let selfSender = Sender(photoURL: "",
                                    senderId: "1",
                                    displayName: "Chris Kwon")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        messages.append(Message(sender: selfSender, messageId: "1", sentDate: Date(), kind: .text("Play me in Uno")))
        messages.append(Message(sender: selfSender, messageId: "1", sentDate: Date(), kind: .text("Play me in Uno BITCHPlay me in Uno BITCH Play me in Uno BITCH Play me in Uno BITCH ")))
        
        view.backgroundColor = .cyan
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
    }
    
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        return selfSender
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
}
