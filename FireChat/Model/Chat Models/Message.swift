//
//  Message.swift
//  FireChat
//
//  Created by Alex Cole on 10/7/20.
//

import Foundation
import MessageKit

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}
