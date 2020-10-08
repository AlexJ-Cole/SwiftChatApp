//
//  ChatAppUser.swift
//  FireChat
//
//  Created by Alex Cole on 10/7/20.
//

import Foundation

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        DatabaseManager.safeEmail(self.emailAddress)
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
