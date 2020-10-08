//
//  Location.swift
//  FireChat
//
//  Created by Alex Cole on 10/7/20.
//

import Foundation
import CoreLocation
import MessageKit

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
}
