//
//  DatabaseManager.swift
//  FireChat
//
//  Created by Alex Cole on 9/28/20.
//

import Foundation
import FirebaseDatabase
import MessageKit
import AVFoundation
import SDWebImage
import CoreLocation

/// Manager object to read and write data to Firebase DB
final class DatabaseManager {
    
    ///Shared instance of class
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    //This makes it so other instances of DatabaseManager cannot be created, shared instance MUST be used
    private init() {}
    
    static func safeEmail(_ emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    
    /// Returns dictionary node from DB at child `path`
    /// - Parameter path: Path string pointing to a location in DB
    /// - Parameter completion: Async closure to return with result holding dictionary located at path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        })
    }
}

//MARK: - Account Management

extension DatabaseManager {
    
    /// Check if user exists for given email
    /// - Parameter email:      Target email to be checked
    /// - Parameter completion : Async closure to return with result holding Bool. True if successful, false if unsuccessful
    public func userExists(with email: String,
                          completion: @escaping ((Bool) -> Void)) {
        
        let safeEmail = DatabaseManager.safeEmail(email)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    /// Inserts new user to database. If completion parameter Bool is true, the insert succeeded.
    /// - Parameter user: ChatAppUser object representing user info to insert in DB
    /// - Parameter completion: Async closure to return with Bool. True if successful, false if unsuccessful
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void ) {
        //Adds a child to database with key of user's safe email address
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { [weak self] error, _ in
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
            
            //Adds a "users" object to database if it does not exist, downloads data contained in this object as a [[String: String]] object if it does exist
            //Then, appends new user information to object and sets new value for "users"
            self?.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //append to users dictionary
                    let newElement: [String: String] = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    
                    usersCollection.append(newElement)
                    
                    self?.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else {
                    //create users collection in DB if it does not currently exist
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self?.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    /// Get all users from database
    /// - Parameter completion: Async closure to return with result holding `[[String: String]]` dictionary of user directory in DB
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void ) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
        
        public var localizedDescription: String {
            switch self {
            case .failedToFetch:
                return "Failed to fetch data from DB"
            }
        }
    }
    
    /*
     users => [
        [
            "name":
            "safe_email":
        ],
        [
            "name":
            "safe_email":
        ]
     ]
     */
}

//MARK: - Sending messages / conversations

extension DatabaseManager {
    
    /*
        uniqueID {
            "messages": [
                {
                    "id": String,
                    "type": text, photo, vidoe,
                    "content": String,
                    "date": Date(),
                    "sender_email": String,
                    "is_read": true / false
                }
            ]
        }
     
         conversation => [
            [
                "conversation_id": uniqueID
                "other_user_email":
                "latest_message": => {
                    "date": Date()
                    "latest_message": "message"
                    "is_read": true/false
                }
            
            ],
         ]
     */
    
    /// Returns a string representing contents of message to be stored in DB
    /// - Parameter message: Message object to be sent to a conversation
    private func createMessageContents(for message: Message) -> String {
        switch message.kind {
        case .text(let messageText):
            return messageText
        case .attributedText(_):
            return ""
        case .photo(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                return targetUrlString
            }
            return ""
        case .video(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                return targetUrlString
            }
            return ""
        case .location(let locationData):
            let location = locationData.location
            return "\(location.coordinate.longitude),\(location.coordinate.latitude)"
        case .emoji(_):
            return ""
        case .audio(_):
            return ""
        case .contact(_):
            return ""
        case .linkPreview(_):
            return ""
        case .custom(_):
            return ""
        }
    }
    
    /// Creates a new conversation with target user email and first message sent
    /// - Parameter otherUserEmail: Email of user who current user is starting a conversation with
    /// - Parameter otherUserName: Name of user who current user is starting a conversation with
    /// - Parameter firstMessage: Message to be sent in the newly created conversation
    /// - Parameter completion: Async closure to return result holding Bool. True if conversation created successfully
    public func createNewConversation(with otherUserEmail: String, otherUserName: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentUserName = UserDefaults.standard.value(forKey: "name") as? String else {
            completion(false)
            return
        }
        
        let ref = database.child("\(currentUserEmail)")
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var currentUserNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            guard let message = self?.createMessageContents(for: firstMessage) else {
                print("could not create message contents")
                return
            }
            
            let conversationId = "conversation: \(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": otherUserName,
                "latest_message": [
                    "date": dateString,
                    "is_read": false,
                    "message": message
                ]
                
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": currentUserEmail,
                "name": currentUserName,
                "latest_message": [
                    "date": dateString,
                    "is_read": false,
                    "message": message
                ]
                
            ]
            
            //Update recipient's conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    //create new conversations object
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            //Update current user conversation entry
            if var conversations = currentUserNode["conversations"] as? [[String: Any]] {
                //conversations array exists in database for current user
                //append conversation here
                conversations.append(newConversationData)
                currentUserNode["conversations"] = conversations
                
                ref.setValue(currentUserNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(recipientName: otherUserName,
                                                     conversationId: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            } else {
                //conversations array does NOT exist, create conversations array
                currentUserNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(currentUserNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(recipientName: otherUserName,
                                                     conversationId: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            }
        })
    }
    
    /// Creates a new conversation object for conversation matching `conversationId` using message `firstMessage`
    /// - Parameter recipientName: Name of user who current user is creating a conversation with
    /// - Parameter conversationId: Id of the conversation to continue being created
    /// - Parameter firstMessage: The first message to be sent in newly created conversation
    /// - Parameter completion: Async closure to return result holding Bool. True if creation is successful
    private func finishCreatingConversation(recipientName: String, conversationId: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        {
//            "id": String,
//            "type": text, photo, vidoe,
//            "content": String,
//            "date": Date(),
//            "sender_email": String,
//            "is_read": true / false
//        }
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        let message = createMessageContents(for: firstMessage)
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": recipientName
        ]
        
        let messagesCollection: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("adding convo: \(conversationId)")
        
        database.child("\(conversationId)").setValue(messagesCollection, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    
    ///Fetches all conversations for the user with email matching `email`.
    /// - Parameter email: Email of user to fetch conversations for
    /// - Parameter completion: Async closure to return result holding array of `Conversation` objects if successful. 
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            
            completion(.success(conversations))
        })
    }
    
    ///Fetches and returns all messages for conversation with ID matching `id`
    /// - Parameter id: conversation ID of target conversation
    /// - Parameter completion: Async closure to return with result holding array of `Message` objects if successful
    public func getAllMessagesForConversation(conversationId id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                print("ID: \(id)")
                print("Snapshot: \(snapshot)")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString),
                      let messageId = dictionary["id"] as? String,
                      let _ = dictionary["is_read"] as? Bool,
                      let name = dictionary["name"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String else {
                    return nil
                }
                
                //Handle different message types
                var kind: MessageKind?
                if type == "photo" {
                    guard let imageUrl = URL(string: content),
                          let placeholder = UIImage(systemName: "plus") else {
                        return nil
                    }
                    
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .photo(media)
                } else if type == "video" {
                    guard let videoUrl = URL(string: content),
                          let placeholder = UIImage(systemName: "play.circle") else {
                        return nil
                    }
                    
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .video(media)
                } else if type == "location" {
                    let locationComponents = content.split(separator: ",")
                    
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                        return nil
                    }
                    print("Rendering location: long = \(longitude), lat = \(latitude)")
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    
                    kind = .location(location)
                } else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: date,
                               kind: finalKind)
            })
            
            completion(.success(messages))
        })
    }
    
    /// Sends a message to conversation with ID matching `conervsationId`
    /// - Parameter conversation: Conversation ID of target conversation
    /// - Parameter otherUserEmail: Email of recipient user
    /// - Parameter name: Name of recipient user
    /// - Parameter newMessage: `Message` object holding data for message to be sent
    /// - Parameter completion: async closure to return Bool. True if successful.
    public func sendMessage(conversationId conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        //Get messages collection from target conversation
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {
            [weak self] snapshot in
            
            guard let strongSelf = self else { return }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            //Create message contents depending on kind of message
            guard let message = self?.createMessageContents(for: newMessage) else {
                print("could not create message contents")
                return
            }
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            //add new message entry to currentmessages and push to DB
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                //Set latest message equal to sent message for sending user
                strongSelf.database.child("\(currentUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "message": message,
                        "is_read": false
                    ]
                    //This block adds a conversation object to the sender's conversations collection if it exists in the DB,
                    //  if this collection exists and the conversation with matching ID does as well, it simply changes the latest message in that object
                    //  However, if the collection exists and a convo with matchin ID does NOT, it creates a new conversation object and appends that to the collection
                    //  Lastly, if the collection does not exist, it creates a new conversation collection for the sender and creates a conversation object that is appended to it.
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        //create conversations entry
                        var wasFound = false
                        
                        for index in 0..<currentUserConversations.count {
                            if let currentId = currentUserConversations[index]["id"] as? String, currentId == conversation {
                                wasFound = true
                                currentUserConversations[index]["latest_message"] = updatedValue
                                databaseEntryConversations = currentUserConversations
                            }
                        }
                        
                        if !wasFound {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else {
                        //Create "new" conversation for the sender with same conversation ID as deleted one
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                                newConversationData
                        ]
                    }
                    
                    strongSelf.database.child("\(currentUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        //Update latest message for receiving user
                        strongSelf.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: { error, _ in
                            guard error == nil else {
                                completion(false)
                                return
                            }
                            
                            //Set latest message equal to sent message
                            //Check to see if conversation ID exists in recipient user's conversations collection,
                            //  if it does not exist but the conversations collection does, this means the recipient deleted convo
                            //  so, create a new conversation object and append it to the recipients conversation collection
                            //  if a conversation collection does not exist for the recipient, create one and add new conversation object
                            strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                                var otherDatabaseEntryConversations = [[String: Any]]()
                                
                                guard let currentName = UserDefaults.standard.value(forKey: "name") else {
                                    return
                                }
                                
                                if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                    var wasFound = false
                                    for index in 0..<otherUserConversations.count {
                                        if let otherId = otherUserConversations[index]["id"] as? String, otherId == conversation {
                                            wasFound = true
                                            otherUserConversations[index]["latest_message"] = updatedValue
                                            otherDatabaseEntryConversations = otherUserConversations
                                        }
                                    }
                                    
                                    if !wasFound {
                                        let newConversationData: [String: Any] = [
                                            "id": conversation,
                                            "other_user_email": currentUserEmail,
                                            "name": currentName,
                                            "latest_message": updatedValue
                                        ]
                                        otherUserConversations.append(newConversationData)
                                        otherDatabaseEntryConversations = otherUserConversations
                                    }
                                } else {
                                    //Create "new" conversation for the recipient with same conversation ID as deleted one
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": currentUserEmail,
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    otherDatabaseEntryConversations = [
                                            newConversationData
                                    ]
                                }
                                                             
                                strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherDatabaseEntryConversations, withCompletionBlock: { error, _ in
                                    guard error == nil else {
                                        completion(false)
                                        return
                                    }
                                    
                                    completion(true)
                                })
                            })
                        })
                    })
                })
            })
        })
    }
    
    /// Deletes conversation with `conversationId` for the current user, will not remove the main reference or recipient's reference to the conversation.
    /// - Parameter conversationID: ID of conversation to remove from current user's DB entry
    /// - Parameter completion: Async closure to return Bool. True if successful
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let ref = database.child("\(currentUserEmail)/conversations")
        
        print("deleting conversation with id: \(conversationId)")
        
        // Get all convos for current user
        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard var conversations = snapshot.value as? [[String: Any]] else {
                return
            }
            
            //Remove target conversation from conversations array
            for (index, conversation) in conversations.enumerated() {
                if conversation["id"] as? String == conversationId {
                    print("found conversation to delete")
                    conversations.remove(at: index)
                }
            }
            
            //Set user's conversations collection to new conversations collection
            ref.setValue(conversations, withCompletionBlock: { error, _ in
                guard error == nil else {
                    completion(false)
                    print("failed to write new conversation array")
                    return
                }
                print("deleted conversation with id: \(conversationId)")
                completion(true)
            })
        })
    }
    
    /// Checks if target conversation exists in the database for recipeint. This is used to ensure duplicate conversations are not created when sending user deletes their conversation with recipient then sends or receives another message to/from the recipient user.
    /// - Parameter targetRecipientEmail: Email of user who's entry in the DB will be checked for conversation data.
    /// - Parameter completion: Async closure to return result holding conversationID for conversation if it exists.
    public func conversationExists(withRecipient targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let safeSenderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeRecipientEmail = DatabaseManager.safeEmail(targetRecipientEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let conversations = snapshot.value as? [[String: Any]] else {
                print("failed to fetch conversations in conversationExists")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            if let conversation = conversations.first(where: {
                $0["other_user_email"] as? String == safeSenderEmail
            }) {
                //Get id and pass to completion
                guard let conversationId = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                completion(.success(conversationId))
                return
            }
            
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}
