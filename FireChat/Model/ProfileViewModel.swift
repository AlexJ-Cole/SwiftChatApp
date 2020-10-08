//
//  ProfileViewModel.swift
//  FireChat
//
//  Created by Alex Cole on 10/7/20.
//

import Foundation

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    var title: String
    let handler: (() -> Void)?
}

enum ProfileViewModelType {
    case info, logout
}
