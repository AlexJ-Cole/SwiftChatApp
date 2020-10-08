//
//  Media.swift
//  FireChat
//
//  Created by Alex Cole on 10/7/20.
//

import Foundation
import UIKit
import MessageKit

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}
